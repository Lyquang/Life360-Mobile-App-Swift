import Foundation

final class MediaUploadService {
    private let api: APIClient
    private let session: URLSession
    private let logger: NetworkLogger

    init(api: APIClient, session: URLSession = .shared, logger: NetworkLogger = NoopNetworkLogger()) {
        self.api = api
        self.session = session
        self.logger = logger
    }

    func requestTicket(conversationId: String, kind: MediaKind, fileSize: Int) async throws -> MediaUploadTicket {
        guard fileSize > 0, fileSize <= MediaUploadPolicy.maxBytes(for: kind) else {
            throw MediaUploadError.invalidMedia("Kích thước tệp không hợp lệ.")
        }
        do {
            let response = try await api.send(
                ChatEndpoint.mediaTicket(conversationId: conversationId, kind: kind, fileSize: fileSize),
                as: APIResponseDTO<PresignedMediaTicketDTO>.self
            )
            return try response.unwrap(fallbackMessage: "Không thể tạo phiên tải tệp.").toDomain()
        } catch APIError.unauthorized {
            // Refresh Token Rotation has no mobile API contract yet.
            throw MediaUploadError.refreshUnavailable
        } catch APIError.http(let status, let code, let message, _) {
            switch status {
            case 403: throw MediaUploadError.forbidden
            case 503: throw MediaUploadError.serviceUnavailable
            default: throw MediaUploadError.backend(status: status, code: code,
                                                    message: message ?? "Không thể tạo phiên tải tệp.")
            }
        } catch let error as MediaUploadError {
            throw error
        } catch {
            throw error
        }
    }

    func upload(_ data: Data, using ticket: MediaUploadTicket,
                progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        guard ticket.expiresAt > Date() else { throw MediaUploadError.ticketExpired }
        if let signedLength = header("Content-Length", in: ticket.headers).flatMap(Int.init),
           signedLength != data.count {
            throw MediaUploadError.fileSizeMismatch(expected: signedLength, actual: data.count)
        }
        #if !DEBUG
        guard ticket.uploadURL.scheme?.lowercased() == "https" else {
            throw MediaUploadError.invalidMedia("URL tải tệp không an toàn.")
        }
        #endif

        var request = URLRequest(url: ticket.uploadURL)
        request.httpMethod = ticket.method
        ticket.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue(nil, forHTTPHeaderField: "Authorization")

        let delegate = UploadProgressDelegate(progress: progress)
        let startedAt = Date()
        do {
            progress(0)
            let (responseData, response) = try await session.upload(for: request, from: data, delegate: delegate)
            logger.logHTTP(request: request, response: response, data: responseData, error: nil,
                           duration: Date().timeIntervalSince(startedAt))
            guard let http = response as? HTTPURLResponse else {
                throw MediaUploadError.uploadFailed(status: nil, retryable: true)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw MediaUploadError.uploadFailed(status: http.statusCode, retryable: true)
            }
            progress(1)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as MediaUploadError {
            throw error
        } catch {
            logger.logHTTP(request: request, response: nil, data: nil, error: error,
                           duration: Date().timeIntervalSince(startedAt))
            if (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw MediaUploadError.uploadFailed(status: nil, retryable: true)
        }
    }

    /// Safe before message persistence: each retry obtains a new signature/public URL.
    func uploadWithFreshTicket(_ data: Data, conversationId: String, kind: MediaKind,
                               progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> MediaUploadTicket {
        var lastError: Error?
        for attempt in 0..<2 {
            let ticket = try await requestTicket(conversationId: conversationId, kind: kind, fileSize: data.count)
            do {
                try await upload(data, using: ticket, progress: progress)
                return ticket
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as MediaUploadError {
                lastError = error
                guard attempt == 0, isSafeToRetry(error) else { throw error }
            }
        }
        throw lastError ?? MediaUploadError.uploadFailed(status: nil, retryable: true)
    }

    private func isSafeToRetry(_ error: MediaUploadError) -> Bool {
        switch error {
        case .ticketExpired, .uploadFailed: return true
        default: return false
        }
    }

    private func header(_ name: String, in headers: [String: String]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let progress: @Sendable (Double) -> Void

    init(progress: @escaping @Sendable (Double) -> Void) {
        self.progress = progress
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        progress(min(1, max(0, Double(totalBytesSent) / Double(totalBytesExpectedToSend))))
    }
}
