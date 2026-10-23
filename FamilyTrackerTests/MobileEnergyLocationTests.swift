import XCTest
@testable import FamilyTracker

final class MobileEnergyLocationTests: XCTestCase {
    func testStateTimeIsSplitAtWindowBoundaryWithoutTimer() async {
        let clock = EnergyTestClock(Date(timeIntervalSince1970: 0))
        let collector = MobileMetricsCollector(store: makeStore(), now: { clock.read() })
        await collector.record(.state(.foreground))
        await collector.record(.state(.motionWalking))
        clock.set(Date(timeIntervalSince1970: 450))
        await collector.record(.state(.background))
        clock.set(Date(timeIntervalSince1970: 1_800))
        let windows = await collector.snapshot()
        #if DEBUG
        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows[0].secondsByState[.foreground], 450)
        XCTAssertEqual(windows[0].secondsByState[.background], 450)
        XCTAssertEqual(windows[0].secondsByState[.motionWalking], 900)
        XCTAssertEqual(windows[1].secondsByState[.background], 900)
        XCTAssertEqual(windows[1].secondsByState[.motionWalking], 900)
        #else
        XCTAssertTrue(windows.isEmpty)
        #endif
    }

    func testAccuracyBucketsAndBatteryBounds() async {
        let collector = MobileMetricsCollector(store: makeStore())
        for accuracy in [-1.0, 5, 25, 75, 150, .infinity] {
            await collector.record(.horizontalAccuracy(accuracy))
        }
        await collector.record(.batteryLevel(-1))
        await collector.record(.batteryLevel(80))
        await collector.record(.batteryLevel(78))
        let windows = await collector.snapshot()
        #if DEBUG
        XCTAssertEqual(windows.first?.horizontalAccuracyBuckets, [1, 1, 1, 1, 2])
        XCTAssertEqual(windows.first?.batteryStart, 80)
        XCTAssertEqual(windows.first?.batteryEnd, 78)
        #else
        XCTAssertTrue(windows.isEmpty)
        #endif
    }

    func testWholeDeviceBatteryTrendNeedsReliableSample() {
        let trend = WholeDeviceBatteryTrend.percentagePointsPerHour(
            start: 80, end: 78, seconds: 3_600,
            charged: false, powerModeChanged: false, thermalChanged: false)
        XCTAssertEqual(trend, 2)
        XCTAssertNil(WholeDeviceBatteryTrend.percentagePointsPerHour(
            start: 80, end: 79, seconds: 900,
            charged: false, powerModeChanged: false, thermalChanged: false))
        XCTAssertNil(WholeDeviceBatteryTrend.percentagePointsPerHour(
            start: 80, end: 78, seconds: 3_600,
            charged: true, powerModeChanged: false, thermalChanged: false))
        XCTAssertNil(WholeDeviceBatteryTrend.percentagePointsPerHour(
            start: 80, end: 78, seconds: 3_600,
            charged: false, powerModeChanged: true, thermalChanged: false))
    }

    func testStateAndAccuracySummaryContainsNoSensitiveFields() throws {
        var window = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        window.secondsByState[.motionWalking] = 30
        window.apply(.horizontalAccuracy(22))
        let text = try XCTUnwrap(String(data: JSONEncoder().encode(window), encoding: .utf8)).lowercased()
        for forbidden in ["latitude", "longitude", "userid", "token", "email", "ssid", "message"] {
            XCTAssertFalse(text.contains(forbidden))
        }
    }

    private func makeStore() -> MobileMetricsStore {
        MobileMetricsStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))
    }
}

private final class EnergyTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ date: Date) { value = date }

    func read() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        value = date
    }
}
