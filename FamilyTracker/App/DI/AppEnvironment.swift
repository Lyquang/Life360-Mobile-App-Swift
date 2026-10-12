import Foundation

struct AppEnvironment {
    let name: String
    let apiBaseURL: URL
    /// Socket.IO gateway (root host, not the /api path).
    let socketURL: URL

    static let production = AppEnvironment(
        name: "Production",
        apiBaseURL: URL(string: "https://life360-backend-6v9n.onrender.com/api/v1")!,
        socketURL: URL(string: "https://life360-backend-6v9n.onrender.com")!
    )

    static func local(host: String = "localhost") -> AppEnvironment {
        AppEnvironment(
            name: "Local",
            apiBaseURL: URL(string: "http://\(host):3000/api/v1")!,
            socketURL: URL(string: "http://\(host):3000")!
        )
    }

    static var current: AppEnvironment {
        let process = ProcessInfo.processInfo.environment
        guard process["FAMILYTRACKER_USE_LOCAL_BACKEND"] == "1" else { return .production }
        return .local(host: process["FAMILYTRACKER_LOCAL_HOST"] ?? "localhost")
    }
}
