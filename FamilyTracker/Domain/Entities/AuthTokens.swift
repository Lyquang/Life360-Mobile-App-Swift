import Foundation

struct AuthTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let accessTokenExpiresAt: Date

    init(accessToken: String, refreshToken: String, expiresIn: Int, receivedAt: Date = Date()) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.accessTokenExpiresAt = receivedAt.addingTimeInterval(TimeInterval(expiresIn))
    }
}
