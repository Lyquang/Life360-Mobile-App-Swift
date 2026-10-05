import Foundation

struct AppEnvironment {
    let name: String
    let apiBaseURL: URL
    /// Socket.IO gateway (root host, not the /api path).
    let socketURL: URL

    static let production = AppEnvironment(
        name: "Production",
        apiBaseURL: URL(string: "https://life360-backend-latest.onrender.com/api/v1")!,
        socketURL: URL(string: "https://life360-backend-latest.onrender.com")!
    )

    static var current: AppEnvironment {
        return .production
    }
}
