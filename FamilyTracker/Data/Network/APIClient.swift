import Foundation

protocol AccessTokenProvider: AnyObject {
    var accessToken: String? { get }
    /// Called on 401 with the token that was sent; must not remove a newer token saved by a later login.
    func invalidate(token: String)
}

protocol APIClient {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
}

final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: AccessTokenProvider
    private let logger: NetworkLogger

    init(baseURL: URL, session: URLSession = .shared, tokenProvider: AccessTokenProvider, logger: NetworkLogger) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.logger = logger
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let (request, sentToken) = try makeRequest(for: endpoint)
        let method = endpoint.method.rawValue
        let url = request.url?.absoluteString ?? endpoint.path
        let requestId = UUID()
        let startedAt = Date()

        // Request bodies can contain passwords or Google ID tokens.
        logger.logRequest(id: requestId, method: method, url: url, body: nil)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.logHTTP(request: request, response: nil, data: nil, error: error,
                           duration: Date().timeIntervalSince(startedAt))
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            logger.logError(id: requestId, method: method, url: url, message: error.localizedDescription,
                            duration: Date().timeIntervalSince(startedAt))
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        logger.logHTTP(request: request, response: response, data: data, error: nil,
                       duration: Date().timeIntervalSince(startedAt))
        logger.logResponse(id: requestId, method: method, url: url, statusCode: http.statusCode,
                           data: endpoint.requiresAuth ? data : Data(),
                           duration: Date().timeIntervalSince(startedAt))

        let decoder = JSONDecoder()
        let envelope: APIErrorResponseDTO?
        do { envelope = try decoder.decode(APIErrorResponseDTO.self, from: data) }
        catch { envelope = nil } // A proxy may return HTML instead of the API envelope.

        if (http.statusCode == 401 || envelope?.code == "UNAUTHORIZED"), let sentToken {
            tokenProvider.invalidate(token: sentToken)
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode), envelope?.success != false else {
            throw APIError.http(status: http.statusCode, code: envelope?.code,
                                message: envelope?.message, errors: envelope?.errors ?? [])
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func makeRequest(for endpoint: Endpoint) throws -> (URLRequest, String?) {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }
        if !endpoint.query.isEmpty { components.queryItems = endpoint.query }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 30
        for (key, value) in endpoint.headers where key.lowercased() != "authorization" {
            request.setValue(value, forHTTPHeaderField: key)
        }

        var token: String?
        if endpoint.requiresAuth {
            guard let accessToken = tokenProvider.accessToken, !accessToken.isEmpty else { throw APIError.unauthorized }
            token = accessToken
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try endpoint.encodedBody()
        return (request, token)
    }
}
