#if DEBUG
import XCTest
@testable import FamilyTracker

final class MobileMonitoringReportTests: XCTestCase {
    func testExportContainsOnlyTypedAggregateSections() throws {
        var window = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        window.counters[.locationEmit] = 3
        let data = try MobileMonitoringReport(windows: [window], metricKit: []).encoded()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["windows", "metricKit"])
        let decoded = try JSONDecoder().decode(MobileMonitoringReport.self, from: data)
        XCTAssertEqual(decoded.windows.first?.counters[.locationEmit], 3)
        let text = String(decoding: data, as: UTF8.self)
        for forbidden in ["latitude", "longitude", "userId", "token", "email", "SSID", "identifierForVendor"] {
            XCTAssertFalse(text.contains(forbidden))
        }
    }

    func testExportRejectsOversizedReport() {
        let window = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        let report = MobileMonitoringReport(windows: Array(repeating: window, count: 2_000), metricKit: [])
        XCTAssertThrowsError(try report.encoded())
    }
}
#endif
