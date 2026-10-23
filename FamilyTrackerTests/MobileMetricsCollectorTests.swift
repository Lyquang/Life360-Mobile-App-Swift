import XCTest
@testable import FamilyTracker

final class MobileMetricsCollectorTests: XCTestCase {
    func testWindowBucketsAndClockBoundary() async {
        let clock = MetricsTestClock(Date(timeIntervalSince1970: 0))
        let collector = MobileMetricsCollector(store: temporaryStore(), now: { clock.read() })
        await collector.record(.increment(.fixReceived))
        await collector.record(.latency(.chat, milliseconds: 99))
        await collector.record(.latency(.chat, milliseconds: 500))
        await collector.record(.bytes(.cellular, sent: 1_024, received: 2_048))
        #if DEBUG
        var windows = await collector.snapshot()
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].counters[.fixReceived], 1)
        XCTAssertEqual(windows[0].latencyBuckets[.chat], [1, 0, 1, 0])
        XCTAssertEqual(windows[0].sentBytes[.cellular], 1_024)
        XCTAssertEqual(windows[0].receivedBytes[.cellular], 2_048)
        #endif
        clock.set(Date(timeIntervalSince1970: 900))
        await collector.record(.increment(.locationEmit))
        #if DEBUG
        windows = await collector.snapshot()
        XCTAssertEqual(windows.map(\.start), [Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 900)])
        XCTAssertEqual(windows[1].counters[.locationEmit], 1)
        #else
        let releaseWindows = await collector.snapshot()
        XCTAssertTrue(releaseWindows.isEmpty)
        #endif
    }

    func testRejectsInvalidNumbersAndUnknownLabels() throws {
        var window = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        window.apply(.latency(.auth, milliseconds: -1))
        window.apply(.bytes(.wifi, sent: -10, received: 100))
        XCTAssertTrue(window.latencyBuckets.isEmpty)
        XCTAssertTrue(window.sentBytes.isEmpty)
        XCTAssertThrowsError(try JSONDecoder().decode(MobileMetricCounter.self, from: Data("\"userId\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(MobileEndpointGroup.self, from: Data("\"/users/123\"".utf8)))
    }

    func testStoreCapCorruptionPrivacyAndClear() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MobileMetricsStore(directory: directory)
        let windows = (0..<120).map { offset -> MobileMetricWindow in
            var window = MobileMetricWindow(start: Date(timeIntervalSince1970: Double(offset * 900)))
            window.apply(.increment(.request))
            return window
        }
        store.save(windows)
        store.save(Array(windows.suffix(100)))
        XCTAssertEqual(store.load().count, 96)
        let data = try Data(contentsOf: directory.appendingPathComponent("windows.json"))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8)).lowercased()
        for forbidden in ["latitude", "longitude", "userid", "token", "email", "message", "ssid", "deviceid"] {
            XCTAssertFalse(text.contains(forbidden), "Found forbidden key: \(forbidden)")
        }
        XCTAssertLessThanOrEqual(data.count, 256 * 1_024)
        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
        var malformed = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        malformed.latencyBuckets[.auth] = [1]
        let malformedData = try JSONEncoder().encode([malformed])
        try malformedData.write(to: directory.appendingPathComponent("windows.json"), options: .atomic)
        XCTAssertTrue(store.load().isEmpty)
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent("windows.json"), options: .atomic)
        XCTAssertTrue(store.load().isEmpty)
        store.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testDisabledCollectorHasNoSnapshotOrDisk() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collector = MobileMetricsCollector(store: MobileMetricsStore(directory: directory), enabled: false)
        await collector.record(.increment(.request))
        let snapshot = await collector.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testDisableDeletesExistingData() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = MetricsTestClock(Date(timeIntervalSince1970: 0))
        let collector = MobileMetricsCollector(store: MobileMetricsStore(directory: directory), now: { clock.read() })
        await collector.record(.increment(.request))
        clock.set(Date(timeIntervalSince1970: 900))
        await collector.record(.increment(.request))
        await collector.setEnabled(false)
        let snapshot = await collector.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    private func temporaryStore() -> MobileMetricsStore {
        MobileMetricsStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))
    }
}

private final class MetricsTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) { self.value = value }

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
