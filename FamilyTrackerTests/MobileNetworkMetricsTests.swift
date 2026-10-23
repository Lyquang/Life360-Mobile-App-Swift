import Foundation
import XCTest
@testable import FamilyTracker

final class MobileNetworkMetricsTests: XCTestCase {
    func testRouteGroupingNeverStoresDynamicIDs() {
        XCTAssertEqual(RESTMetricGroup.classify("/auth/refresh"), .auth)
        XCTAssertEqual(RESTMetricGroup.classify("/groups/private-id/members"), .groups)
        XCTAssertEqual(RESTMetricGroup.classify("/conversations/private-id/messages"), .chat)
        XCTAssertEqual(RESTMetricGroup.classify("/history/private-id/journey"), .history)
        XCTAssertEqual(RESTMetricGroup.classify("/history/private-id/journey/trail"), .trail)
        XCTAssertEqual(RESTMetricGroup.classify("/groups/private-id/places"), .places)
        XCTAssertEqual(RESTMetricGroup.classify("/locations/batch"), .locationBatch)
        XCTAssertEqual(RESTMetricGroup.classify("/unknown/private-id"), .other)
        XCTAssertEqual(RESTMetricGroup.classify(""), .other)
    }

    func testByteCountsAreBoundedAndNeverNegative() {
        XCTAssertEqual(NetworkTaskMetricsDelegate.safeTotal(100, 200), 300)
        XCTAssertEqual(NetworkTaskMetricsDelegate.safeTotal(-1, 200), 0)
        XCTAssertEqual(NetworkTaskMetricsDelegate.safeTotal(Int64.max, 1), Int.max)
    }

    func testRESTFailureAndLatencyUseOnlyTypedLabels() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collector = MobileMetricsCollector(store: MobileMetricsStore(directory: directory))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MetricURLProtocol.self]
        MetricURLProtocol.statusCode = 503
        let client = URLSessionAPIClient(baseURL: URL(string: "https://example.test/api/v1")!,
                                         session: URLSession(configuration: configuration),
                                         tokenProvider: MetricTokenProvider(), logger: NoopNetworkLogger(),
                                         metrics: collector)
        do {
            _ = try await client.send(Endpoint(path: "/groups/private-member-id"), as: APIErrorResponseDTO.self)
            XCTFail("503 must fail")
        } catch APIError.http(let status, _, _, _) {
            XCTAssertEqual(status, 503)
        }
        #if DEBUG
        let windows = await collector.snapshot()
        XCTAssertEqual(windows.last?.counters[.request], 1)
        XCTAssertEqual(windows.last?.counters[.requestFailure], 1)
        XCTAssertEqual(windows.last?.latencyBuckets[.groups]?.reduce(0, +), 1)
        let encoded = try JSONEncoder().encode(windows)
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(text.contains("private-member-id"))
        XCTAssertFalse(text.contains("example.test"))
        #else
        let windows = await collector.snapshot()
        XCTAssertTrue(windows.isEmpty)
        #endif
    }
}

private final class MetricTokenProvider: AccessTokenProvider {
    let accessToken: String? = "secret-access-token"
    func invalidate(token: String) {}
}

private final class MetricURLProtocol: URLProtocol {
    static var statusCode = 503

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"success":false,"code":"SERVICE_UNAVAILABLE"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
