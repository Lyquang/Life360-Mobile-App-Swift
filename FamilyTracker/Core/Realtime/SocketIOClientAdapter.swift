import Foundation
#if canImport(SocketIO)
import SocketIO
#endif

/// Socket.IO implementation of `SocketClient`.
/// Without the SocketIO package (SPM: socket.io-client-swift) it runs as an offline stub so the app still builds.
final class SocketIOClientAdapter: SocketClient {
    private let url: URL
    private let logger: NetworkLogger
    private let tokenProvider: AccessTokenProvider
    var onAuthenticationFailure: ((String) -> Void)?
    private var reconnectAllowed = false
    private var lastAuthFailureToken: String?

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

    init(url: URL, logger: NetworkLogger, tokenProvider: AccessTokenProvider) {
        self.url = url
        self.logger = logger
        self.tokenProvider = tokenProvider
    }

    func on(_ event: String, handler: @escaping ([String: Any]) -> Void) {
        handlers[event, default: []].append(handler)
    }

    func onStatusChange(_ handler: @escaping (SocketConnectionStatus) -> Void) {
        statusHandlers.append(handler)
    }

    func connect(token: String) {
        disconnect()
        guard let currentToken = tokenProvider.accessToken, !currentToken.isEmpty else { return }
        reconnectAllowed = true
        status = .connecting

        #if canImport(SocketIO)
        let manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(false)
        ])
        let socket = manager.defaultSocket

        socket.on(clientEvent: .connect) { [weak self] _, _ in self?.status = .connected }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.status = .disconnected
            self?.scheduleReconnect()
        }
        socket.on(clientEvent: .error) { [weak self] data, _ in
            self?.logger.logSocket(event: "client_error", payload: data.first ?? "unknown")
            self?.status = .disconnected
            let description = String(describing: data.first ?? "").lowercased()
            if description.contains("unauthorized") || description.contains("expired") {
                self?.handleAuthenticationFailure(for: currentToken)
            } else {
                self?.scheduleReconnect()
            }
        }
        socket.onAny { [weak self] event in
            guard let payload = event.items?.first as? [String: Any] else { return }
            self?.dispatch(event.event, payload)
        }

        self.manager = manager
        self.socket = socket
        socket.connect(withPayload: ["token": currentToken])
        #else
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard self?.status == .connecting else { return }
            self?.status = .connected
        }
        #endif
    }

    func disconnect() {
        reconnectAllowed = false
        #if canImport(SocketIO)
        socket?.removeAllHandlers()
        socket?.disconnect()
        manager?.disconnect()
        socket = nil
        manager = nil
        #endif
        status = .disconnected
    }

    private func handleAuthenticationFailure(for token: String) {
        guard lastAuthFailureToken != token else { return }
        lastAuthFailureToken = token
        reconnectAllowed = false
        onAuthenticationFailure?(token)
    }

    private func scheduleReconnect() {
        guard reconnectAllowed else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.reconnectAllowed, self.status == .disconnected,
                  let token = self.tokenProvider.accessToken else { return }
            self.connect(token: token)
        }
    }

    func emit(_ event: String, _ payload: [String: Any]) {
        logger.logSocket(event: "→ \(event)", payload: payload)
        #if canImport(SocketIO)
        socket?.emit(event, payload)
        #endif
    }

    func emitWithAck(_ event: String, _ payload: [String: Any], timeout: TimeInterval) async throws -> [String: Any] {
        guard status == .connected else { throw SocketClientError.disconnected }
        logger.logSocket(event: "→ \(event)", payload: payload)
        #if canImport(SocketIO)
        guard let socket else { throw SocketClientError.disconnected }
        return try await withCheckedThrowingContinuation { continuation in
            socket.emitWithAck(event, payload).timingOut(after: timeout) { [weak self] data in
                if data.first as? String == SocketAckStatus.noAck.rawValue {
                    continuation.resume(throwing: SocketClientError.acknowledgementTimeout)
                    return
                }
                guard let payload = data.first as? [String: Any] else {
                    continuation.resume(throwing: SocketClientError.invalidAcknowledgement)
                    return
                }
                self?.logger.logSocket(event: "← \(event):ack", payload: payload)
                continuation.resume(returning: payload)
            }
        }
        #else
        throw SocketClientError.disconnected
        #endif
    }

    private func dispatch(_ event: String, _ payload: [String: Any]) {
        logger.logSocket(event: event, payload: payload)
        handlers[event]?.forEach { $0(payload) }
    }
}
