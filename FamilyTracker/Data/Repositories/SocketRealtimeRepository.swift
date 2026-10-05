import Foundation

/// Bridges the Socket.IO transport to domain streams. Emits made while offline go to `OfflineQueue`.
final class SocketRealtimeRepository: RealtimeSessionRepository, LiveLocationRepository, SOSRepository {
    private let socket: SocketClient
    private let offlineQueue: OfflineQueue

    private let connection = AsyncBroadcaster<RealtimeConnectionState>()
    private let locations = AsyncBroadcaster<MemberLocation>()
    private let stayAlerts = AsyncBroadcaster<LocationStayAlert>()
    private let presence = AsyncBroadcaster<MemberPresence>()
    private let sosAlerts = AsyncBroadcaster<SOSAlert>()

    init(socket: SocketClient, offlineQueue: OfflineQueue) {
        self.socket = socket
        self.offlineQueue = offlineQueue
        registerHandlers()
    }

    // MARK: - RealtimeSessionRepository

    var connectionState: RealtimeConnectionState { Self.map(socket.status) }

    func connect(token: String) { socket.connect(token: token) }
    func disconnect() { socket.disconnect() }
    func observeConnectionState() -> AsyncStream<RealtimeConnectionState> { connection.stream() }

    // MARK: - LiveLocationRepository

    func observeMemberLocations() -> AsyncStream<MemberLocation> { locations.stream() }
    func observeStayAlerts() -> AsyncStream<LocationStayAlert> { stayAlerts.stream() }
    func observePresence() -> AsyncStream<MemberPresence> { presence.stream() }

    func sendLocation(_ point: GeoPoint, batteryLevel: Int?) {
        var payload: [String: Any] = ["latitude": point.latitude, "longitude": point.longitude]
        if let batteryLevel { payload["batteryLevel"] = batteryLevel }
        emitOrQueue(SocketEvent.updateLocation, payload, coalesceKey: "location")
    }

    // MARK: - SOSRepository

    func observeSOSAlerts() -> AsyncStream<SOSAlert> { sosAlerts.stream() }

    func sendSOS(message: String, location: GeoPoint?, batteryLevel: Int?) {
        var payload: [String: Any] = ["message": message]
        if let location {
            payload["latitude"] = location.latitude
            payload["longitude"] = location.longitude
        }
        if let batteryLevel { payload["batteryLevel"] = batteryLevel }
        emitOrQueue(SocketEvent.sosAlert, payload, coalesceKey: nil)
    }

    // MARK: - Private

    private func emitOrQueue(_ event: String, _ payload: [String: Any], coalesceKey: String?) {
        if socket.status == .connected {
            socket.emit(event, payload)
        } else {
            offlineQueue.enqueue(event: event, payload: payload, coalesceKey: coalesceKey)
        }
    }

    private func flushOfflineQueue() {
        for item in offlineQueue.drain() {
            socket.emit(item.event, item.payload)
        }
    }

    private func registerHandlers() {
        socket.onStatusChange { [weak self] status in
            guard let self else { return }
            self.connection.send(Self.map(status))
            if status == .connected { self.flushOfflineQueue() }
        }

        socket.on(SocketEvent.sessionReady) { [weak self] _ in
            self?.flushOfflineQueue()
        }

        socket.on(SocketEvent.locationUpdate) { [weak self] payload in
            guard let dto = JSONPayload.decode(LocationUpdateDTO.self, from: payload) else { return }
            self?.locations.send(dto.toDomain())
        }

        socket.on(SocketEvent.locationStayAlert) { [weak self] payload in
            guard let dto = JSONPayload.decode(StayAlertDTO.self, from: payload) else { return }
            self?.stayAlerts.send(dto.toDomain())
        }

        socket.on(SocketEvent.sosAlertReceive) { [weak self] payload in
            guard let dto = JSONPayload.decode(SOSAlertDTO.self, from: payload) else { return }
            self?.sosAlerts.send(dto.toDomain())
        }

        socket.on(SocketEvent.memberOnline) { [weak self] payload in
            guard let dto = JSONPayload.decode(PresenceDTO.self, from: payload) else { return }
            self?.presence.send(MemberPresence(userId: dto.userId, isOnline: true))
        }

        socket.on(SocketEvent.memberOffline) { [weak self] payload in
            guard let dto = JSONPayload.decode(PresenceDTO.self, from: payload) else { return }
            self?.presence.send(MemberPresence(userId: dto.userId, isOnline: false))
        }
    }

    private static func map(_ status: SocketConnectionStatus) -> RealtimeConnectionState {
        switch status {
        case .disconnected: return .disconnected
        case .connecting: return .connecting
        case .connected: return .connected
        }
    }
}
