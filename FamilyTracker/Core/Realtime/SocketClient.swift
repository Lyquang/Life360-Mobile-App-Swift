import Foundation

enum SocketConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
}

/// Transport-level realtime client. Knows nothing about app models; payloads are JSON dictionaries.
protocol SocketClient: AnyObject {
    var status: SocketConnectionStatus { get }
    func connect(token: String)
    func disconnect()
    func emit(_ event: String, _ payload: [String: Any])
    /// Handlers survive reconnects; register once at startup.
    func on(_ event: String, handler: @escaping ([String: Any]) -> Void)
    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void)
}
