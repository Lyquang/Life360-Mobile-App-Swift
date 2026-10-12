import Foundation

/// Implement this when the backend publishes the Refresh Token Rotation contract.
/// The implementation must persist the returned access token in Keychain before returning.
protocol AccessTokenRefreshing: AnyObject {
    func refreshAccessToken() async throws -> String
}

actor TokenRefreshCoordinator {
    private var inFlight: Task<String, Error>?

    func refresh(using refresher: AccessTokenRefreshing) async throws -> String {
        if let inFlight { return try await inFlight.value }
        let task = Task { try await refresher.refreshAccessToken() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}
