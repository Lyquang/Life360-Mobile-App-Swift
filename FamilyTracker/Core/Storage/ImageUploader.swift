import Foundation

struct UploadTarget {
    let url: URL
    let method: String
    let headers: [String: String]
}

enum ImageUploadError: LocalizedError {
    case insecureURL
    case failed(statusCode: Int?)

    var errorDescription: String? {
        switch self {
        case .insecureURL: return "URL tải ảnh không an toàn."
        case .failed(let code): return "Tải ảnh thất bại (\(code.map(String.init) ?? "network"))."
        }
    }
}

/// Uploads raw bytes to a presigned object-storage URL.
final class ImageUploader {
    private let session: URLSession
    private let logger: NetworkLogger

    init(session: URLSession = .shared, logger: NetworkLogger = NoopNetworkLogger()) {
        self.session = session
        self.logger = logger
    }

    func upload(_ data: Data, to target: UploadTarget) async throws {
        #if !DEBUG
        guard target.url.scheme == "https" else { throw ImageUploadError.insecureURL }
        #endif

        var request = URLRequest(url: target.url)
        request.httpMethod = target.method
        // Presigned URLs are signed against these exact headers.
        target.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let startedAt = Date()
        let response: URLResponse
        do {
            let (responseData, receivedResponse) = try await session.upload(for: request, from: data)
            response = receivedResponse
            logger.logHTTP(request: request, response: response, data: responseData, error: nil,
                           duration: Date().timeIntervalSince(startedAt))
        } catch {
            logger.logHTTP(request: request, response: nil, data: nil, error: error,
                           duration: Date().timeIntervalSince(startedAt))
            throw error
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard let statusCode, (200..<300).contains(statusCode) else {
            throw ImageUploadError.failed(statusCode: statusCode)
        }
    }
}
