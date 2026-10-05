import Foundation

protocol NetworkLogger {
    func logRequest(id: UUID, method: String, url: String, body: [String: Any]?)
    func logResponse(id: UUID, method: String, url: String, statusCode: Int, data: Data, duration: TimeInterval)
    func logError(id: UUID, method: String, url: String, message: String, duration: TimeInterval)
    func logSocket(event: String, payload: Any)
    func logHTTP(request: URLRequest, response: URLResponse?, data: Data?, error: Error?, duration: TimeInterval)
}

extension NetworkLogger {
    func logHTTP(request: URLRequest, response: URLResponse?, data: Data?, error: Error?, duration: TimeInterval) {}
}

struct NoopNetworkLogger: NetworkLogger {
    func logRequest(id: UUID, method: String, url: String, body: [String: Any]?) {}
    func logResponse(id: UUID, method: String, url: String, statusCode: Int, data: Data, duration: TimeInterval) {}
    func logError(id: UUID, method: String, url: String, message: String, duration: TimeInterval) {}
    func logSocket(event: String, payload: Any) {}
}

#if DEBUG
/// Forwards logs to the in-app Network Inspector.
struct DebugStoreNetworkLogger: NetworkLogger {
    func logRequest(id: UUID, method: String, url: String, body: [String: Any]?) {
        let sanitized = body.map { NetworkDebugStore.sanitizedBody($0) }
        Task { @MainActor in
            _ = NetworkDebugStore.shared.recordRequest(method: method, url: url, body: sanitized)
        }
    }

    func logResponse(id: UUID, method: String, url: String, statusCode: Int, data: Data, duration: TimeInterval) {
        let body = NetworkDebugStore.prettyJSON(
            (try? JSONSerialization.jsonObject(with: data)) ?? (String(data: data, encoding: .utf8) ?? "<empty>")
        )
        Task { @MainActor in
            NetworkDebugStore.shared.recordResponse(
                requestId: id, method: method, url: url, statusCode: statusCode, body: body, duration: duration
            )
        }
    }

    func logError(id: UUID, method: String, url: String, message: String, duration: TimeInterval) {
        Task { @MainActor in
            NetworkDebugStore.shared.recordError(requestId: id, method: method, url: url, message: message, duration: duration)
        }
    }

    func logSocket(event: String, payload: Any) {
        let pretty = NetworkDebugStore.prettyJSON(payload)
        Task { @MainActor in
            NetworkDebugStore.shared.recordSocket(event: event, payload: pretty)
        }
    }
}
#endif
