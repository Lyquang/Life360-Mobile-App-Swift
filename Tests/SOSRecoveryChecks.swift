import Foundation

private enum RecoveryCheckError: Error { case failure(String) }

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw RecoveryCheckError.failure(message) }
}

private actor RecoveryRepository: SOSIncidentRepository {
    var pages: [String: Result<SOSIncidentPage, SOSFailure>] = [:]
    var responses: [String: [Result<SOSDetail, SOSFailure>]] = [:]
    var calls: [String] = []
    var suspendNextDetail = false
    var suspendNextList = false
    var continuation: CheckedContinuation<Void, Never>?
    var isSuspended: Bool { continuation != nil }

    func setPage(_ cursor: String?, _ result: Result<SOSIncidentPage, SOSFailure>) {
        pages[cursor ?? "first"] = result
    }

    func setResponses(_ id: String, after: String? = nil, _ values: [Result<SOSDetail, SOSFailure>]) {
        responses["\(id):\(after ?? "first")"] = values
    }

    func suspendNext() { suspendNextDetail = true }
    func suspendList() { suspendNextList = true }
    func resume() { continuation?.resume(); continuation = nil }

    func create(_ intent: SOSCreationIntent) async throws -> SOSCreated { throw SOSFailure.unexpected }
    func respond(id: String) async throws -> SOSAssistanceResult { throw SOSFailure.unexpected }
    func close(id: String, status: SOSClosure) async throws -> SOSClosed { throw SOSFailure.unexpected }

    func list(status: SOSListFilter, limit: Int, cursor: String?) async throws -> SOSIncidentPage {
        if suspendNextList {
            suspendNextList = false
            await withCheckedContinuation { continuation = $0 }
        }
        return try (pages[cursor ?? "first"] ?? .failure(.unexpected)).get()
    }

    func detail(id: String, limit: Int, afterId: String?) async throws -> SOSDetail {
        let key = "\(id):\(afterId ?? "first")"
        calls.append(key)
        if suspendNextDetail {
            suspendNextDetail = false
            await withCheckedContinuation { continuation = $0 }
        }
        guard var values = responses[key], !values.isEmpty else { throw SOSFailure.unexpected }
        let result = values.removeFirst()
        responses[key] = values
        return try result.get()
    }
}

private final class RecoveryClock {
    var value = Date(timeIntervalSince1970: 1_000)
}

private final class RecoverySocket: SocketClient {
    var status: SocketConnectionStatus = .disconnected
    private var handlers: [String: [([String: Any]) -> Void]] = [:]
    func connect(token: String) {}
    func disconnect() {}
    func emit(_ event: String, _ payload: [String: Any]) {}
    func emitWithAck(_ event: String, _ payload: [String: Any], timeout: TimeInterval) async throws -> [String: Any] {
        throw SocketClientError.disconnected
    }
    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) {
        handlers[event, default: []].append(handler)
    }
    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) {}
    func deliver(_ event: String, _ payload: [String: Any]) { handlers[event]?.forEach { $0(payload) } }
    func count(_ event: String) -> Int { handlers[event]?.count ?? 0 }
}

enum SOSRecoveryChecks {
    @MainActor
    static func run() async throws {
        try await eventAdapter()
        let a = "000000000000000000000001"
        let b = "000000000000000000000002"
        let cursor = "000000000000000000000003"
        let repository = RecoveryRepository()
        let clock = RecoveryClock()
        let controller = SOSSessionController(repository: repository, now: { clock.value })
        controller.startSession()
        await repository.setPage(nil, .success(SOSIncidentPage(items: [incident(a, 1)], hasMore: true, nextCursor: cursor)))
        await repository.setPage(cursor, .success(SOSIncidentPage(items: [incident(b, 1)], hasMore: false, nextCursor: nil)))
        await controller.reconcile()
        try expect(controller.incidents.count == 2, "SOS recovery missed a list page")

        await repository.setResponses(a, [.success(detail(a, 2)), .success(detail(a, 3))])
        await controller.refreshDetail(id: a, minimumRevision: 3)
        try expect(controller.details[a]?.incident.revision == 3, "Older revision overwrote newer SOS")

        let first = detail(a, 3, group: "group-a", responders: [responder("one")], hasMore: true, cursor: cursor)
        await repository.setResponses(a, [.success(first)])
        await controller.refreshDetail(id: a)
        let changed = detail(a, 4, group: "group-b", responders: [responder("two")])
        await repository.setResponses(a, after: cursor, [.success(changed)])
        await repository.setResponses(a, [.success(changed)])
        await controller.loadMoreResponders(id: a)
        try expect(controller.details[a]?.incident.revision == 4, "Responder revision mismatch did not reload")
        try expect(controller.details[a]?.responders.map(\.id) == ["two"], "Old responders leaked across reload")

        let sameRevision = detail(a, 4, group: "group-c", responders: [responder("three")])
        await repository.setResponses(a, [.success(sameRevision)])
        await controller.refreshDetail(id: a)
        try expect(controller.details[a]?.responders.map(\.id) == ["three"], "Equal-revision permission refresh merged stale responders")

        await repository.setResponses(a, [.success(detail(a, 4)), .success(detail(a, 5))])
        await repository.suspendNext()
        let oldRequest = Task { await controller.refreshDetail(id: a) }
        for _ in 0..<1_000 {
            if await repository.isSuspended { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let suspended = await repository.isSuspended
        try expect(suspended, "Delayed SOS request did not start")
        let newEvent = Task { await controller.refreshDetail(id: a, minimumRevision: 5) }
        for _ in 0..<1_000 {
            if controller.awaitingRefresh.contains(a) { break }
            await Task.yield()
        }
        try expect(controller.awaitingRefresh.contains(a), "New SOS revision was left actionable")
        await repository.resume()
        await oldRequest.value
        await newEvent.value
        try expect(controller.details[a]?.incident.revision == 5, "Event during GET did not refresh newest revision")
        try expect(!controller.awaitingRefresh.contains(a), "Verified SOS stayed unavailable")

        await repository.setPage(nil, .success(SOSIncidentPage(items: [incident(a, 5), incident(b, 1)],
                                                               hasMore: false, nextCursor: nil)))
        await repository.suspendList()
        let staleList = Task { await controller.reconcile() }
        for _ in 0..<1_000 {
            if await repository.isSuspended { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let listStarted = await repository.isSuspended
        try expect(listStarted, "Delayed SOS list did not start")
        await repository.setResponses(a, [.failure(.forbidden), .failure(.forbidden)])
        await controller.refreshDetail(id: a)
        await repository.setResponses(b, [.success(detail(b, 1))])
        await repository.resume()
        await staleList.value
        try expect(controller.incidents[a] == nil && controller.details[a] == nil, "403 did not remove SOS")
        try expect(controller.detailErrors[a] == .forbidden && controller.detailErrors[b] == nil,
                   "SOS permission errors leaked across incidents")
        await repository.setPage(nil, .failure(.network))
        await controller.reconcile()
        try expect(controller.incidents[b] != nil, "Failed list removed a cached incident")

        await repository.setResponses(b, [.failure(.rateLimited(retryAfter: "75")), .success(detail(b, 2))])
        await controller.refreshDetail(id: b)
        let before = await repository.calls.count
        await controller.refreshDetail(id: b, minimumRevision: 2)
        let after = await repository.calls.count
        try expect(before == after, "SOS read bypassed Retry-After")
        try expect(controller.awaitingRefresh.contains(b), "Stale SOS stayed actionable during cooldown")
        clock.value.addTimeInterval(75)
        await controller.refreshDetail(id: b)
        try expect(controller.details[b]?.incident.revision == 2, "SOS read did not resume after cooldown")

        await repository.setResponses(b, [.success(detail(b, 3))])
        await repository.suspendNext()
        let late = Task { await controller.refreshDetail(id: b) }
        for _ in 0..<1_000 {
            if await repository.isSuspended { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let lateStarted = await repository.isSuspended
        try expect(lateStarted, "Late SOS request did not start")
        controller.stop()
        await repository.resume()
        await late.value
        try expect(controller.incidents.isEmpty && controller.details.isEmpty, "Logout did not clear SOS state")
    }

    private static func eventAdapter() async throws {
        let socket = RecoverySocket()
        let adapter = SOSRealtimeEventAdapter(socket: socket)
        var iterator = adapter.observe().makeAsyncIterator()
        let firstID = "000000000000000000000006"
        let secondID = "000000000000000000000007"
        let sosID = "000000000000000000000001"
        let first: [String: Any] = ["eventId": firstID, "sosId": sosID, "revision": 1]
        let second: [String: Any] = ["eventId": secondID, "sosId": sosID, "revision": 2]
        socket.deliver(SocketEvent.sosAlertReceive, first) // Inactive session is ignored.
        adapter.startSession()
        adapter.startSession()
        socket.deliver(SocketEvent.sosAlertReceive, ["userId": "legacy"])
        socket.deliver(SocketEvent.sosAlertReceive, first)
        socket.deliver(SocketEvent.sosAlertReceive, first)
        socket.deliver(SocketEvent.sosUpdated, second)
        guard let alert = await iterator.next(), let update = await iterator.next() else {
            throw RecoveryCheckError.failure("SOS events missing")
        }
        try expect(alert.kind == .alert && alert.eventID == firstID && alert.revision == 1, "SOS alert identity")
        try expect(update.kind == .updated && update.eventID == secondID && update.revision == 2,
                   "Duplicate, legacy or invalid SOS event was delivered")
        try expect(socket.count(SocketEvent.sosAlertReceive) == 1 && socket.count(SocketEvent.sosUpdated) == 1,
                   "SOS handlers registered more than once")
        adapter.stopSession()
        try expect(!adapter.isCurrent(alert), "Old SOS event survived logout")
        adapter.startSession()
        try expect(!adapter.isCurrent(update), "Old SOS event survived account change")
        socket.deliver(SocketEvent.sosAlertReceive, first)
        guard let nextSession = await iterator.next() else { throw RecoveryCheckError.failure("SOS event missing") }
        try expect(adapter.isCurrent(nextSession) && nextSession.eventID == firstID,
                   "New session did not reset SOS deduplication")
        adapter.stopSession()
    }

    private static func incident(_ id: String, _ revision: Int, group: String = "group-a") -> SOSIncident {
        SOSIncident(id: id, ownerId: "owner", status: .active, revision: revision, message: "",
                    location: nil, groupIds: [group], createdAt: Date(timeIntervalSince1970: 0), closedAt: nil)
    }

    private static func responder(_ id: String) -> SOSResponder {
        SOSResponder(id: id, responderId: id, name: nil, avatar: nil, status: "coming",
                     respondedAt: Date(timeIntervalSince1970: 0))
    }

    private static func detail(_ id: String, _ revision: Int, group: String = "group-a",
                               responders: [SOSResponder] = [], hasMore: Bool = false,
                               cursor: String? = nil) -> SOSDetail {
        SOSDetail(incident: incident(id, revision, group: group), responders: responders,
                  hasMore: hasMore, nextAfterId: cursor)
    }
}
