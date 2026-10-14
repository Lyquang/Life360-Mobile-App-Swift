import Foundation

protocol AccessTokenProvider: AnyObject {
    var accessToken: String? { get }
    var sessionGeneration: Int { get }
    var tokenSnapshot: (token: String?, generation: Int) { get }
    /// Called on 401 with the token that was sent; must not remove a newer token saved by a later login.
    func invalidate(token: String)
}

extension AccessTokenProvider {
    var sessionGeneration: Int { 0 }
    var tokenSnapshot: (token: String?, generation: Int) { (accessToken, sessionGeneration) }
}

protocol APIClient {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func sendWithMetadata<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResult<T>
}

struct APIResult<T> {
    let value: T
    let statusCode: Int
}

final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: AccessTokenProvider
    private let logger: NetworkLogger
    private let refreshCoordinator: TokenRefreshCoordinator?

    init(baseURL: URL, session: URLSession = .shared, tokenProvider: AccessTokenProvider,
         logger: NetworkLogger, refreshCoordinator: TokenRefreshCoordinator? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.logger = logger
        self.refreshCoordinator = refreshCoordinator
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        try await perform(endpoint, as: type, mayRefresh: true, expectedGeneration: nil,
                          exposeRateLimit: false).value
    }

    func sendWithMetadata<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> APIResult<T> {
        try await perform(endpoint, as: type, mayRefresh: true, expectedGeneration: nil,
                          exposeRateLimit: true)
    }

    private func perform<T: Decodable>(_ endpoint: Endpoint, as type: T.Type,
                                       mayRefresh: Bool, expectedGeneration: Int?,
                                       exposeRateLimit: Bool) async throws -> APIResult<T> {
        let (request, sentToken, sentGeneration) = try makeRequest(for: endpoint)
        if let expectedGeneration, sentGeneration != expectedGeneration { throw CancellationError() }
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

        let decoder = BackendJSONCoding.makeDecoder()
        let envelope: APIErrorResponseDTO?
        do { envelope = try decoder.decode(APIErrorResponseDTO.self, from: data) }
        catch { envelope = nil } // A proxy may return HTML instead of the API envelope.

        if http.statusCode == 401 || envelope?.code == "UNAUTHORIZED", let sentToken {
            let isLogout = endpoint.path == "/auth/logout" || endpoint.path == "/auth/logout-all"
            if isLogout { throw APIError.unauthorized }
            if mayRefresh, let refreshCoordinator {
                do {
                    _ = try await refreshCoordinator.validAccessToken(afterUnauthorized: sentToken,
                                                                      sentGeneration: sentGeneration)
                    return try await perform(endpoint, as: type, mayRefresh: false,
                                             expectedGeneration: sentGeneration,
                                             exposeRateLimit: exposeRateLimit)
                } catch let failure as RefreshFailure {
                    switch failure {
                    case .invalidSession, .storage: throw APIError.unauthorized
                    case .rateLimited:
                        if exposeRateLimit { throw APIError.rateLimited(retryAfter: nil) }
                        throw APIError.http(status: 429, code: "RATE_LIMITED", message: nil, errors: [])
                    case .network, .ambiguousNetwork: throw APIError.networkError("Không có kết nối mạng. Hãy thử lại.")
                    case .server: throw APIError.serverError("Không thể làm mới phiên đăng nhập. Hãy thử lại.")
                    case .cancelled: throw CancellationError()
                    }
                }
            }
            if !mayRefresh {
                await refreshCoordinator?.expireCurrentSession(after: sentToken,
                                                               sentGeneration: sentGeneration)
            }
            else { tokenProvider.invalidate(token: sentToken) }
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode), envelope?.success != false else {
            if exposeRateLimit, http.statusCode == 429 {
                throw APIError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
            }
            throw APIError.http(status: http.statusCode, code: envelope?.code,
                                message: envelope?.message, errors: envelope?.errors ?? [])
        }

        do {
            return APIResult(value: try decoder.decode(T.self, from: data), statusCode: http.statusCode)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func makeRequest(for endpoint: Endpoint) throws -> (URLRequest, String?, Int) {
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

        let snapshot = tokenProvider.tokenSnapshot
        var token: String?
        if endpoint.requiresAuth {
            guard let accessToken = snapshot.token, !accessToken.isEmpty else { throw APIError.unauthorized }
            token = accessToken
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try endpoint.encodedBody()
        return (request, token, snapshot.generation)
    }
}
