import XCTest
@testable import FamilyTracker

@MainActor
final class LocationDiagnosticsTests: XCTestCase {
    func testCountersMotionBucketsBatterySegmentsAndReset() {
        let logger = LocationLoggerStub()
        let battery = BatterySnapshot()
        let diagnostics = LocationDiagnostics(logger: logger, battery: battery, observesBackground: false)
        let start = Date(timeIntervalSince1970: 1_000)

        diagnostics.startSession(batteryLevel: 90, now: start)
        battery.level = 89
        diagnostics.recordMotion(.walking, now: start.addingTimeInterval(10))
        diagnostics.recordMotion(.walking, now: start.addingTimeInterval(11))
        diagnostics.recordEmit()
        diagnostics.recordHeartbeatAttempt()
        diagnostics.recordManagerReconfiguration()
        diagnostics.recordDrop(.invalidHorizontalAccuracy)
        diagnostics.recordPolicyDecision(outcome: .hold, reason: "minimumInterval")
        diagnostics.recordPolicyDecision(outcome: .send, reason: "trailingEdge")
        battery.level = 88
        diagnostics.recordMotion(.automotive, now: start.addingTimeInterval(40))
        diagnostics.recordEmit()
        diagnostics.recordOfflineEnqueue()

        let counters = diagnostics.snapshot()
        #if DEBUG
        XCTAssertEqual(counters.emitted, ["walking": 1, "automotive": 1])
        XCTAssertEqual(counters.motionTransitions, 2)
        XCTAssertEqual(counters.heartbeatAttempts, 1)
        XCTAssertEqual(counters.managerReconfigurations, 1)
        XCTAssertEqual(counters.dropped["invalidHorizontalAccuracy"], 1)
        XCTAssertEqual(counters.offlineQueueEnqueues, 1)
        XCTAssertEqual(counters.policyDecisions["hold.minimumInterval"], 1)
        XCTAssertEqual(counters.policyDecisions["send.trailingEdge"], 1)
        let summary = diagnostics.summary(now: start.addingTimeInterval(50))
        XCTAssertEqual(summary?["startBatteryPercent"] as? Int, 90)
        XCTAssertEqual((summary?["batteryDropByMotionPercentagePoints"] as? [String: Int])?["walking"], 1)
        #else
        XCTAssertTrue(counters.emitted.isEmpty)
        XCTAssertEqual(counters.motionTransitions, 0)
        XCTAssertNil(diagnostics.summary())
        #endif

        diagnostics.stopSession(batteryLevel: 87, now: start.addingTimeInterval(60))
        #if DEBUG
        XCTAssertEqual(logger.events, ["location_diagnostics_summary"])
        XCTAssertEqual(logger.payloads.first?["endBatteryPercent"] as? Int, 87)
        #else
        XCTAssertTrue(logger.events.isEmpty)
        #endif
        diagnostics.reset()
        XCTAssertTrue(diagnostics.snapshot().emitted.isEmpty)
        XCTAssertEqual(diagnostics.snapshot().motionTransitions, 0)
    }

    func testLegacyQueuedLocationIsNotReplayedOrCountedAsNewEmit() {
        let battery = BatterySnapshot()
        let diagnostics = LocationDiagnostics(logger: LocationLoggerStub(), battery: battery,
                                              observesBackground: false)
        diagnostics.startSession(batteryLevel: nil)
        diagnostics.recordMotion(.stationary)
        let socket = LocationSocketStub()
        let queue = OfflineQueue(fileName: "location-diagnostics-tests-\(UUID()).json")
        let repository = SocketRealtimeRepository(socket: socket, offlineQueue: queue, diagnostics: diagnostics)

        queue.enqueue(event: SocketEvent.updateLocation, payload: ["latitude": 10, "longitude": 106], coalesceKey: "location")
        #if DEBUG
        XCTAssertEqual(diagnostics.snapshot().offlineQueueEnqueues, 0)
        #endif
        XCTAssertEqual(queue.count, 1)
        socket.setStatus(.connected)

        XCTAssertTrue(socket.emittedEvents.isEmpty)
        #if DEBUG
        XCTAssertNil(diagnostics.snapshot().emitted["stationary"])
        #endif
        diagnostics.stopSession(batteryLevel: nil)
        withExtendedLifetime(repository) {}
    }

    func testSummaryContainsNoCoordinatesOrTokenAndDisabledInstanceIsNoop() throws {
        let logger = LocationLoggerStub()
        let battery = BatterySnapshot()
        let diagnostics = LocationDiagnostics(logger: logger, battery: battery, observesBackground: false)
        diagnostics.startSession(batteryLevel: 80)
        diagnostics.recordEmit()
        diagnostics.logSummary()

        #if DEBUG
        let payload = try XCTUnwrap(logger.payloads.first)
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8)).lowercased()
        XCTAssertFalse(text.contains("latitude"))
        XCTAssertFalse(text.contains("longitude"))
        XCTAssertFalse(text.contains("token"))
        XCTAssertFalse(text.contains("106."))
        #else
        XCTAssertTrue(logger.payloads.isEmpty)
        #endif

        let disabled = LocationDiagnostics(logger: logger, battery: battery, enabled: false,
                                           observesBackground: false)
        disabled.startSession(batteryLevel: 80)
        disabled.recordMotion(.walking)
        disabled.recordEmit()
        disabled.recordHeartbeatAttempt()
        disabled.logSummary()
        XCTAssertTrue(disabled.snapshot().emitted.isEmpty)
        XCTAssertEqual(disabled.snapshot().heartbeatAttempts, 0)
        XCTAssertNil(disabled.summary())
        diagnostics.reset()
    }
}

private final class LocationLoggerStub: NetworkLogger {
    var events: [String] = []
    var payloads: [[String: Any]] = []
    func logRequest(id: UUID, method: String, url: String, body: [String: Any]?) {}
    func logResponse(id: UUID, method: String, url: String, statusCode: Int, data: Data, duration: TimeInterval) {}
    func logError(id: UUID, method: String, url: String, message: String, duration: TimeInterval) {}
    func logSocket(event: String, payload: Any) {
        events.append(event)
        if let payload = payload as? [String: Any] { payloads.append(payload) }
    }
}

private final class LocationSocketStub: SocketClient {
    var status: SocketConnectionStatus = .disconnected
    var emittedEvents: [String] = []
    private var statusHandler: ((SocketConnectionStatus) -> Void)?
    func connect(token: String) {}
    func disconnect() {}
    func emit(_ event: String, _ payload: [String: Any]) { emittedEvents.append(event) }
    func emitWithAck(_ event: String, _ payload: [String: Any], timeout: TimeInterval) async throws -> [String: Any] {
        [:]
    }
    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) {}
    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) { statusHandler = handler }
    func setStatus(_ status: SocketConnectionStatus) {
        self.status = status
        statusHandler?(status)
    }
}
