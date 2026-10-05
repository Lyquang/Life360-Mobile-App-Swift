import Foundation
#if canImport(SocketIO)
import SocketIO
#endif

/// Socket.IO implementation of `SocketClient`.
/// Without the SocketIO package (SPM: socket.io-client-swift) it runs as an offline stub so the app still builds.
final class SocketIOClientAdapter: SocketClient {
    private let url: URL
    private let logger: NetworkLogger

    private var handlers: [String: [([String: Any]) -> Void]] = [:]
    private var statusHandlers: [(SocketConnectionStatus) -> Void] = []

    private(set) var status: SocketConnectionStatus = .disconnected {
        didSet {
            guard oldValue != status else { return }
            statusHandlers.forEach { $0(status) }
        }
    }

    #if canImport(SocketIO)
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    #endif

    init(url: URL, logger: NetworkLogger) {
        self.url = url
        self.logger = logger
    }

    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) {
        handlers[event, default: []].append(handler)
    }

    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) {
        statusHandlers.append(handler)
    }

    func connect(token: String) {
        disconnect()
        status = .connecting

        #if canImport(SocketIO)
        let manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectWait(3),
            .extraHeaders(["Authorization": "Bearer \(token)"]),
            .connectParams(["token": token])
        ])
        let socket = manager.defaultSocket

        socket.on(clientEvent: .connect) { [weak self] _, _ in self?.status = .connected }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in self?.status = .disconnected }
        socket.on(clientEvent: .reconnectAttempt) { [weak self] _, _ in self?.status = .connecting }
        socket.on(clientEvent: .error) { [weak self] data, _ in
            self?.logger.logSocket(event: "client_error", payload: data.first ?? "unknown")
        }
        socket.onAny { [weak self] event in
            guard let payload = event.items?.first as? [String: Any] else { return }
            self?.dispatch(event.event, payload)
        }

        self.manager = manager
        self.socket = socket
        socket.connect(withPayload: ["token": token])
        #else
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard self?.status == .connecting else { return }
            self?.status = .connected
        }
        #endif
    }

    func disconnect() {
        #if canImport(SocketIO)
        socket?.removeAllHandlers()
        socket?.disconnect()
        manager?.disconnect()
        socket = nil
        manager = nil
        #endif
        status = .disconnected
    }

    func emit(_ event: String, _ payload: [String: Any]) {
        logger.logSocket(event: "→ \(event)", payload: payload)
        #if canImport(SocketIO)
        socket?.emit(event, payload)
        #endif
    }

    private func dispatch(_ event: String, _ payload: [String: Any]) {
        logger.logSocket(event: event, payload: payload)
        handlers[event]?.forEach { $0(payload) }
    }
}
