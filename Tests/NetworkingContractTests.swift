import Foundation

private struct CheckFailure: Error { let message: String }

private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(message: message) }
}

private final class TokenStub: AccessTokenProvider {
    var accessToken: String? = "keychain-token"
    var invalidated: [String] = []
    func invalidate(token: String) {
        invalidated.append(token)
        if accessToken == token { accessToken = nil }
    }
}

private final class ProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    static var responseHeaders: [String: String] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw CheckFailure(message: "Missing handler") }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                           httpVersion: nil, headerFields: Self.responseHeaders)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private actor RefreshStub: RefreshTokenTransport {
    private(set) var calls = 0
    func rotate(refreshToken: String) async throws -> AuthTokens {
        calls += 1
        try await Task.sleep(nanoseconds: 50_000_000)
        return AuthTokens(accessToken: "refreshed-token", refreshToken: "next-refresh", expiresIn: 900)
    }
}

private final class PairStoreStub: TokenPairStore {
    var tokens: AuthTokens? = AuthTokens(accessToken: "expired", refreshToken: "current-refresh", expiresIn: 900)
    var sessionGeneration = 0
    var failWrite = false
    var accessToken: String? { tokens?.accessToken }
    var invalidated: [String] = []
    func invalidate(token: String) { invalidated.append(token); if accessToken == token { tokens = nil } }
    func replaceTokens(_ value: AuthTokens) throws {
        if failWrite { throw CheckFailure(message: "Keychain write failed") }
        tokens = value
    }
    func replaceTokens(_ value: AuthTokens, ifGeneration expected: Int) throws {
        guard sessionGeneration == expected else { throw RefreshFailure.cancelled }
        try replaceTokens(value)
    }
    func clear() { tokens = nil }
}

private final class SOSRaceTokenProvider: AccessTokenProvider {
    private let lock = NSLock()
    private var token = "account-a-token"
    private var generation = 0
    private let switchOnSnapshot: Bool

    init(switchOnSnapshot: Bool = false) { self.switchOnSnapshot = switchOnSnapshot }
    var accessToken: String? { lock.lock(); defer { lock.unlock() }; return token }
    var sessionGeneration: Int { lock.lock(); defer { lock.unlock() }; return generation }
    var tokenSnapshot: (token: String?, generation: Int) {
        lock.lock(); defer { lock.unlock() }
        let previous = (token: Optional(token), generation: generation)
        if switchOnSnapshot && generation == 0 { token = "account-b-token"; generation = 1 }
        return previous
    }
    func switchAccount() { lock.lock(); token = "account-b-token"; generation += 1; lock.unlock() }
    func invalidate(token: String) {}
}

private final class UnfencedAPIStub: APIClient {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        throw CheckFailure(message: "Unfenced API must not be called")
    }
    func sendWithMetadata<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResult<T> {
        throw CheckFailure(message: "Unfenced API must not be called")
    }
}

private actor ConfigurableRefreshStub: RefreshTokenTransport {
    private(set) var calls = 0
    let result: Result<AuthTokens, RefreshFailure>
    init(_ result: Result<AuthTokens, RefreshFailure>) { self.result = result }
    func rotate(refreshToken: String) async throws -> AuthTokens {
        calls += 1
        return try result.get()
    }
}

private actor ExpiryCounter {
    private(set) var count = 0
    func record() { count += 1 }
}

private actor DeferredRefreshStub: RefreshTokenTransport {
    private(set) var started = false
    private var continuation: CheckedContinuation<AuthTokens, Error>?

    func rotate(refreshToken: String) async throws -> AuthTokens {
        started = true
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func failAsReused() {
        continuation?.resume(throwing: RefreshFailure.invalidSession)
        continuation = nil
    }
}

private actor MediaRefreshStub: RefreshTokenTransport {
    private(set) var calls = 0
    func rotate(refreshToken: String) async throws -> AuthTokens {
        calls += 1
        return AuthTokens(accessToken: "fresh", refreshToken: "next-refresh", expiresIn: 900)
    }
}

private final class SOSRunnerClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_000)
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ seconds: TimeInterval) { lock.lock(); value.addTimeInterval(seconds); lock.unlock() }
}

private final class SOSRunnerGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 41
    func current() -> Int { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ next: Int) { lock.lock(); value = next; lock.unlock() }
}

private actor SOSRunnerSender {
    private(set) var requests: [SOSCreationIntent] = []
    private var failures: [SOSFailure]
    init(failures: [SOSFailure]) { self.failures = failures }
    func send(_ intent: SOSCreationIntent) throws -> SOSCreated {
        requests.append(intent)
        if !failures.isEmpty { throw failures.removeFirst() }
        return SOSCreated(created: true, incident: SOSSummary(
            id: "000000000000000000000001", ownerId: "000000000000000000000002", status: .active,
            revision: 1, groupCount: 1, recipientCount: 1, createdAt: Date(timeIntervalSince1970: 1_000), closedAt: nil))
    }
}

private actor SOSRunnerBlockingSender {
    private(set) var calls = 0
    private var continuation: CheckedContinuation<Void, Never>?
    func send(_ intent: SOSCreationIntent) async -> SOSCreated {
        calls += 1
        await withCheckedContinuation { continuation = $0 }
        return SOSCreated(created: true, incident: SOSSummary(
            id: "000000000000000000000001", ownerId: "000000000000000000000002", status: .active,
            revision: 1, groupCount: 1, recipientCount: 1, createdAt: Date(timeIntervalSince1970: 1_000), closedAt: nil))
    }
    func release() { continuation?.resume(); continuation = nil }
}

@main
enum NetworkingContractTests {
    static func main() async throws {
        try documentedResponses()
        try localizedAPIErrorSafety()
        try deployedCircleMembersResponse()
        try requests()
        try mediaContracts()
        try await locationBatchContract()
        try await sosContract()
        try await sosGenerationFenceContract()
        try await sosPendingContract()
        try await sosRunnerContract()
        try await SOSRecoveryChecks.run()
        try SOSChatChecks.run()
        try redaction()
        try liveTrailAssemblyAndGeometry()
        try socketLocationContract()
        try check(AppEnvironment.current.apiBaseURL.absoluteString == "https://life360-backend-6v9n.onrender.com/api/v1", "Deployed REST host")
        try check(AppEnvironment.current.socketURL.absoluteString == "https://life360-backend-6v9n.onrender.com", "Deployed Socket.IO host")
        try await transport()
        try await mediaTransport()
        try await singleFlightRefresh()
        try await refreshFailurePolicies()
        try await refreshTransportContract()
        try await retryUnauthorizedStops()
        try await lateRefreshCannotExpireNewSession()
        print("PASS: REST/SOS contracts, auth refresh, media ticket/PUT retry, decoding and errors")
    }

    static func sosContract() async throws {
        let id = "000000000000000000000001"
        let intent = SOSCreationIntent(clientRequestId: UUID(), message: "Help", location: nil)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil; ProtocolStub.responseHeaders = [:] }
        let store = PairStoreStub()
        let refresh = RefreshStub()
        let coordinator = TokenRefreshCoordinator(store: store, transport: refresh)
        let client = URLSessionAPIClient(baseURL: URL(string: "https://example.test/api/v1")!, session: session,
                                         tokenProvider: store, logger: NoopNetworkLogger(), refreshCoordinator: coordinator)
        let repository = SOSIncidentRepositoryImpl(api: client)
        let summary = """
        {"id":"\(id)","ownerId":"000000000000000000000002","status":"active","revision":1,
         "groupCount":2,"recipientCount":3,"createdAt":"2026-10-29T10:00:00.000Z"}
        """
        var observedIDs: [String] = []
        ProtocolStub.handler = { request in
            try check(request.url?.path == "/api/v1/sos" && request.httpMethod == "POST", "SOS create route")
            let body = try JSONSerialization.jsonObject(with: sosRequestBody(request)) as! [String: Any]
            try check(Set(body.keys) == ["clientRequestId", "message"], "SOS strict body")
            observedIDs.append(body["clientRequestId"] as! String)
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
                return (401, Data(#"{"success":false,"code":"UNAUTHORIZED"}"#.utf8))
            }
            return (201, Data("{\"success\":true,\"data\":{\"created\":true,\"incident\":\(summary)}}".utf8))
        }
        let created = try await repository.create(intent, expectedSessionGeneration: 0)
        try check(created.created && created.incident.revision == 1, "SOS summary decode")
        let rotations = await refresh.calls
        try check(rotations == 1 && observedIDs == Array(repeating: intent.clientRequestId.uuidString.lowercased(), count: 2),
                  "SOS refresh must reuse request UUID")

        ProtocolStub.handler = { _ in
            (200, Data("{\"success\":true,\"data\":{\"created\":false,\"incident\":\(summary)}}".utf8))
        }
        let replay = try await repository.create(intent, expectedSessionGeneration: 0)
        try check(!replay.created && replay.incident.id == id, "SOS replay")

        ProtocolStub.handler = { request in
            try check(request.url?.query?.contains("afterId=") == true, "Responder afterId missing")
            try check(request.url?.query?.contains("cursor=") == false, "Incident cursor leaked into detail")
            return (200, Data("""
            {"success":true,"data":{"incident":{"id":"\(id)","ownerId":"000000000000000000000002",
            "status":"active","revision":2,"message":"Help","location":null,"groupIds":[],
            "createdAt":"2026-10-29T10:00:00.123Z","closedAt":null},"responders":[
            {"id":"000000000000000000000004","responderId":"000000000000000000000005",
            "name":null,"avatar":null,"status":"coming","respondedAt":"2026-10-29T10:01:00Z"}],
            "hasMore":false,"nextAfterId":null}}
            """.utf8))
        }
        let detail = try await repository.detail(id: id, afterId: id)
        try check(detail.incident.location == nil && detail.responders.first?.name == nil, "SOS null fields")
        try check(detail.incident.createdAt == ISO8601.date(from: "2026-10-29T10:00:00.123Z"), "SOS fractional date")

        ProtocolStub.handler = { request in
            try check(request.url?.query?.contains("cursor=") == true, "Incident cursor missing")
            try check(request.url?.query?.contains("afterId=") == false, "Responder cursor leaked into list")
            return (200, Data(#"{"success":true,"data":{"items":[],"hasMore":false,"nextCursor":null}}"#.utf8))
        }
        let page = try await repository.list(cursor: id)
        try check(page.items.isEmpty && !page.hasMore, "SOS empty list")

        ProtocolStub.handler = { request in
            try check(request.url?.path == "/api/v1/sos/\(id)/responses", "SOS respond route")
            let body = try JSONSerialization.jsonObject(with: sosRequestBody(request)) as! [String: String]
            try check(body == ["status": "coming"], "SOS respond strict body")
            return (201, Data("""
            {"success":true,"data":{"created":true,"sosId":"\(id)","revision":2,"response":{
            "id":"000000000000000000000004","responderId":"000000000000000000000005",
            "status":"coming","respondedAt":"2026-10-29T10:01:00.000Z"}}}
            """.utf8))
        }
        let assistance = try await repository.respond(id: id, expectedSessionGeneration: 0)
        try check(assistance.response.name == nil && assistance.created, "Write response has no profile")

        ProtocolStub.handler = { request in
            try check(request.httpMethod == "PATCH", "SOS close method")
            let closed = summary.replacingOccurrences(of: "active", with: "resolved")
            return (200, Data("{\"success\":true,\"data\":{\"changed\":false,\"incident\":\(closed)}}".utf8))
        }
        let closed = try await repository.close(id: id, status: .resolved, expectedSessionGeneration: 0)
        try check(!closed.changed && closed.incident.status == .resolved, "SOS close replay")

        let cases: [(Int, SOSFailure)] = [(400, .invalidRequest), (403, .forbidden), (404, .notFound),
            (409, .conflict), (413, .payloadTooLarge), (429, .rateLimited(retryAfter: "75")),
            (503, .unavailable), (500, .server)]
        ProtocolStub.responseHeaders = ["Retry-After": "75"]
        for (status, expected) in cases {
            ProtocolStub.handler = { _ in (status, Data(#"{"success":false,"message":"private"}"#.utf8)) }
            do { _ = try await repository.list(); throw CheckFailure(message: "SOS error accepted as success") }
            catch let error as SOSFailure { try check(error == expected, "SOS error mapping \(status)") }
        }
        ProtocolStub.handler = { _ in (200, Data(#"{"success":true,"data":null}"#.utf8)) }
        do { _ = try await repository.list(); throw CheckFailure(message: "Missing data accepted") }
        catch let error as SOSFailure { try check(error == .invalidResponse, "SOS invalid envelope") }
    }

    private static func sosRequestBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { throw CheckFailure(message: "Missing SOS request body") }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw CheckFailure(message: "Cannot read SOS request body") }
            if count == 0 { return result }
            result.append(contentsOf: buffer.prefix(count))
        }
    }

    static func sosGenerationFenceContract() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil; ProtocolStub.responseHeaders = [:] }
        let intent = SOSCreationIntent(clientRequestId: UUID(), message: nil, location: nil)
        let unfencedRepository = SOSIncidentRepositoryImpl(api: UnfencedAPIStub())
        do {
            _ = try await unfencedRepository.create(intent, expectedSessionGeneration: 0)
            throw CheckFailure(message: "Client without session fencing accepted SOS")
        } catch is CancellationError {}
        let baseURL = URL(string: "https://example.test/api/v1")!
        let switchedBeforeSend = SOSRaceTokenProvider(switchOnSnapshot: true)
        let client = URLSessionAPIClient(baseURL: baseURL, session: session, tokenProvider: switchedBeforeSend,
                                         logger: NoopNetworkLogger())
        let repository = SOSIncidentRepositoryImpl(api: client)
        var requests = 0
        ProtocolStub.handler = { _ in requests += 1; return (500, Data()) }
        do {
            _ = try await repository.create(intent, expectedSessionGeneration: 0)
            throw CheckFailure(message: "SOS was sent after account changed")
        } catch is CancellationError {}
        try check(requests == 0, "Old SOS reached the network after session change")

        let switchedBeforeResponse = SOSRaceTokenProvider()
        let secondClient = URLSessionAPIClient(baseURL: baseURL, session: session, tokenProvider: switchedBeforeResponse,
                                               logger: NoopNetworkLogger())
        let secondRepository = SOSIncidentRepositoryImpl(api: secondClient)
        ProtocolStub.handler = { request in
            try check(request.value(forHTTPHeaderField: "Authorization") == "Bearer account-a-token", "Wrong account token")
            switchedBeforeResponse.switchAccount()
            return (201, Data("""
            {"success":true,"data":{"created":true,"incident":{"id":"000000000000000000000001",
            "ownerId":"000000000000000000000002","status":"active","revision":1,"groupCount":1,
            "recipientCount":1,"createdAt":"2026-10-29T10:00:00Z"}}}
            """.utf8))
        }
        do {
            _ = try await secondRepository.create(intent, expectedSessionGeneration: 0)
            throw CheckFailure(message: "Old SOS response accepted after account changed")
        } catch is CancellationError {}
        try check(switchedBeforeResponse.accessToken == "account-b-token", "New account was invalidated")

        var laterRequests = 0
        ProtocolStub.handler = { _ in laterRequests += 1; return (500, Data()) }
        let id = "000000000000000000000001"
        do {
            _ = try await secondRepository.respond(id: id, expectedSessionGeneration: 0)
            throw CheckFailure(message: "Old assistance sent as new account")
        } catch is CancellationError {}
        do {
            _ = try await secondRepository.close(id: id, status: .resolved, expectedSessionGeneration: 0)
            throw CheckFailure(message: "Old closure sent as new account")
        } catch is CancellationError {}
        try check(laterRequests == 0, "Stale SOS write reached the network")
    }

    static func sosPendingContract() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("pending.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SOSPendingIntentStore(fileURL: url)
        let first = SOSCreationIntent(clientRequestId: UUID(), message: "Help", location: nil)
        let next = SOSCreationIntent(clientRequestId: UUID(), message: "Changed", location: nil)
        let session = try await store.activate(ownerID: "account-a")
        let saved = try await store.prepare(session: session, intent: first)
        let same = try await store.prepare(session: session, intent: next)
        try check(saved.intent == first && same.intent == first, "SOS intent was replaced")
        let now = Date(timeIntervalSince1970: 1_000)
        let deadline = now.addingTimeInterval(75)
        let updated = try await store.update(session: session, requestID: first.clientRequestId,
                                             state: .uncertain, attemptCount: 1, notBefore: deadline)
        try check(updated, "SOS pending update failed")
        let restoredStore = try SOSPendingIntentStore(fileURL: url)
        let restoredSession = try await restoredStore.activate(ownerID: "account-a")
        let restored = try await restoredStore.current(session: restoredSession)
        try check(restored?.intent == first && restored?.state == .uncertain && restored?.notBefore == deadline,
                  "SOS pending did not survive restart")
        let wrongID = try await restoredStore.clear(session: restoredSession, requestID: next.clientRequestId)
        try check(!wrongID, "Wrong UUID cleared SOS pending")
        let otherSession = try await restoredStore.activate(ownerID: "account-b")
        let empty = try await restoredStore.current(session: otherSession)
        try check(empty == nil, "Pending intent crossed accounts")
        _ = try await restoredStore.prepare(session: otherSession, intent: next)
        do {
            _ = try await restoredStore.clear(session: restoredSession, requestID: first.clientRequestId)
            throw CheckFailure(message: "Stale session cleared new account")
        } catch SOSPendingStoreError.inactiveSession {}
        let other = try await restoredStore.current(session: otherSession)
        try check(other?.intent == next, "Stale callback changed new account")
        try await restoredStore.endSession(otherSession)
        try check(!FileManager.default.fileExists(atPath: url.path), "Logout did not clear SOS file")
        try Data("corrupt".utf8).write(to: url, options: .atomic)
        do {
            _ = try await restoredStore.activate(ownerID: "account-b")
            throw CheckFailure(message: "Corrupt pending data accepted")
        } catch SOSPendingStoreError.corruptData {}
        try check(FileManager.default.fileExists(atPath: url.path), "Corrupt intent silently deleted")
        try await restoredStore.clearAll()
        let decision = SOSRetryPolicy.decide(failure: .rateLimited(retryAfter: "75"), attempts: 1, now: now, jitter: 0)
        try check(decision == .deferUntil(deadline), "Long Retry-After was not deferred")
        let stopped = SOSRetryPolicy.decide(failure: .network, attempts: 3, now: now, jitter: 0)
        try check(stopped == .stop(notBefore: now.addingTimeInterval(4)), "SOS retry limit")
        let nonRetryable = SOSRetryPolicy.decide(failure: .forbidden, attempts: 1, now: now, jitter: 0)
        try check(nonRetryable == .stop(notBefore: nil), "SOS 403 should not retry")
        let jittered = SOSRetryPolicy.decide(failure: .rateLimited(retryAfter: "20"), attempts: 1, now: now, jitter: 1)
        try check(jittered == .retry(delay: 21, notBefore: now.addingTimeInterval(21)), "SOS retry jitter")
    }

    static func sosRunnerContract() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pendingURL = directory.appendingPathComponent("pending.json")
        let store = try SOSPendingIntentStore(fileURL: pendingURL)
        let sender = SOSRunnerSender(failures: [.network, .server])
        let clock = SOSRunnerClock()
        let runner = SOSIntentRunner(store: store, send: { intent, generation in
            try check(generation == 41, "SOS runner lost the auth session generation")
            let saved = try JSONDecoder().decode(SOSPendingIntent.self, from: Data(contentsOf: pendingURL))
            try check(saved.state == .uncertain && saved.intent == intent, "SOS was not persisted before send")
            return try await sender.send(intent)
        }, currentSessionGeneration: { 41 },
                                     now: { clock.now() }, jitter: { 0 }, sleep: { clock.advance($0) })
        let initial = try await runner.startSession(ownerID: "owner-a", sessionGeneration: 41)
        try check(initial == nil, "New SOS session should be empty")
        let pending = try await runner.prepare(message: "Help", location: nil)
        let result = try await runner.sendPending()
        guard case .confirmed(let created, let cleanup) = result else {
            throw CheckFailure(message: "SOS retry never confirmed")
        }
        let requests = await sender.requests
        try check(created.created && !cleanup && requests.count == 3, "SOS retry count or cleanup")
        try check(requests.allSatisfy { $0 == pending.intent }, "SOS retry changed intent")
        let empty = try await runner.startSession(ownerID: "owner-a", sessionGeneration: 41)
        try check(empty == nil, "Committed SOS remained pending")

        let delayedSender = SOSRunnerSender(failures: [.rateLimited(retryAfter: "75")])
        let delayed = SOSIntentRunner(store: store, send: { intent, _ in try await delayedSender.send(intent) },
                                      currentSessionGeneration: { 41 },
                                      now: { clock.now() }, jitter: { 0 }, sleep: { clock.advance($0) })
        _ = try await delayed.startSession(ownerID: "owner-a", sessionGeneration: 41)
        let original = try await delayed.prepare(message: "Wait", location: nil)
        let waiting = try await delayed.sendPending()
        guard case .waiting(let saved) = waiting, let notBefore = saved.notBefore else {
            throw CheckFailure(message: "SOS 429 not deferred")
        }
        let restored = try await delayed.startSession(ownerID: "owner-a", sessionGeneration: 41)
        try check(restored?.intent == original.intent && restored?.notBefore == notBefore,
                  "SOS deadline not restored")
        _ = try await delayed.sendPending()
        let delayedCount = await delayedSender.requests.count
        try check(delayedCount == 1, "SOS retried before Retry-After")
        clock.advance(75)
        guard case .confirmed = try await delayed.sendPending() else {
            throw CheckFailure(message: "SOS retry after deadline failed")
        }

        let blocker = SOSRunnerBlockingSender()
        let authGeneration = SOSRunnerGeneration()
        let blocked = SOSIntentRunner(store: store, send: { intent, _ in await blocker.send(intent) },
                                      currentSessionGeneration: { authGeneration.current() })
        _ = try await blocked.startSession(ownerID: "owner-a", sessionGeneration: 41)
        _ = try await blocked.prepare(message: "Blocked", location: nil)
        let sendTask = Task { try await blocked.sendPending() }
        for _ in 0..<1_000 {
            if await blocker.calls > 0 { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let startedCount = await blocker.calls
        try check(startedCount == 1, "SOS request did not start")
        await blocked.cancelPendingWork()
        let second = Task { try await blocked.sendPending() }
        try await Task.sleep(nanoseconds: 5_000_000)
        let concurrentCount = await blocker.calls
        try check(concurrentCount == 1, "Concurrent SOS requests were not single-flight")
        try await blocked.endSession()
        await blocker.release()
        do { _ = try await sendTask.value; throw CheckFailure(message: "Logout accepted old response") }
        catch is CancellationError {}
        do { _ = try await second.value; throw CheckFailure(message: "Logout accepted waiting response") }
        catch is CancellationError {}
        catch SOSIntentRunnerError.noSession {}
        authGeneration.set(42)
        let afterLogout = try await blocked.startSession(ownerID: "owner-b", sessionGeneration: 42)
        try check(afterLogout == nil, "Logout leaked SOS into a new account")

        let staleSender = SOSRunnerBlockingSender()
        authGeneration.set(43)
        let stale = SOSIntentRunner(store: store, send: { intent, _ in await staleSender.send(intent) },
                                    currentSessionGeneration: { authGeneration.current() })
        _ = try await stale.startSession(ownerID: "owner-a", sessionGeneration: 43)
        _ = try await stale.prepare(message: "Pending", location: nil)
        let staleTask = Task { try await stale.sendPending() }
        for _ in 0..<1_000 {
            if await staleSender.calls > 0 { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let staleStarted = await staleSender.calls
        try check(staleStarted == 1, "Stale-session request did not start")
        authGeneration.set(44)
        await staleSender.release()
        do { _ = try await staleTask.value; throw CheckFailure(message: "Stale SOS result was accepted") }
        catch SOSIntentRunnerError.sessionChanged {}
        let fresh = try await stale.startSession(ownerID: "owner-b", sessionGeneration: 44)
        try check(fresh == nil, "Pending SOS crossed account generations")
    }


    static func locationBatchContract() async throws {
        let fix = LocationFix(latitude: 10.7, longitude: 106.7,
                              timestamp: Date(timeIntervalSince1970: 1_000_000.123),
                              horizontalAccuracy: 8, speed: 1, course: 0)
        let point = BufferedLocationPoint(fix: fix, batteryLevel: 80)
        let endpoint = LocationEndpoint.batch(LocationBatchRequestDTO(points: [LocationBatchPointDTO(point)]))
        try check(endpoint.path == "/locations/batch" && endpoint.method == .POST && endpoint.requiresAuth,
                  "Batch endpoint contract")
        let body = try JSONSerialization.jsonObject(with: endpoint.encodedBody()!) as! [String: Any]
        let values = (body["points"] as! [[String: Any]])[0]
        try check(values["recordedAt"] as? String == ISO8601.string(from: fix.timestamp), "Fix time lost")
        try check(values["pointId"] as? String == point.pointId.uuidString, "Point ID lost")
        try check(values["unknownRejectionAttempts"] == nil, "Private counter sent to backend")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil; ProtocolStub.responseHeaders = [:] }
        let client = URLSessionAPIClient(baseURL: URL(string: "https://example.test/api/v1")!, session: session,
                                         tokenProvider: TokenStub(), logger: NoopNetworkLogger())
        let repository = LocationBatchRepositoryImpl(api: client)
        ProtocolStub.handler = { request in
            try check(request.url?.path == "/api/v1/locations/batch", "Batch URL")
            return (200, Data("""
                {"success":true,"data":{"accepted":["\(point.pointId.uuidString)"],"duplicates":[],"rejected":[]}}
                """.utf8))
        }
        let result = try await repository.upload([point])
        try check(result.accepted == [point.pointId], "Batch accepted IDs")
        ProtocolStub.responseHeaders = ["Retry-After": "75"]
        ProtocolStub.handler = { _ in (429, Data(#"{"success":false,"code":"RATE_LIMITED"}"#.utf8)) }
        do {
            _ = try await repository.upload([point])
            throw CheckFailure(message: "Rate limit ignored")
        } catch LocationBatchError.rateLimited(let retryAfter) {
            try check(retryAfter == "75", "Retry-After lost")
        }
        ProtocolStub.responseHeaders = [:]
        let refreshStore = PairStoreStub()
        let refreshTransport = RefreshStub()
        let refresh = TokenRefreshCoordinator(store: refreshStore, transport: refreshTransport)
        let refreshingClient = URLSessionAPIClient(baseURL: URL(string: "https://example.test/api/v1")!,
                                                   session: session, tokenProvider: refreshStore,
                                                   logger: NoopNetworkLogger(), refreshCoordinator: refresh)
        var authHeaders: [String?] = []
        ProtocolStub.handler = { request in
            let header = request.value(forHTTPHeaderField: "Authorization")
            authHeaders.append(header)
            if header == "Bearer expired" {
                return (401, Data(#"{"success":false,"code":"UNAUTHORIZED"}"#.utf8))
            }
            return (200, Data(#"{"success":true,"data":{"accepted":[],"duplicates":[],"rejected":[]}}"#.utf8))
        }
        _ = try await LocationBatchRepositoryImpl(api: refreshingClient).upload([point])
        try check(authHeaders == ["Bearer expired", "Bearer refreshed-token"], "Batch 401 retry token")
        let refreshCalls = await refreshTransport.calls
        try check(refreshCalls == 1, "Batch refresh count")
    }

    static func localizedAPIErrorSafety() throws {
        let originalLanguage = L10n.language
        defer { L10n.language = originalLanguage }

        let serverError = APIError.http(
            status: 400,
            code: "VALIDATION_ERROR",
            message: "private server detail",
            errors: [.init(field: "email", message: "private field detail")]
        ).domainError

        L10n.language = .vietnamese
        try check(serverError.localizedDescription == L10n.tr("error.invalid_data"),
                  "Validation errors must be localized without exposing server text")
        let forbidden = APIError.http(status: 403, code: "FORBIDDEN", message: "private", errors: []).domainError
        try check(forbidden.localizedDescription == L10n.tr("error.forbidden"),
                  "403 errors must keep a localized generic message")

        L10n.language = .english
        try check(serverError.localizedDescription == L10n.tr("error.invalid_data"),
                  "API errors must follow the selected app language")
    }

    static func deployedCircleMembersResponse() throws {
        let json = Data(#"{"success":true,"data":{"groupName":"Ly Quang Family","inviteCode":"747684","conversationId":"conversation-1","memberCount":3,"members":[{"id":"member-1","name":"Ly","batteryLevel":35,"isOnline":true},{"id":"member-2","name":"Binh","batteryLevel":85,"isOnline":true},{"id":"member-3","name":"Quang","batteryLevel":100,"isOnline":false}]}}"#.utf8)
        let response = try BackendJSONCoding.makeDecoder().decode(APIResponseDTO<GroupMembersDTO>.self, from: json)
        let details = try response.unwrap(fallbackMessage: "Missing members")
        try check(details.groupId == nil, "Deployed members response may omit groupId")
        try check(details.members.count == 3 && details.members[0].id == "member-1", "Circle members were lost")
        try check(details.members[2].isOnline == false, "Circle member status was lost")
    }

    static func mediaContracts() throws {
        try check(MediaUploadPolicy.mimeType(for: .image) == "image/jpeg", "Image MIME")
        try check(MediaUploadPolicy.fileExtension(for: .image) == "jpg", "Image extension")
        try check(MediaUploadPolicy.mimeType(for: .voice) == "audio/mp4", "Voice MIME")
        try check(MediaUploadPolicy.fileExtension(for: .voice) == "m4a", "Voice extension")
        try check(MediaUploadPolicy.maxImageBytes == 10 * 1024 * 1024, "Image limit")
        try check(MediaUploadPolicy.maxVoiceBytes == 25 * 1024 * 1024, "Voice limit")
        try check(MediaUploadPolicy.maxVoiceDuration == 900, "Voice duration")

        let endpoint = ChatEndpoint.mediaTicket(conversationId: "conversation", kind: .voice, fileSize: 123456)
        try check(endpoint.path == "/chat/media/presigned-url", "Media ticket path")
        let body = try JSONSerialization.jsonObject(with: endpoint.encodedBody()!) as! [String: Any]
        try check(body["mimeType"] as? String == "audio/mp4" && body["extension"] as? String == "m4a", "Voice ticket body")
        try check(body["fileSize"] as? Int == 123456, "Compressed file size")

        let decoder = BackendJSONCoding.makeDecoder()
        let image = try decoder.decode(ChatMessageDTO.self, from: Data(#"{"id":"i","conversationId":"c","senderId":"u","type":"image","content":"Hi","attachment":{"url":"https://cdn.test/i.jpg","mimeType":"image/jpeg","size":42,"width":1170,"height":2532,"blurhash":"LEHV6nWB2yk8pyo0adR*.7kCMdnj"},"createdAt":"2026-10-12T08:16:00.123Z"}"#.utf8))
        try check(image.attachment?.blurhash?.count == 28 && image.createdAt.timeIntervalSince1970 > 0, "Image and millisecond date decode")
        let voice = try decoder.decode(ChatMessageDTO.self, from: Data(#"{"id":"v","conversationId":"c","senderId":"u","type":"voice","content":"","attachment":null,"mediaUrl":"https://cdn.test/v.m4a","duration":12.4,"fileSize":123456,"mimeType":"audio/mp4","createdAt":"2026-10-12T08:16:00.000Z"}"#.utf8))
        try check(voice.attachment == nil && voice.mediaUrl?.hasSuffix(".m4a") == true && voice.duration == 12.4, "Voice decode")
    }

    static func singleFlightRefresh() async throws {
        let store = PairStoreStub()
        let refresher = RefreshStub()
        let coordinator = TokenRefreshCoordinator(store: store, transport: refresher)
        async let first = coordinator.validAccessToken(afterUnauthorized: "expired")
        async let second = coordinator.validAccessToken(afterUnauthorized: "expired")
        let values = try await [first, second]
        try check(values == ["refreshed-token", "refreshed-token"], "Refresh result")
        let calls = await refresher.calls
        try check(calls == 1, "Refresh was not single-flight")
        try check(store.tokens?.refreshToken == "next-refresh", "Refresh pair not persisted")
    }

    static func refreshFailurePolicies() async throws {
        let replacement = AuthTokens(accessToken: "fresh", refreshToken: "new-refresh", expiresIn: 900)
        let staleStore = PairStoreStub()
        staleStore.tokens = replacement
        let staleTransport = ConfigurableRefreshStub(.success(replacement))
        let staleCoordinator = TokenRefreshCoordinator(store: staleStore, transport: staleTransport)
        let staleValue = try await staleCoordinator.validAccessToken(afterUnauthorized: "expired")
        let staleCalls = await staleTransport.calls
        try check(staleValue == "fresh" && staleCalls == 0, "Stale 401 refreshed again")

        staleStore.sessionGeneration = 1
        do {
            _ = try await staleCoordinator.validAccessToken(afterUnauthorized: "expired", sentGeneration: 0)
            throw CheckFailure(message: "Old account request used new account token")
        } catch RefreshFailure.cancelled { }

        let terminalStore = PairStoreStub()
        let terminalTransport = ConfigurableRefreshStub(.failure(.invalidSession))
        let terminal = TokenRefreshCoordinator(store: terminalStore, transport: terminalTransport,
                                                onExpired: { _ in terminalStore.clear() })
        do {
            _ = try await terminal.validAccessToken(afterUnauthorized: "expired")
            throw CheckFailure(message: "Invalid refresh accepted")
        } catch RefreshFailure.invalidSession { }
        try check(terminalStore.tokens == nil, "Invalid refresh did not clear session")

        for failure in [RefreshFailure.network, .ambiguousNetwork, .server] {
            let store = PairStoreStub()
            let transport = ConfigurableRefreshStub(.failure(failure))
            let coordinator = TokenRefreshCoordinator(store: store, transport: transport)
            do {
                _ = try await coordinator.validAccessToken(afterUnauthorized: "expired")
                throw CheckFailure(message: "Recoverable refresh failure accepted")
            } catch is RefreshFailure { }
            try check(store.tokens?.refreshToken == "current-refresh", "Recoverable failure removed token")
        }

        let limitedStore = PairStoreStub()
        let limitedTransport = ConfigurableRefreshStub(.failure(.rateLimited(until: Date().addingTimeInterval(60))))
        let limited = TokenRefreshCoordinator(store: limitedStore, transport: limitedTransport)
        for _ in 0..<2 {
            do {
                _ = try await limited.validAccessToken(afterUnauthorized: "expired")
                throw CheckFailure(message: "Rate limit ignored")
            } catch RefreshFailure.rateLimited { }
        }
        let limitedCalls = await limitedTransport.calls
        try check(limitedCalls == 1 && limitedStore.tokens != nil, "Rate limit looped or signed out")

        let failedStore = PairStoreStub()
        failedStore.failWrite = true
        let failedTransport = ConfigurableRefreshStub(.success(replacement))
        let failed = TokenRefreshCoordinator(store: failedStore, transport: failedTransport,
                                              onExpired: { _ in failedStore.clear() })
        do {
            _ = try await failed.validAccessToken(afterUnauthorized: "expired")
            throw CheckFailure(message: "Failed Keychain write accepted")
        } catch RefreshFailure.storage { }
        try check(failedStore.tokens == nil, "Failed Keychain write kept old refresh token")
    }

    static func refreshTransportContract() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil; ProtocolStub.responseHeaders = [:] }
        let transport = URLSessionRefreshTransport(baseURL: URL(string: "https://api.test/api/v1")!,
                                                   session: session, logger: NoopNetworkLogger())
        ProtocolStub.handler = { request in
            try check(request.url?.path == "/api/v1/auth/refresh", "Refresh endpoint path")
            try check(request.value(forHTTPHeaderField: "Authorization") == nil, "Refresh sent Bearer")
            let payload: Data
            if let body = request.httpBody { payload = body }
            else if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var collected = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    collected.append(contentsOf: buffer.prefix(count))
                }
                payload = collected
            } else { throw CheckFailure(message: "Refresh request body missing") }
            let body = try JSONSerialization.jsonObject(with: payload) as! [String: Any]
            try check(body["refreshToken"] as? String == "opaque" && body["deviceName"] == nil,
                      "Refresh body contract")
            return (200, Data(#"{"success":true,"message":"Token refreshed successfully.","data":{"token":"new","accessToken":"new","refreshToken":"opaque-next","expiresIn":900}}"#.utf8))
        }
        let value = try await transport.rotate(refreshToken: "opaque")
        try check(value.accessToken == "new" && value.refreshToken == "opaque-next", "Refresh response decode")
        try check(value.accessTokenExpiresAt > Date(), "Absolute token expiry missing")
        for code in ["INVALID_REFRESH_TOKEN", "REFRESH_TOKEN_REUSED"] {
            ProtocolStub.handler = { _ in
                (401, Data("{\"success\":false,\"code\":\"\(code)\",\"message\":\"Sign in again.\"}".utf8))
            }
            do {
                _ = try await transport.rotate(refreshToken: "opaque")
                throw CheckFailure(message: "Terminal refresh code accepted")
            } catch RefreshFailure.invalidSession { }
        }
        ProtocolStub.responseHeaders = ["Retry-After": "47"]
        ProtocolStub.handler = { _ in (429, Data(#"{"success":false,"code":"RATE_LIMITED"}"#.utf8)) }
        do {
            _ = try await transport.rotate(refreshToken: "opaque")
            throw CheckFailure(message: "429 accepted")
        } catch RefreshFailure.rateLimited(let until) {
            try check(until.timeIntervalSinceNow > 40, "Retry-After ignored")
        }
        ProtocolStub.responseHeaders = [:]
        ProtocolStub.handler = { _ in (429, Data(#"{"success":false,"code":"RATE_LIMITED"}"#.utf8)) }
        do {
            _ = try await transport.rotate(refreshToken: "opaque")
            throw CheckFailure(message: "429 without Retry-After accepted")
        } catch RefreshFailure.rateLimited(let until) {
            try check(until.timeIntervalSinceNow >= 59, "Default cooldown missing")
        }
        ProtocolStub.handler = { _ in (503, Data(#"{"success":false}"#.utf8)) }
        do {
            _ = try await transport.rotate(refreshToken: "opaque")
            throw CheckFailure(message: "Refresh 503 accepted")
        } catch RefreshFailure.server { }
        for (code, ambiguous) in [(URLError.notConnectedToInternet, false),
                                  (.dataNotAllowed, false), (.cannotFindHost, false),
                                  (.dnsLookupFailed, false), (.cannotConnectToHost, false),
                                  (.timedOut, true), (.networkConnectionLost, true)] {
            ProtocolStub.handler = { _ in throw URLError(code) }
            do {
                _ = try await transport.rotate(refreshToken: "opaque")
                throw CheckFailure(message: "Refresh network error accepted")
            } catch RefreshFailure.ambiguousNetwork where ambiguous { }
            catch RefreshFailure.network where !ambiguous { }
        }
    }

    static func retryUnauthorizedStops() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil }
        let store = PairStoreStub()
        let transport = ConfigurableRefreshStub(.success(
            AuthTokens(accessToken: "fresh", refreshToken: "next", expiresIn: 900)
        ))
        let expiryCounter = ExpiryCounter()
        let coordinator = TokenRefreshCoordinator(store: store, transport: transport,
                                                   onExpired: { _ in store.clear(); await expiryCounter.record() })
        let client = URLSessionAPIClient(baseURL: URL(string: "https://api.test/api/v1")!, session: session,
                                         tokenProvider: store, logger: NoopNetworkLogger(),
                                         refreshCoordinator: coordinator)
        var requests = 0
        ProtocolStub.handler = { _ in
            requests += 1
            return (401, Data(#"{"success":false,"code":"UNAUTHORIZED"}"#.utf8))
        }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponseDTO<UserDTO>.self)
            throw CheckFailure(message: "Repeated 401 accepted")
        } catch APIError.unauthorized { }
        let refreshCalls = await transport.calls
        let expiryEvents = await expiryCounter.count
        try check(requests == 2 && refreshCalls == 1 && expiryEvents == 1,
                  "Repeated 401 caused a refresh loop or multiple expiry events")
        try check(store.tokens == nil, "Repeated 401 kept revoked session")
    }

    static func lateRefreshCannotExpireNewSession() async throws {
        let store = PairStoreStub()
        let transport = DeferredRefreshStub()
        let counter = ExpiryCounter()
        let coordinator = TokenRefreshCoordinator(store: store, transport: transport,
                                                   onExpired: { _ in await counter.record() })
        let oldRequest = Task { try await coordinator.validAccessToken(afterUnauthorized: "expired", sentGeneration: 0) }
        while !(await transport.started) { await Task.yield() }
        store.sessionGeneration = 1
        store.tokens = AuthTokens(accessToken: "other-account", refreshToken: "other-refresh", expiresIn: 900)
        await transport.failAsReused()
        do {
            _ = try await oldRequest.value
            throw CheckFailure(message: "Old refresh response accepted after new login")
        } catch RefreshFailure.invalidSession { }
        let events = await counter.count
        try check(events == 0 && store.accessToken == "other-account", "Old refresh expired new account")
    }

    static func mediaTransport() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil }
        let token = PairStoreStub()
        let refresher = MediaRefreshStub()
        let coordinator = TokenRefreshCoordinator(store: token, transport: refresher)
        let client = URLSessionAPIClient(baseURL: URL(string: "https://api.test/api/v1")!, session: session,
                                         tokenProvider: token, logger: NoopNetworkLogger(), refreshCoordinator: coordinator)
        let service = MediaUploadService(api: client, session: session)
        var ticketCalls = 0, putCalls = 0
        ProtocolStub.handler = { request in
            if request.url?.host == "api.test" {
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
                    return (401, Data(#"{"success":false,"code":"UNAUTHORIZED"}"#.utf8))
                }
                ticketCalls += 1
                let index = ticketCalls
                let json = #"{"success":true,"data":{"uploadUrl":"https://r2.test/upload?X-Amz-Signature=secret"#
                    + String(index) + #"","method":"PUT","headers":{"Content-Type":"image/jpeg","Content-Length":"4"},"key":"key"#
                    + String(index) + #"","publicUrl":"https://cdn.test/file"# + String(index)
                    + #".jpg","expiresIn":300,"expiresAt":"2099-10-12T08:15:00.000Z"}}"#
                return (201, Data(json.utf8))
            }
            putCalls += 1
            try check(request.httpMethod == "PUT", "R2 method")
            try check(request.value(forHTTPHeaderField: "Authorization") == nil, "Bearer leaked to R2")
            try check(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg", "Signed MIME changed")
            return (putCalls == 1 ? 403 : 204, Data())
        }
        let ticket = try await service.uploadWithFreshTicket(Data([1, 2, 3, 4]), conversationId: "c", kind: .image)
        let refreshCalls = await refresher.calls
        try check(refreshCalls == 1 && token.accessToken == "fresh", "Ticket 401 refresh retry")
        try check(ticketCalls == 2 && putCalls == 2, "PUT 403 did not obtain a fresh ticket")
        try check(ticket.publicURL.absoluteString == "https://cdn.test/file2.jpg", "Retry reused stale public URL")
    }

    static func documentedResponses() throws {
        let document = try String(contentsOfFile: "study/API_INTERGRATION.MD", encoding: .utf8)
        let rest = String(document.components(separatedBy: "## 9. Socket.io")[0])
        let regex = try NSRegularExpression(pattern: "```json\\s*([\\s\\S]*?)\\s*```")
        var count = 0
        for match in regex.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
            let range = Range(match.range(at: 1), in: rest)!
            let data = Data(rest[range].utf8)
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard object?["success"] as? Bool == true else { continue }
            let prefix = rest[..<range.lowerBound]
            let heading = prefix.components(separatedBy: "\n").last(where: { $0.hasPrefix("### ") }) ?? ""
            let decoder = BackendJSONCoding.makeDecoder()
            func decode<T: Codable>(_ type: T.Type) throws {
                let result = try decoder.decode(type, from: data)
                _ = try decoder.decode(type, from: BackendJSONCoding.makeEncoder().encode(result))
            }
            switch heading {
            case "### Register", "### Login", "### Social Login - Google": try decode(APIResponse<AuthDataDTO>.self)
            case "### Get Me": try decode(APIResponse<UserDTO>.self)
            case "### Create Circle", "### Join Circle By Invite Code": try decode(APIResponse<GroupDTO>.self)
            case "### List My Circles": try decode(APIResponse<[GroupDTO]>.self)
            case "### Circle Members": try decode(APIResponse<GroupMembersDTO>.self)
            case "### Update Digest Notification Interval": try decode(APIResponse<NotificationIntervalDTO>.self)
            case "### Add Favorite Place": try decode(APIResponse<PlaceDTO>.self)
            case "### List Favorite Places": try decode(APIResponse<[PlaceDTO]>.self)
            case "### List Circle Digests": try decode(DigestPageDTO.self)
            case "### Latest Circle Digest": try decode(LatestDigestDTO.self)
            case "### List Conversations": try decode(APIResponse<[ConversationDTO]>.self)
            case "### Get Conversation Detail", "### Open Direct 1-1 Conversation", "### Update Group Conversation Metadata":
                try decode(APIResponse<ConversationDTO>.self)
            case "### List Messages": try decode(MessagePageDTO.self)
            case "### Send Message Via REST": try decode(APIResponse<ChatMessageDTO>.self)
            case "### Mark Conversation As Read": try decode(APIResponse<MarkReadDTO>.self)
            case "### Get Conversation Unread Count": try decode(APIResponse<ConversationUnreadDTO>.self)
            case "### Unread Summary": try decode(APIResponse<UnreadSummaryDTO>.self)
            case "### Create Upload Ticket For Chat Image": try decode(APIResponse<UploadTicketDTO>.self)
            case "### Today Location Points": try decode(LocationHistoryDTO.self)
            case "### Day Journey":
                let journey = try decoder.decode(DayJourneyResponseDTO.self, from: data)
                try check(journey.summary?.movingSegmentCount == 3, "Journey moving count")
                try check(journey.journey?.last?.points?.count == 1, "Journey points")
                try decode(DayJourneyResponseDTO.self)
            default: continue // Generic envelope examples in the overview.
            }
            count += 1
        }
        try check(count == 26, "Expected 26 REST response examples, decoded \(count)")
        print("Decoded and round-tripped \(count) documented REST examples")
    }

    static func redaction() throws {
        var request = URLRequest(url: URL(string: "https://user:password@example.test/api?token=jwt&X-Amz-Signature=signature&limit=30#secret")!)
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"password":"secret","nested":{"accessToken":"jwt","email":"alice@example.test","latitude":10.77},"data":[{"content":"private chat","unreadCount":3}]}"#.utf8)
        let safe = DiagnosticRedactor.request(request)
        try check(safe.url?.user == nil && safe.url?.password == nil && safe.url?.fragment == nil, "URL credentials")
        try check(!(safe.url!.absoluteString.contains("jwt")) && !(safe.url!.absoluteString.contains("=signature")), "Query credentials")
        try check(safe.value(forHTTPHeaderField: "Authorization") == "[REDACTED]", "Authorization redaction")
        try check(safe.value(forHTTPHeaderField: "Content-Type") == "application/json", "Content type retained")
        let json = String(data: safe.httpBody!, encoding: .utf8)!
        for value in ["secret", "jwt", "alice@example.test", "10.77", "private chat"] {
            try check(!json.contains(value), "Sensitive body value survived")
        }
        try check(json.contains("unreadCount"), "Useful payload structure retained")
        try check(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret", "Redaction changed actual request")
        let html = DiagnosticRedactor.body(Data("<html>secret</html>".utf8))!
        try check(!String(data: html, encoding: .utf8)!.contains("secret"), "Unstructured body leakage")
        let large = DiagnosticRedactor.body(Data(repeating: 65, count: 256_001))!
        try check(large.count < 100, "Oversized body retained")
        var authRequest = URLRequest(url: URL(string: "https://api.test/api/v1/auth/refresh")!)
        authRequest.httpBody = Data(#"{"refreshToken":"opaque-secret"}"#.utf8)
        try check(DiagnosticRedactor.request(authRequest).httpBody == nil, "Auth request body persisted")
        let authResponse = Data(#"{"data":{"accessToken":"secret","refreshToken":"opaque-secret"}}"#.utf8)
        try check(DiagnosticRedactor.responseBody(authResponse, for: authRequest.url) == nil,
                  "Auth response body persisted")
        let trail = Data(#"{"matched":[{"geometry":{"encoding":"polyline6","data":"secret-route"}}],"points":[{"latitude":10.7,"longitude":106.7}],"revision":4}"#.utf8)
        let safeTrail = String(data: DiagnosticRedactor.body(trail)!, encoding: .utf8)!
        try check(!safeTrail.contains("secret-route") && !safeTrail.contains("10.7") &&
                  safeTrail.contains("revision"), "Trail geometry leaked into diagnostics")
    }

    static func liveTrailAssemblyAndGeometry() throws {
        func point(_ seq: Int) -> LiveTrailPoint {
            LiveTrailPoint(seq: seq, coordinate: GeoPoint(latitude: 10 + Double(seq) * 0.001,
                                                           longitude: 106 + Double(seq) * 0.001),
                           recordedAt: Date(timeIntervalSince1970: Double(seq)),
                           accuracy: 8, motionState: "walking", pointId: nil)
        }
        let snapshot = LiveTrailSnapshot(trailId: "trail", userId: "user", date: "2026-10-18",
                                         timeZone: "Asia/Ho_Chi_Minh", revision: 1, lastSeq: 4,
                                         points: (1...4).map(point),
                                         gaps: [LiveTrailGap(fromSeq: 2, toSeq: 3,
                                                             seconds: 500, meters: 600)],
                                         matches: [], hasMore: false, nextAfterSeq: nil)
        var assembled = try LiveTrailAssembler(firstPage: snapshot)
        let raw = TrailDrawing.build(from: assembled)
        try check(raw.lines.count == 2 && raw.lines.allSatisfy { $0.style == .gps },
                  "Gap must split GPS line")
        let match = LiveTrailMatch(segmentId: "segment", fromSeq: 1, toSeq: 2, status: .final,
                                   geometry: LiveTrailGeometry(encoding: "polyline6",
                                                               data: "_p~iF~ps|U_ulLnnqC"),
                                   provider: "road-provider", providerVersion: "v1", confidence: 0.9,
                                   sourceRevision: "r1", generatedAt: Date())
        try assembled.apply(LiveTrailDelta(userId: "user", trailId: "trail", revision: 1,
                                           afterSeq: 4, toSeq: 2, points: [], matchedUpdates: [match]))
        try check(assembled.cursor == 4, "Match-only delta changed insertion cursor")
        let matched = TrailDrawing.build(from: assembled)
        try check(matched.lines.filter { $0.style == .matched }.count == 1,
                  "Valid real provider did not render matched geometry")
        try check(matched.lines.filter { $0.style == .gps }.count == 1,
                  "Unmatched GPS run was lost")
        do {
            try assembled.apply(LiveTrailDelta(userId: "user", trailId: "trail", revision: 1,
                                               afterSeq: 3, toSeq: 5, points: [point(5)],
                                               matchedUpdates: []))
            throw CheckFailure(message: "Cursor mismatch accepted")
        } catch LiveTrailAssemblyError.unexpectedCursor { }
    }

    static func socketLocationContract() throws {
        let fix = LocationFix(latitude: 10.77, longitude: 106.66,
                              timestamp: Date(timeIntervalSince1970: 1_729_000_000),
                              horizontalAccuracy: 8.5, speed: -1, course: -1)
        let payload = LocationSocketPayload.make(fix: fix, batteryLevel: 80)
        try check(payload["recordedAt"] as? String == ISO8601.string(from: fix.timestamp),
                  "Socket lost GPS measurement time")
        try check(payload["accuracy"] as? Double == 8.5 && payload["batteryLevel"] as? Int == 80,
                  "Socket lost GPS accuracy or battery")
        let invalid = LocationFix(latitude: 10.77, longitude: 106.66,
                                  timestamp: fix.timestamp, horizontalAccuracy: -1,
                                  speed: -1, course: -1)
        try check(LocationSocketPayload.make(fix: invalid, batteryLevel: nil)["accuracy"] == nil,
                  "Negative accuracy must be omitted")
    }

    static func requests() throws {
        func body(_ endpoint: Endpoint) throws -> [String: Any] {
            try JSONSerialization.jsonObject(with: endpoint.encodedBody()!) as! [String: Any]
        }
        let join = try body(GroupEndpoint.join(inviteCode: "001234"))
        try check(join["inviteCode"] as? String == "001234", "Leading zero invite code")
        let social = try body(AuthEndpoint.googleLogin(idToken: "google-id-token"))
        try check(social["token"] as? String == "google-id-token" && social["provider"] as? String == "google", "Social payload")
        try check((social["deviceName"] as? String)?.count ?? 0 <= 100, "Device label too long")
        let refresh = try body(AuthEndpoint.refresh(refreshToken: "opaque"))
        try check(refresh.count == 1 && refresh["refreshToken"] as? String == "opaque", "Refresh body")
        let logout = try body(AuthEndpoint.logout(refreshToken: "opaque"))
        try check(logout["refreshToken"] as? String == "opaque", "Logout body")
        let logoutAllBody = try AuthEndpoint.logoutAll.encodedBody()
        try check(logoutAllBody == nil, "Logout-all body must be empty")
        let clear = try body(ChatEndpoint.update(conversationId: "c", request: .init(avatar: .clear)))
        try check(clear["avatarUrl"] is NSNull, "Explicit null avatar")
        let unchanged = try body(ChatEndpoint.update(conversationId: "c", request: .init(name: "Family")))
        try check(unchanged["avatarUrl"] == nil, "Omitted avatar")
        let read = try body(ChatEndpoint.markRead(conversationId: "c", messageId: nil))
        try check(read.isEmpty, "Read latest must omit messageId")
        let firstPage = ChatEndpoint.messages(conversationId: "c", before: nil)
        try check(firstPage.query.map(\.name) == ["limit"], "Initial page omits cursor")
        let older = ChatEndpoint.messages(conversationId: "c", before: "oldest-id")
        try check(older.query.last?.value == "oldest-id", "Message ID cursor")
        let placeForbidden = APIError.http(
            status: 403,
            code: "FORBIDDEN",
            message: "Server-specific text",
            errors: []
        ).domainError
        try check(placeForbidden == .forbidden, "Non-chat 403 must remain typed as forbidden")
        try check(
            placeForbidden.localizedDescription == L10n.tr("error.forbidden"),
            "Non-chat 403 changed its user-facing message"
        )
        let digest = DigestEndpoint.list(groupId: "g", from: "2026-10-01T00:00:00+07:00", to: "2026-10-02T00:00:00Z")
        try check(digest.query.map(\.name) == ["page", "limit", "from", "to"], "Digest query")
        try check(HistoryEndpoint.today(userId: "u").query.isEmpty, "No undocumented history date")
        let endpoints: [(Endpoint, String, HTTPMethod)] = [
            (AuthEndpoint.login(email: "e", password: "p"), "/auth/login", .POST),
            (AuthEndpoint.register(name: "n", email: "e", password: "p"), "/auth/register", .POST),
            (AuthEndpoint.googleLogin(idToken: "t"), "/auth/social-login", .POST),
            (AuthEndpoint.me, "/auth/me", .GET),
            (GroupEndpoint.list, "/groups", .GET),
            (GroupEndpoint.create(name: "n"), "/groups", .POST),
            (GroupEndpoint.join(inviteCode: "123456"), "/groups/join", .POST),
            (GroupEndpoint.members(groupId: "g"), "/groups/g/members", .GET),
            (GroupEndpoint.updateInterval(groupId: "g", minutes: 0), "/groups/g/notification-interval", .PATCH),
            (PlaceEndpoint.list(groupId: "g"), "/groups/g/places", .GET),
            (PlaceEndpoint.add(groupId: "g", name: "n", category: "cafe", latitude: 10, longitude: 106), "/groups/g/places", .POST),
            (DigestEndpoint.list(groupId: "g"), "/groups/g/digests", .GET),
            (DigestEndpoint.latest(groupId: "g"), "/groups/g/digests/latest", .GET),
            (ChatEndpoint.conversations, "/conversations", .GET),
            (ChatEndpoint.detail(conversationId: "c"), "/conversations/c", .GET),
            (ChatEndpoint.openDirect(userId: "u"), "/conversations/direct", .POST),
            (ChatEndpoint.update(conversationId: "c", request: .init(name: "n")), "/conversations/c", .PATCH),
            (firstPage, "/conversations/c/messages", .GET),
            (ChatEndpoint.send(conversationId: "c", request: .init(type: "text", content: "Hi")), "/conversations/c/messages", .POST),
            (ChatEndpoint.markRead(conversationId: "c", messageId: nil), "/conversations/c/read", .POST),
            (ChatEndpoint.unread(conversationId: "c"), "/conversations/c/unread", .GET),
            (ChatEndpoint.unreadSummary, "/conversations/unread-summary", .GET),
            (ChatEndpoint.mediaTicket(conversationId: "c", kind: .image, fileSize: 42), "/chat/media/presigned-url", .POST),
            (HistoryEndpoint.today(userId: "u"), "/history/u", .GET),
            (HistoryEndpoint.journey(userId: "u", date: "2026-10-01"), "/history/u/journey", .GET),
            (HealthEndpoint.check, "/health", .GET)
        ]
        for (endpoint, path, method) in endpoints {
            try check(endpoint.path == path && endpoint.method == method, "Endpoint \(path)")
            let isPublic = ["/auth/login", "/auth/register", "/auth/social-login", "/health"].contains(path)
            try check(endpoint.requiresAuth != isPublic, "Auth policy \(path)")
            try check(endpoint.headers["Accept"] == "application/json", "Accept header")
            _ = try endpoint.encodedBody()
        }
        do {
            _ = try Endpoint(path: "/test", body: ["invalid": Double.nan]).encodedBody()
            throw CheckFailure(message: "Invalid body was silently encoded")
        } catch APIError.encodingError { }
    }

    static func transport() async throws {
        let token = TokenStub()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProtocolStub.handler = nil }
        let client = URLSessionAPIClient(baseURL: URL(string: "https://example.test/api/v1")!, session: session,
                                         tokenProvider: token, logger: NoopNetworkLogger())
        let ok = Data(#"{"success":true,"data":{"id":"u","name":"Alice"}}"#.utf8)
        ProtocolStub.handler = { request in
            try check(request.url?.path == "/api/v1/auth/me", "Versioned base path")
            try check(request.value(forHTTPHeaderField: "Authorization") == "Bearer keychain-token", "Bearer interceptor")
            try check(request.value(forHTTPHeaderField: "Accept") == "application/json", "Accept")
            return (200, ok)
        }
        _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
        ProtocolStub.handler = { request in
            try check(request.value(forHTTPHeaderField: "Authorization") == nil, "Public endpoint leaked token")
            return (401, Data(#"{"success":false,"code":"UNAUTHORIZED","message":"Bad login"}"#.utf8))
        }
        do {
            _ = try await client.send(AuthEndpoint.googleLogin(idToken: "invalid"), as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Login 401 accepted")
        } catch APIError.http(let status, _, _, _) { try check(status == 401, "Login error status") }
        try check(token.accessToken != nil && token.invalidated.isEmpty, "Login failure invalidated existing session")
        for status in [400, 403, 404, 409, 429, 503] {
            ProtocolStub.handler = { _ in (status, Data(#"{"success":false,"code":"VALIDATION_ERROR","errors":[{"field":"body.email","message":"Invalid email"}]}"#.utf8)) }
            do {
                _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
                throw CheckFailure(message: "HTTP error accepted")
            } catch APIError.http(let actual, let code, _, let errors) {
                try check(actual == status && code == "VALIDATION_ERROR" && errors.first?.field == "body.email", "Structured error lost")
            }
        }
        ProtocolStub.handler = { _ in (500, ok) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Non-2xx success-shaped body accepted")
        } catch APIError.http { }
        ProtocolStub.handler = { _ in (200, Data(#"{"success":false,"message":"Rejected"}"#.utf8)) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Failed envelope accepted")
        } catch APIError.http { }
        ProtocolStub.handler = { _ in (503, Data("<html>Unavailable</html>".utf8)) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "HTML error accepted")
        } catch APIError.http(let status, _, _, _) { try check(status == 503, "HTML status") }
        ProtocolStub.handler = { _ in (200, Data("invalid-json".utf8)) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Malformed success accepted")
        } catch APIError.decodingError { }
        ProtocolStub.handler = { _ in throw URLError(.cancelled) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Cancellation ignored")
        } catch is CancellationError { }
        ProtocolStub.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await withDomainErrors { try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self) }
            throw CheckFailure(message: "Offline ignored")
        } catch DomainError.network { }
        ProtocolStub.handler = { _ in
            token.accessToken = "new-login-token"
            return (401, Data(#"{"success":false}"#.utf8))
        }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Expired auth accepted")
        } catch APIError.unauthorized { }
        try check(token.accessToken == "new-login-token" && token.invalidated == ["keychain-token"], "New login invalidated")
        ProtocolStub.handler = { _ in (200, Data(#"{"success":false,"code":"UNAUTHORIZED"}"#.utf8)) }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Unauthorized envelope accepted")
        } catch APIError.unauthorized { }
        try check(token.accessToken == nil, "Unauthorized code did not clear sent token")
        ProtocolStub.handler = { _ in throw CheckFailure(message: "Missing token reached network") }
        do {
            _ = try await client.send(AuthEndpoint.me, as: APIResponse<UserDTO>.self)
            throw CheckFailure(message: "Missing token accepted")
        } catch APIError.unauthorized { }
    }
}
