import XCTest
@testable import FamilyTracker

@MainActor
final class LocationReconnectTests: XCTestCase {
    func testFreshTimeoutStartsHistoryWithoutSendingCachedFix() async {
        let date = Date()
        let device = ReconnectDevice()
        let live = ReconnectLive()
        live.isSessionReady = true
        let history = expectation(description: "History sync after fresh-fix deadline")
        let sharing = ShareLocationUseCase(deviceLocation: device, liveLocation: live,
                                           deviceStatus: ReconnectBattery(),
                                           sleeper: { nanos in
                                               guard nanos == 10_000_000_000 else { throw CancellationError() }
                                           }, now: { date }, onHistorySync: { history.fulfill() })
        sharing.start()
        await fulfillment(of: [history], timeout: 1)
        sharing.handle(fix(at: date.addingTimeInterval(-30)), now: date)
        XCTAssertTrue(live.sent.isEmpty)
        sharing.stop()
    }

    func testReconnectWaitsForFreshFixThenSendsBeforeSync() {
        let date = Date()
        let device = ReconnectDevice()
        let live = ReconnectLive()
        var order: [String] = []
        live.onSend = { order.append("realtime") }
        let sharing = ShareLocationUseCase(deviceLocation: device, liveLocation: live,
                                           deviceStatus: ReconnectBattery(),
                                           sleeper: { _ in throw CancellationError() }, now: { date },
                                           onHistorySync: { order.append("batch") })
        live.isSessionReady = true
        sharing.start()
        XCTAssertEqual(device.freshRequests, 1)
        sharing.handle(fix(at: date.addingTimeInterval(-1)), now: date)
        XCTAssertTrue(live.sent.isEmpty)
        let fresh = fix(at: date.addingTimeInterval(1))
        sharing.handle(fresh, now: date.addingTimeInterval(1))
        XCTAssertEqual(live.sent, [fresh])
        XCTAssertEqual(order, ["realtime", "batch"])
        sharing.stop()
    }

    func testOfflineFixStillUsesPolicyAndReconnectDropsCachedPending() {
        let date = Date()
        let device = ReconnectDevice()
        let live = ReconnectLive()
        let sharing = ShareLocationUseCase(deviceLocation: device, liveLocation: live,
                                           deviceStatus: ReconnectBattery(),
                                           sleeper: { _ in throw CancellationError() }, now: { date })
        sharing.start()
        let offline = fix(at: date.addingTimeInterval(-5))
        sharing.handle(offline, now: date)
        XCTAssertEqual(live.sent, [offline])
        live.isSessionReady = true
        sharing.handle(offline, now: date.addingTimeInterval(31))
        XCTAssertEqual(device.freshRequests, 1)
        XCTAssertEqual(live.sent, [offline])
        sharing.stop()
    }

    private func fix(at date: Date) -> LocationFix {
        LocationFix(latitude: 10, longitude: 106, timestamp: date, horizontalAccuracy: 5, speed: 0, course: -1)
    }
}

private final class ReconnectDevice: DeviceLocationRepository {
    var authorization: LocationAuthorization = .always
    var lastKnownLocation: GeoPoint? { nil }
    var lastKnownFix: LocationFix? { nil }
    var currentMotionState: MotionState { .stationary }
    var freshRequests = 0
    func requestPermission() {}
    func startTracking() {}
    func stopTracking() {}
    func requestFreshLocation() { freshRequests += 1 }
    func observeLocations() -> AsyncStream<GeoPoint> { AsyncStream { $0.finish() } }
    func observeFixes() -> AsyncStream<LocationFix> { AsyncStream { $0.finish() } }
    func observeMotionStates() -> AsyncStream<MotionState> { AsyncStream { $0.finish() } }
}

private final class ReconnectLive: LiveLocationRepository {
    var isSessionReady = false
    var sent: [LocationFix] = []
    var onSend: (() -> Void)?
    func sendLocation(_ fix: LocationFix, batteryLevel: Int?) { sent.append(fix); onSend?() }
    func observeMemberLocations() -> AsyncStream<MemberLocation> { AsyncStream { $0.finish() } }
    func observeStayAlerts() -> AsyncStream<LocationStayAlert> { AsyncStream { $0.finish() } }
    func observePresence() -> AsyncStream<MemberPresence> { AsyncStream { $0.finish() } }
}

@MainActor
private final class ReconnectBattery: DeviceStatusRepository {
    var batteryLevel: Int? { 70 }
}
