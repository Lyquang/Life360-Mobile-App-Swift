import Foundation
import XCTest
@testable import FamilyTracker

@MainActor
final class SOSSessionControllerTests: XCTestCase {
    func testNewerRevisionWinsAndForbiddenClearsState() async {
        let repository = SOSRecoveryStub()
        let controller = SOSSessionController(repository: repository)
        controller.startSession()
        await repository.setDetails([.success(detail(revision: 2)), .success(detail(revision: 3))])
        await controller.refreshDetail(id: "incident", minimumRevision: 3)
        XCTAssertEqual(controller.details["incident"]?.incident.revision, 3)
        await repository.setDetails([.failure(.forbidden)])
        await controller.refreshDetail(id: "incident")
        XCTAssertNil(controller.incidents["incident"])
        XCTAssertNil(controller.details["incident"])
        XCTAssertEqual(controller.lastError, .forbidden)
    }

    func testEqualRevisionReplacesRespondersWhenVisibilityChanges() async {
        let repository = SOSRecoveryStub()
        let controller = SOSSessionController(repository: repository)
        controller.startSession()
        await repository.setDetails([.success(detail(revision: 1, group: "a", responder: "one")),
                                     .success(detail(revision: 1, group: "b", responder: "two"))])
        await controller.refreshDetail(id: "incident")
        await controller.refreshDetail(id: "incident")
        XCTAssertEqual(controller.details["incident"]?.responders.map(\.id), ["two"])
    }

    func testRealtimeEventsAreDeduplicatedAndScopedToSession() async throws {
        let socket = SOSRecoverySocketStub()
        let adapter = SOSRealtimeEventAdapter(socket: socket)
        var iterator = adapter.observe().makeAsyncIterator()
        adapter.startSession()
        adapter.startSession()
        let id = "000000000000000000000001"
        let payload: [String: Any] = ["eventId": id, "sosId": id, "revision": 2]
        let next: [String: Any] = ["eventId": "000000000000000000000002", "sosId": id, "revision": 3]
        socket.deliver(SocketEvent.sosAlertReceive, payload)
        socket.deliver(SocketEvent.sosAlertReceive, payload)
        socket.deliver(SocketEvent.sosUpdated, next)
        let receivedAlert = await iterator.next()
        let receivedUpdate = await iterator.next()
        let alert = try XCTUnwrap(receivedAlert)
        let update = try XCTUnwrap(receivedUpdate)
        XCTAssertEqual(alert.kind, .alert)
        XCTAssertEqual(update.revision, 3)
        XCTAssertEqual(socket.count(SocketEvent.sosAlertReceive), 1)
        adapter.stopSession()
        adapter.startSession()
        XCTAssertFalse(adapter.isCurrent(alert))
    }

    private func detail(revision: Int, group: String = "a", responder: String? = nil) -> SOSDetail {
        let incident = SOSIncident(id: "incident", ownerId: "owner", status: .active, revision: revision,
                                   message: "", location: nil, groupIds: [group],
                                   createdAt: Date(timeIntervalSince1970: 0), closedAt: nil)
        let responders = responder.map {
            [SOSResponder(id: $0, responderId: $0, name: nil, avatar: nil, status: "coming",
                          respondedAt: Date(timeIntervalSince1970: 0))]
        } ?? []
        return SOSDetail(incident: incident, responders: responders, hasMore: false, nextAfterId: nil)
    }
}

private final class SOSRecoverySocketStub: SocketClient {
    var status: SocketConnectionStatus = .disconnected
    private var handlers: [String: [([String: Any]) -> Void]] = [:]
    func connect(token: String) {}
    func disconnect() {}
    func emit(_ event: String, _ payload: [String: Any]) {}
    func emitWithAck(_ event: String, _ payload: [String: Any], timeout: TimeInterval) async throws -> [String: Any] {
        throw SocketClientError.disconnected
    }
    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) { handlers[event, default: []].append(handler) }
    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) {}
    func deliver(_ event: String, _ payload: [String: Any]) { handlers[event]?.forEach { $0(payload) } }
    func count(_ event: String) -> Int { handlers[event]?.count ?? 0 }
}

private actor SOSRecoveryStub: SOSIncidentRepository {
    private var details: [Result<SOSDetail, SOSFailure>] = []
    func setDetails(_ values: [Result<SOSDetail, SOSFailure>]) { details = values }
    func create(_ intent: SOSCreationIntent) async throws -> SOSCreated { throw SOSFailure.unexpected }
    func list(status: SOSListFilter, limit: Int, cursor: String?) async throws -> SOSIncidentPage {
        SOSIncidentPage(items: [], hasMore: false, nextCursor: nil)
    }
    func detail(id: String, limit: Int, afterId: String?) async throws -> SOSDetail {
        guard !details.isEmpty else { throw SOSFailure.unexpected }
        return try details.removeFirst().get()
    }
    func respond(id: String) async throws -> SOSAssistanceResult { throw SOSFailure.unexpected }
    func close(id: String, status: SOSClosure) async throws -> SOSClosed { throw SOSFailure.unexpected }
}
