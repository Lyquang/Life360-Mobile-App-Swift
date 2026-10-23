import Foundation
import XCTest
@testable import FamilyTracker

final class MobileMediaMetricsTests: XCTestCase {
    func testMediaBytesRemainSeparateFromRESTAndSocket() throws {
        var window = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        window.apply(.mediaTransfer(.imageUpload, network: .cellular, sent: 512, received: 32))
        window.apply(.mediaTransfer(.voiceUpload, network: .wifi, sent: 256, received: 16))
        window.apply(.bytes(.cellular, sent: 10, received: 20))
        window.apply(.socketPayload(.chatSendMessage, network: .cellular, sent: 5, received: 3))
        XCTAssertEqual(window.mediaSentBytesByKind[.imageUpload], 512)
        XCTAssertEqual(window.mediaSentBytesByKind[.voiceUpload], 256)
        XCTAssertEqual(window.mediaSentBytesByNetwork[.cellular], 512)
        XCTAssertEqual(window.mediaReceivedBytesByNetwork[.wifi], 16)
        XCTAssertEqual(window.sentBytes[.cellular], 10)
        XCTAssertEqual(window.socketSentBytesByNetwork[.cellular], 5)
        let encoded = try JSONEncoder().encode(window)
        XCTAssertEqual(try JSONDecoder().decode(MobileMetricWindow.self, from: encoded), window)
    }

    func testInvalidMediaMeasurementsAndOldWindows() throws {
        var window = MobileMetricWindow(start: Date())
        window.apply(.mediaTransfer(.imageUpload, network: .wifi, sent: -1, received: 10))
        XCTAssertTrue(window.mediaSentBytesByKind.isEmpty)
        let old = try JSONDecoder().decode(MobileMetricWindow.self,
                                           from: Data(#"{"start":0,"counters":{}}"#.utf8))
        XCTAssertTrue(old.mediaSentBytesByKind.isEmpty)
        XCTAssertTrue(old.mediaReceivedBytesByNetwork.isEmpty)
    }

    func testFailedPUTCountsAttemptWithoutPersistingSignedURL() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collector = MobileMetricsCollector(store: MobileMetricsStore(directory: directory))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MediaMetricsURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let service = MediaUploadService(api: UnusedMediaAPIClient(), session: session,
                                         metrics: collector)
        let ticket = MediaUploadTicket(
            uploadURL: URL(string: "https://r2.test/upload?signature=private-signature")!,
            method: "PUT", headers: ["Content-Type": "image/jpeg"], key: "private-key",
            publicURL: URL(string: "https://cdn.test/private-image.jpg")!,
            expiresIn: 300, expiresAt: Date().addingTimeInterval(300)
        )
        do {
            try await service.upload(Data([1, 2, 3]), using: ticket, kind: .image)
            XCTFail("503 PUT must fail")
        } catch MediaUploadError.uploadFailed(let status, _) {
            XCTAssertEqual(status, 503)
        }
        #if DEBUG
        let windows = await collector.snapshot()
        XCTAssertEqual(windows.last?.counters[.mediaUpload], 1)
        XCTAssertEqual(windows.last?.counters[.mediaUploadFailure], 1)
        let text = String(decoding: try JSONEncoder().encode(windows), as: UTF8.self)
        for forbidden in ["private-signature", "private-key", "private-image", "r2.test", "token"] {
            XCTAssertFalse(text.contains(forbidden))
        }
        #else
        let windows = await collector.snapshot()
        XCTAssertTrue(windows.isEmpty)
        #endif
    }
}

private final class UnusedMediaAPIClient: APIClient {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        throw APIError.unknown
    }

    func sendWithMetadata<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResult<T> {
        throw APIError.unknown
    }
}

private final class MediaMetricsURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 503,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
