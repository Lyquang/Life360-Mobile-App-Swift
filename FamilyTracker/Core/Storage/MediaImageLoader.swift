import Foundation
import UIKit

/// Platform adapter for image cache and transport; views receive decoded images only.
@MainActor
final class MediaImageLoader {
    private let session: URLSession
    private let cache: URLCache
    private let metrics: MobileMetricsRecording?

    init(session: URLSession = .shared, cache: URLCache = .shared,
         metrics: MobileMetricsRecording? = nil) {
        self.session = session
        self.cache = cache
        self.metrics = metrics
    }

    func load(_ url: URL) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        if let cached = cache.cachedResponse(for: request) {
            if let image = UIImage(data: cached.data) {
                if let metrics { await metrics.record(.increment(.mediaCacheHit)) }
                return image
            }
            cache.removeCachedResponse(for: request)
        }
        if let metrics { await metrics.record(.increment(.mediaCacheMiss)) }
        do {
            let data: Data
            let response: URLResponse
            if let metrics {
                (data, response) = try await session.data(
                    for: request, delegate: ImageDownloadMetricsDelegate(recorder: metrics))
            } else {
                (data, response) = try await session.data(for: request)
            }
            guard let image = UIImage(data: data) else { throw ImageLoadError.invalidImage }
            cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            return image
        } catch {
            if !Task.isCancelled, (error as? URLError)?.code != .cancelled,
               let metrics { await metrics.record(.increment(.mediaDownloadFailure)) }
            throw error
        }
    }
}

private enum ImageLoadError: Error {
    case invalidImage
}

private final class ImageDownloadMetricsDelegate: NSObject, URLSessionTaskDelegate {
    private let recorder: MobileMetricsRecording

    init(recorder: MobileMetricsRecording) { self.recorder = recorder }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        for transaction in metrics.transactionMetrics where transaction.resourceFetchType == .networkLoad {
            let sent = NetworkTaskMetricsDelegate.safeTotal(transaction.countOfRequestHeaderBytesSent,
                                                            transaction.countOfRequestBodyBytesSent)
            let received = NetworkTaskMetricsDelegate.safeTotal(transaction.countOfResponseHeaderBytesReceived,
                                                                transaction.countOfResponseBodyBytesReceived)
            guard sent > 0 || received > 0 else { continue }
            let network: MobileNetworkKind = transaction.isCellular ? .cellular : .other
            Task { [recorder] in
                await recorder.record(.mediaTransfer(.imageDownload, network: network,
                                                     sent: sent, received: received))
            }
        }
    }
}
