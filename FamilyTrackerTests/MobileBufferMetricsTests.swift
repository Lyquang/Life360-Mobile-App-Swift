import XCTest
@testable import FamilyTracker

final class MobileBufferMetricsTests: XCTestCase {
    func testBufferBucketsCountsAndMotionLabels() {
        var window = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        window.apply(.bufferSnapshot(depth: 3, oldestAgeSeconds: 299))
        XCTAssertEqual(window.bufferDepthLatest, 3)
        XCTAssertEqual(window.bufferAgeBucketLatest, 0)
        for (age, bucket) in [(300.0, 1), (1_800, 2), (7_200, 3), (86_400, 4)] {
            window.apply(.bufferSnapshot(depth: 2, oldestAgeSeconds: age))
            XCTAssertEqual(window.bufferAgeBucketLatest, bucket)
        }
        XCTAssertEqual(window.bufferDepthPeak, 3)
        window.apply(.bufferSnapshot(depth: -1, oldestAgeSeconds: 0))
        XCTAssertEqual(window.bufferDepthLatest, 2)
        window.apply(.count(.batchPoint, by: 3))
        window.apply(.count(.batchPoint, by: -2))
        XCTAssertEqual(window.counters[.batchPoint], 3)
        window.apply(.locationEmit(motion: .motionWalking))
        window.apply(.locationEmit(motion: .charging))
        XCTAssertEqual(window.counters[.locationEmit], 1)
        XCTAssertEqual(window.locationEmitsByMotion[.motionWalking], 1)
        window.apply(.bufferSnapshot(depth: 0, oldestAgeSeconds: nil))
        XCTAssertNil(window.bufferAgeBucketLatest)
    }

    func testOldWindowWithoutNewFieldsStillDecodes() throws {
        struct LegacyWindow: Codable {
            let start: Date
            let counters: [MobileMetricCounter: Int]
        }
        let legacy = LegacyWindow(start: Date(timeIntervalSince1970: 0), counters: [.fixReceived: 2])
        let window = try JSONDecoder().decode(MobileMetricWindow.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(window.counters[.fixReceived], 2)
        XCTAssertNil(window.bufferDepthLatest)
        XCTAssertTrue(window.locationEmitsByMotion.isEmpty)
    }

    func testBufferSummaryIsOwnerScopedAndUsesOnlyAggregateValues() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let buffer = try LocationBuffer(fileURL: folder.appendingPathComponent("points.jsonl"))
        let start = Date(timeIntervalSince1970: 1_000_000)
        try await buffer.activate(ownerID: "account-a")
        for offset in [0.0, 60.0] {
            let fix = LocationFix(latitude: 10, longitude: 106,
                                  timestamp: start.addingTimeInterval(offset),
                                  horizontalAccuracy: 8, speed: 1, course: -1)
            try await buffer.append(BufferedLocationPoint(fix: fix, batteryLevel: 80),
                                    ownerID: "account-a", now: start.addingTimeInterval(120))
        }
        let summary = await buffer.metricsSummary(ownerID: "account-a", now: start.addingTimeInterval(120))
        XCTAssertEqual(summary.depth, 2)
        XCTAssertEqual(summary.oldestAgeSeconds, 120)
        let other = await buffer.metricsSummary(ownerID: "account-b", now: start.addingTimeInterval(120))
        XCTAssertEqual(other.depth, 0)
        XCTAssertNil(other.oldestAgeSeconds)
        try await buffer.clear()
        let cleared = await buffer.metricsSummary(ownerID: "account-a", now: start.addingTimeInterval(120))
        XCTAssertEqual(cleared.depth, 0)
    }

    func testSerializedSummaryContainsNoLocationOrIdentity() throws {
        var window = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        window.apply(.bufferSnapshot(depth: 2, oldestAgeSeconds: 600))
        window.apply(.locationEmit(motion: .motionAutomotive))
        let text = try XCTUnwrap(String(data: JSONEncoder().encode(window), encoding: .utf8)).lowercased()
        for forbidden in ["latitude", "longitude", "pointid", "ownerid", "userid", "token", "email"] {
            XCTAssertFalse(text.contains(forbidden))
        }
    }
}
