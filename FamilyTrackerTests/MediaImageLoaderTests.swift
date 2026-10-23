import Foundation
import UIKit
import XCTest
@testable import FamilyTracker

final class MediaImageLoaderTests: XCTestCase {
    @MainActor
    func testCacheHitMissCorruptEntryAndPrivacy() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collector = MobileMetricsCollector(store: MobileMetricsStore(directory: directory))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let png = try XCTUnwrap(renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }.pngData())
        MediaImageURLProtocol.configure(data: png)
        let cache = URLCache(memoryCapacity: 1_024_000, diskCapacity: 0, diskPath: nil)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MediaImageURLProtocol.self]
        config.urlCache = cache
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let loader = MediaImageLoader(session: session, cache: cache, metrics: collector)
        let url = URL(string: "https://cdn.test/private-member/image.jpg?signature=secret")!

        _ = try await loader.load(url)
        _ = try await loader.load(url)
        XCTAssertEqual(MediaImageURLProtocol.requestCount, 1)

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        cache.storeCachedResponse(CachedURLResponse(response: response, data: Data("broken".utf8)), for: request)
        _ = try await loader.load(url)
        XCTAssertEqual(MediaImageURLProtocol.requestCount, 2)

        #if DEBUG
        let windows = await collector.snapshot()
        XCTAssertEqual(windows.last?.counters[.mediaCacheHit], 1)
        XCTAssertEqual(windows.last?.counters[.mediaCacheMiss], 2)
        let text = String(decoding: try JSONEncoder().encode(windows), as: UTF8.self)
        for forbidden in ["private-member", "signature", "secret", "cdn.test", "latitude"] {
            XCTAssertFalse(text.contains(forbidden))
        }
        #else
        let windows = await collector.snapshot()
        XCTAssertTrue(windows.isEmpty)
        #endif
    }

    @MainActor
    func testInvalidDownloadedImageCountsFailureWithoutCaching() async throws {
        MediaImageURLProtocol.configure(data: Data("not an image".utf8))
        let cache = URLCache(memoryCapacity: 1_024_000, diskCapacity: 0, diskPath: nil)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MediaImageURLProtocol.self]
        config.urlCache = cache
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let collector = MobileMetricsCollector(store: MobileMetricsStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        let loader = MediaImageLoader(session: session, cache: cache, metrics: collector)
        let url = URL(string: "https://cdn.test/invalid-image.jpg")!
        do {
            _ = try await loader.load(url)
            XCTFail("Invalid image must fail")
        } catch { }
        #if DEBUG
        let windows = await collector.snapshot()
        XCTAssertEqual(windows.last?.counters[.mediaDownloadFailure], 1)
        #endif
        XCTAssertNil(cache.cachedResponse(for: URLRequest(url: url)))
    }
}

private final class MediaImageURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var body = Data()
    private static var count = 0

    static func configure(data: Data) {
        lock.lock()
        body = data
        count = 0
        lock.unlock()
    }

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        let data = Self.body
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "image/png"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
