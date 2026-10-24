import Foundation
import XCTest
@testable import FamilyTracker

final class MetricKitSummaryTests: XCTestCase {
    func testMissingInvalidAndMixedVersionValues() throws {
        var summary = try XCTUnwrap(MetricKitSummary(
            kind: .metrics, start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 86_400), appVersion: "1.2.3", mixedVersions: false))
        summary.set(.cpuSeconds, 120)
        summary.set(.foregroundSeconds, nil)
        summary.set(.backgroundSeconds, -.infinity)
        summary.set(.locationBestSeconds, -1)
        XCTAssertEqual(summary.values, [.cpuSeconds: 120])
        XCTAssertEqual(summary.appVersion, "1.2.3")
        XCTAssertTrue(summary.isValid)
        XCTAssertEqual(MetricKitSummary.seconds(Measurement(value: 2, unit: UnitDuration.minutes)), 120)
        XCTAssertEqual(MetricKitSummary.bytes(Measurement(value: 512, unit: UnitInformationStorage.bytes)), 512)

        let mixed = try XCTUnwrap(MetricKitSummary(
            kind: .metrics, start: summary.start, end: summary.end,
            appVersion: "1.2.3", mixedVersions: true))
        XCTAssertNil(mixed.appVersion)
        let unsafe = try XCTUnwrap(MetricKitSummary(
            kind: .metrics, start: summary.start, end: summary.end,
            appVersion: "private/user-id", mixedVersions: false))
        XCTAssertNil(unsafe.appVersion)
        XCTAssertNil(MetricKitSummary(kind: .metrics, start: summary.end, end: summary.start,
                                      appVersion: nil, mixedVersions: false))
    }

    func testMergeIsIdempotentKeepsKindsAndCapsReports() throws {
        let first = try makeSummary(day: 0, kind: .metrics)
        var updated = first
        updated.set(.cpuSeconds, 42)
        let diagnostic = try makeSummary(day: 0, kind: .diagnostics)
        var reports = MetricKitSummary.merging([first], with: [updated, diagnostic])
        XCTAssertEqual(reports.count, 2)
        XCTAssertEqual(reports.first { $0.kind == .metrics }?.values[.cpuSeconds], 42)
        reports = MetricKitSummary.merging(reports, with: try (1...20).map { try makeSummary(day: $0) })
        XCTAssertEqual(reports.count, 14)
        XCTAssertEqual(reports.first?.start, Date(timeIntervalSince1970: 7 * 86_400))
    }

    func testStorePersistsOnlyBoundedAggregatesAndClears() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MetricKitSummaryStore(directory: directory)
        store.save(try (0...20).map { try makeSummary(day: $0) })
        XCTAssertEqual(store.load().count, 14)
        let data = try Data(contentsOf: directory.appendingPathComponent("summaries.json"))
        XCTAssertLessThanOrEqual(data.count, 128 * 1_024)
        let text = String(decoding: data, as: UTF8.self)
        for forbidden in ["latitude", "longitude", "userId", "token", "email", "callStack", "SSID"] {
            XCTAssertFalse(text.contains(forbidden))
        }
        let resources = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(resources.isExcludedFromBackup, true)
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent("summaries.json"), options: .atomic)
        XCTAssertTrue(store.load().isEmpty)
        store.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    private func makeSummary(day: Int, kind: MetricKitSummary.Kind = .metrics) throws -> MetricKitSummary {
        try XCTUnwrap(MetricKitSummary(kind: kind,
                                       start: Date(timeIntervalSince1970: Double(day * 86_400)),
                                       end: Date(timeIntervalSince1970: Double((day + 1) * 86_400)),
                                       appVersion: "1.0", mixedVersions: false))
    }
}
