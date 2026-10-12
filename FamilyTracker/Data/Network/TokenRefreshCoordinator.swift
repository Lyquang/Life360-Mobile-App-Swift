import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum RefreshFailure: Error {
    case invalidSession
    case rateLimited(until: Date)
    case network
    case ambiguousNetwork
    case server
    case storage
    case cancelled
}

protocol RefreshTokenTransport: AnyObject {
    func rotate(refreshToken: String) async throws -> AuthTokens
}

protocol TokenPairStore: AccessTokenProvider {
    var tokens: AuthTokens? { get }
    func replaceTokens(_ tokens: AuthTokens) throws
    func replaceTokens(_ tokens: AuthTokens, ifGeneration expected: Int) throws
    func clear()
}

/// Only this actor may rotate the current refresh token.
actor TokenRefreshCoordinator {
    private let store: TokenPairStore
    private let transport: RefreshTokenTransport
    private let onRotated: @Sendable (String) async -> Void
    private let onExpired: @Sendable (Int) async -> Void
    private var inFlight: Task<String, Error>?
    private var inFlightID: UUID?
    private var generation = 0
    private var cooldownUntil: Date?

    init(store: TokenPairStore, transport: RefreshTokenTransport,
         onRotated: @escaping @Sendable (String) async -> Void = { _ in },
         onExpired: @escaping @Sendable (Int) async -> Void = { _ in }) {
        self.store = store
        self.transport = transport
        self.onRotated = onRotated
        self.onExpired = onExpired
    }

    func validAccessToken(afterUnauthorized sentToken: String, sentGeneration: Int? = nil) async throws -> String {
        let expectedGeneration = sentGeneration ?? store.sessionGeneration
        guard store.sessionGeneration == expectedGeneration else {
            throw RefreshFailure.cancelled
        }
        if let current = store.accessToken, current != sentToken {
            guard store.sessionGeneration == expectedGeneration else { throw RefreshFailure.cancelled }
            return current
        }
        guard let current = store.tokens, current.accessToken == sentToken else {
            await onExpired(expectedGeneration)
            throw RefreshFailure.invalidSession
        }
        if let cooldownUntil, cooldownUntil > Date() {
            throw RefreshFailure.rateLimited(until: cooldownUntil)
        }

        let flight: Task<String, Error>
        if let inFlight { flight = inFlight }
        else {
            let refreshToken = current.refreshToken
            let startedGeneration = generation
            let storeGeneration = store.sessionGeneration
            flight = Task { [self] in
                try await performRotation(refreshToken: refreshToken, sentToken: sentToken,
                                          startedGeneration: startedGeneration, storeGeneration: storeGeneration)
            }
            inFlight = flight
            inFlightID = UUID()
        }
        let flightID = inFlightID
        do {
            let token = try await flight.value
            if inFlightID == flightID { inFlight = nil; inFlightID = nil }
            return token
        } catch {
            if inFlightID == flightID { inFlight = nil; inFlightID = nil }
            throw error
        }
    }

    private func performRotation(refreshToken: String, sentToken: String,
                                 startedGeneration: Int, storeGeneration: Int) async throws -> String {
        let backgroundTask = await Self.beginBackgroundTask()
        do {
            let newTokens = try await transport.rotate(refreshToken: refreshToken)
            guard startedGeneration == generation, store.sessionGeneration == storeGeneration else {
                throw RefreshFailure.cancelled
            }
            if let updated = store.accessToken, updated != sentToken {
                await Self.endBackgroundTask(backgroundTask)
                return updated
            }
            do { try store.replaceTokens(newTokens, ifGeneration: storeGeneration) }
            catch RefreshFailure.cancelled { throw RefreshFailure.cancelled }
            catch {
                await onExpired(storeGeneration)
                throw RefreshFailure.storage
            }
            await onRotated(newTokens.accessToken)
            await Self.endBackgroundTask(backgroundTask)
            return newTokens.accessToken
        } catch {
            if case RefreshFailure.rateLimited(let until) = error { cooldownUntil = until }
            if case RefreshFailure.invalidSession = error,
               startedGeneration == generation, store.sessionGeneration == storeGeneration {
                await onExpired(storeGeneration)
            }
            await Self.endBackgroundTask(backgroundTask)
            throw error
        }
    }

    func cancelSession() {
        generation += 1
        inFlight?.cancel()
        inFlight = nil
        inFlightID = nil
        cooldownUntil = nil
    }

    func expireCurrentSession(after token: String, sentGeneration: Int) async {
        guard store.accessToken == token, store.sessionGeneration == sentGeneration else { return }
        await onExpired(sentGeneration)
    }

    private static func beginBackgroundTask() async -> Int {
        #if canImport(UIKit)
        return await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "Token rotation", expirationHandler: nil).rawValue
        }
        #else
        return -1
        #endif
    }

    private static func endBackgroundTask(_ identifier: Int) async {
        #if canImport(UIKit)
        await MainActor.run {
            guard identifier != UIBackgroundTaskIdentifier.invalid.rawValue else { return }
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: identifier))
        }
        #endif
    }
}

final class URLSessionRefreshTransport: RefreshTokenTransport {
    private let baseURL: URL
    private let session: URLSession
    private let logger: NetworkLogger

    init(baseURL: URL, session: URLSession = .shared, logger: NetworkLogger) {
        self.baseURL = baseURL
        self.session = session
        self.logger = logger
    }

    func rotate(refreshToken: String) async throws -> AuthTokens {
        let endpoint = AuthEndpoint.refresh(refreshToken: refreshToken)
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try endpoint.encodedBody()
        let started = Date()
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError {
            logger.logHTTP(request: request, response: nil, data: nil, error: error,
                           duration: Date().timeIntervalSince(started))
            switch error.code {
            case .cancelled: throw RefreshFailure.cancelled
            case .notConnectedToInternet, .dataNotAllowed, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost:
                throw RefreshFailure.network
            case .timedOut, .networkConnectionLost: throw RefreshFailure.ambiguousNetwork
            default: throw RefreshFailure.network
            }
        }
        logger.logHTTP(request: request, response: response, data: data, error: nil,
                       duration: Date().timeIntervalSince(started))
        guard let http = response as? HTTPURLResponse else { throw RefreshFailure.server }
        let decoder = BackendJSONCoding.makeDecoder()
        if http.statusCode == 429 {
            let seconds = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                ?? (60 + Double.random(in: 0...5))
            throw RefreshFailure.rateLimited(until: Date().addingTimeInterval(max(0, seconds)))
        }
        if http.statusCode == 401 {
            let body = try? decoder.decode(APIErrorResponseDTO.self, from: data)
            if body?.code == "INVALID_REFRESH_TOKEN" || body?.code == "REFRESH_TOKEN_REUSED" {
                throw RefreshFailure.invalidSession
            }
            throw RefreshFailure.server
        }
        guard (200..<300).contains(http.statusCode) else { throw RefreshFailure.server }
        let payload: RefreshDataDTO
        do {
            payload = try decoder.decode(APIResponseDTO<RefreshDataDTO>.self, from: data)
                .unwrap(fallbackMessage: "Không thể làm mới phiên đăng nhập.")
        } catch { throw RefreshFailure.server }
        guard !payload.accessToken.isEmpty, !payload.refreshToken.isEmpty, payload.expiresIn > 0 else {
            throw RefreshFailure.server
        }
        return AuthTokens(accessToken: payload.accessToken, refreshToken: payload.refreshToken,
                          expiresIn: payload.expiresIn)
    }
}
