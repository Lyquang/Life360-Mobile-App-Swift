import XCTest
@testable import FamilyTracker

@MainActor
final class LocationRoutingTests: XCTestCase {
    func testDuplicateReadyDoesNotCreateAnotherReadinessTransition() async {
        let socket = RoutingSocket()
        let queue = OfflineQueue(fileName: "routing-\(UUID()).json")
        defer { queue.clear() }
        let repository = SocketRealtimeRepository(socket: socket, offlineQueue: queue)
        var readiness = repository.observeSessionReadiness().makeAsyncIterator()
        socket.changeStatus(.connected)
        socket.receive(SocketEvent.sessionReady)
        socket.receive(SocketEvent.sessionReady)
        socket.changeStatus(.disconnected)
        let first = await readiness.next()
        let second = await readiness.next()
        XCTAssertEqual(first, true)
        XCTAssertEqual(second, false)
    }

    func testRealtimePayloadRemainsUnchanged() {
        let socket = RoutingSocket()
        let queue = OfflineQueue(fileName: "routing-\(UUID()).json")
        defer { queue.clear() }
        let repository = SocketRealtimeRepository(socket: socket, offlineQueue: queue)
        let fix = LocationFix(latitude: 10, longitude: 106, timestamp: Date(),
                              horizontalAccuracy: -1, speed: 4, course: 90)
        socket.changeStatus(.connected)
        repository.sendLocation(fix, batteryLevel: 50)
        XCTAssertTrue(socket.events.isEmpty)
        XCTAssertEqual(queue.count, 0)
        socket.receive(SocketEvent.sessionReady)
        repository.sendLocation(fix, batteryLevel: 50)
        XCTAssertEqual(socket.events.count, 1)
        let payload = socket.events[0].1
        XCTAssertEqual(Set(payload.keys), ["latitude", "longitude", "batteryLevel"])
    }

    func testLegacyLocationIsDiscardedButSOSStillReplays() {
        let socket = RoutingSocket()
        let queue = OfflineQueue(fileName: "routing-\(UUID()).json")
        defer { queue.clear() }
        queue.enqueue(event: SocketEvent.updateLocation, payload: ["latitude": 10, "longitude": 106])
        queue.enqueue(event: SocketEvent.sosAlert, payload: ["message": "SOS"])
        let repository = SocketRealtimeRepository(socket: socket, offlineQueue: queue)
        socket.changeStatus(.connected)
        XCTAssertEqual(socket.events.map(\.0), [SocketEvent.sosAlert])
        withExtendedLifetime(repository) {}
    }

    func testTransportConnectionIsNotAuthenticatedReadiness() {
        let socket = RoutingSocket()
        let queue = OfflineQueue(fileName: "routing-\(UUID()).json")
        defer { queue.clear() }
        let repository = SocketRealtimeRepository(socket: socket, offlineQueue: queue)
        socket.changeStatus(.connected)
        XCTAssertFalse(repository.isSessionReady)
        socket.receive(SocketEvent.sessionReady)
        XCTAssertTrue(repository.isSessionReady)
        socket.changeStatus(.disconnected)
        XCTAssertFalse(repository.isSessionReady)
        socket.receive(SocketEvent.sessionReady)
        XCTAssertFalse(repository.isSessionReady)
        socket.changeStatus(.connected)
        XCTAssertFalse(repository.isSessionReady)
        socket.receive(SocketEvent.sessionReady)
        repository.disconnect()
        XCTAssertFalse(repository.isSessionReady)
    }
}

private final class RoutingSocket: SocketClient {
    var status: SocketConnectionStatus = .disconnected
    var events: [(String, [String: Any])] = []
    private var handlers: [String: ([String: Any]) -> Void] = [:]
    private var statusHandler: ((SocketConnectionStatus) -> Void)?
    func connect(token: String) { changeStatus(.connecting) }
    func disconnect() { changeStatus(.disconnected) }
    func emit(_ event: String, _ payload: [String: Any]) { events.append((event, payload)) }
    func emitWithAck(_ event: String, _ payload: [String: Any], timeout: TimeInterval) async throws -> [String: Any] { [:] }
    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) { handlers[event] = handler }
    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) { statusHandler = handler }
    func changeStatus(_ value: SocketConnectionStatus) { status = value; statusHandler?(value) }
    func receive(_ event: String) { handlers[event]?([:]) }
}
