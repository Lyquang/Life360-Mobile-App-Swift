import Foundation

/// Location delivery is owner-scoped; the generic offline queue retains SOS events.
final class SocketRealtimeRepository: RealtimeSessionRepository, LiveLocationRepository, SOSRepository {
    private let socket: SocketClient
    private let offlineQueue: OfflineQueue
    private let diagnostics: LocationDiagnostics?
    private let readinessLock = NSLock()
    private var sessionReady = false
    private var readyID: UUID?
    private let readiness = AsyncBroadcaster<Bool>()
    var deliverLocation: (@MainActor (LocationFix, Int?) -> Void)?
    var onExplicitDisconnect: (@MainActor () -> Void)?

    private let connection = AsyncBroadcaster<RealtimeConnectionState>()
    private let locations = AsyncBroadcaster<MemberLocation>()
    private let stayAlerts = AsyncBroadcaster<LocationStayAlert>()
    private let presence = AsyncBroadcaster<MemberPresence>()
    private let sosAlerts = AsyncBroadcaster<SOSAlert>()
    private let trailEvents = AsyncBroadcaster<LiveTrailEvent>()
    private let outgoingFixes = AsyncBroadcaster<LocationFix>()

    init(socket: SocketClient, offlineQueue: OfflineQueue, diagnostics: LocationDiagnostics? = nil) {
        self.socket = socket
        self.offlineQueue = offlineQueue
        self.diagnostics = diagnostics
        registerHandlers()
    }

    // MARK: - RealtimeSessionRepository

    var connectionState: RealtimeConnectionState { Self.map(socket.status) }

    var isSessionReady: Bool {
        readinessLock.lock(); defer { readinessLock.unlock() }
        return sessionReady
    }

    var readySessionID: UUID? {
        readinessLock.lock(); defer { readinessLock.unlock() }
        return readyID
    }

    func observeSessionReadiness() -> AsyncStream<Bool> { readiness.stream() }
    func observeTrailEvents() -> AsyncStream<LiveTrailEvent> { trailEvents.stream() }
    func observeOutgoingFixes() -> AsyncStream<LocationFix> { outgoingFixes.stream() }

    func watchTrail(userId: String, date: String) async throws -> Int {
        guard isSessionReady else { throw SocketClientError.disconnected }
        let ack = try await socket.emitWithAck(SocketEvent.journeyWatch,
                                                ["userId": userId, "date": date], timeout: 10)
        guard ack["ok"] as? Bool == true else {
            if ack["status"] as? Int == 403 { throw DomainError.forbidden }
            throw DomainError.server("Live trail watch failed")
        }
        return ack["revision"] as? Int ?? 0
    }

    func unwatchTrail(userId: String, date: String) {
        guard isSessionReady else { return }
        socket.emit(SocketEvent.journeyUnwatch, ["userId": userId, "date": date])
    }

    func connect(token: String) { setSessionReady(false); socket.connect(token: token) }
    @MainActor func disconnect() {
        setSessionReady(false)
        onExplicitDisconnect?()
        socket.disconnect()
        offlineQueue.clear()
    }
    func observeConnectionState() -> AsyncStream<RealtimeConnectionState> { connection.stream() }

    // MARK: - LiveLocationRepository

    func observeMemberLocations() -> AsyncStream<MemberLocation> { locations.stream() }
    func observeStayAlerts() -> AsyncStream<LocationStayAlert> { stayAlerts.stream() }
    func observePresence() -> AsyncStream<MemberPresence> { presence.stream() }

    @MainActor func sendLocation(_ fix: LocationFix, batteryLevel: Int?) {
        outgoingFixes.send(fix)
        if let deliverLocation { deliverLocation(fix, batteryLevel) }
        else { _ = emitLocationIfReady(fix, batteryLevel: batteryLevel) }
    }

    @MainActor func emitLocationIfReady(_ fix: LocationFix, batteryLevel: Int?) -> Bool {
        guard isSessionReady, socket.status == .connected else { return false }
        socket.emit(SocketEvent.updateLocation,
                    LocationSocketPayload.make(fix: fix, batteryLevel: batteryLevel))
        diagnostics?.recordEmit()
        return true
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
            if event == SocketEvent.updateLocation { diagnostics?.recordEmit() }
        } else {
            offlineQueue.enqueue(event: event, payload: payload, coalesceKey: coalesceKey)
            if event == SocketEvent.updateLocation { diagnostics?.recordOfflineEnqueue() }
        }
    }

    private func flushOfflineQueue() {
        for item in offlineQueue.drain() {
            // Older app versions persisted a coalesced fix without its GPS timestamp.
            guard item.event != SocketEvent.updateLocation else { continue }
            socket.emit(item.event, item.payload)
            if item.event == SocketEvent.updateLocation { diagnostics?.recordEmit() }
        }
    }

    private func registerHandlers() {
        socket.onStatusChange { [weak self] status in
            guard let self else { return }
            if status != .connected { self.setSessionReady(false) }
            self.connection.send(Self.map(status))
            if status == .connected { self.flushOfflineQueue() }
        }

        socket.on(SocketEvent.sessionReady) { [weak self] _ in
            guard let self, self.socket.status == .connected else { return }
            self.setSessionReady(true)
            self.flushOfflineQueue()
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

        socket.on(SocketEvent.journeyTrailDelta) { [weak self] payload in
            guard let dto = JSONPayload.decode(LiveTrailDeltaDTO.self, from: payload) else { return }
            self?.trailEvents.send(.delta(dto.toDomain()))
        }
        socket.on(SocketEvent.journeyTrailReset) { [weak self] payload in
            guard let dto = JSONPayload.decode(LiveTrailSignalDTO.self, from: payload),
                  let revision = dto.revision else { return }
            self?.trailEvents.send(.reset(userId: dto.userId, revision: revision))
        }
        socket.on(SocketEvent.journeyTrailClosed) { [weak self] payload in
            guard let dto = JSONPayload.decode(LiveTrailSignalDTO.self, from: payload) else { return }
            self?.trailEvents.send(.closed(userId: dto.userId))
        }
    }

    private func setSessionReady(_ ready: Bool) {
        readinessLock.lock()
        let changed = sessionReady != ready
        sessionReady = ready
        if changed { readyID = ready ? UUID() : nil }
        readinessLock.unlock()
        if changed { readiness.send(ready) }
    }

    private static func map(_ status: SocketConnectionStatus) -> RealtimeConnectionState {
        switch status {
        case .disconnected: return .disconnected
        case .connecting: return .connecting
        case .connected: return .connected
        }
    }
}
