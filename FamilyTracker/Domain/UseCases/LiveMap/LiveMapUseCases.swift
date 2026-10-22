import Foundation

struct ObserveMemberLocationsUseCase {
    let repository: LiveLocationRepository
    func callAsFunction() -> AsyncStream<MemberLocation> { repository.observeMemberLocations() }
}

struct ObserveStayAlertsUseCase {
    let repository: LiveLocationRepository
    func callAsFunction() -> AsyncStream<LocationStayAlert> { repository.observeStayAlerts() }
}

struct ObservePresenceUseCase {
    let repository: LiveLocationRepository
    func callAsFunction() -> AsyncStream<MemberPresence> { repository.observePresence() }
}

struct ObserveConnectionStateUseCase {
    let repository: RealtimeSessionRepository
    var current: RealtimeConnectionState { repository.connectionState }
    func callAsFunction() -> AsyncStream<RealtimeConnectionState> { repository.observeConnectionState() }
}

struct ObserveDeviceLocationUseCase {
    let repository: DeviceLocationRepository
    func callAsFunction() -> AsyncStream<GeoPoint> { repository.observeLocations() }
}

struct GetCurrentLocationUseCase {
    let repository: DeviceLocationRepository
    func callAsFunction() -> GeoPoint? { repository.lastKnownLocation }
}

/// Streams device fixes according to the adaptive send policy while preserving the socket contract.
@MainActor
final class ShareLocationUseCase {
    typealias Sleeper = @Sendable (UInt64) async throws -> Void
    typealias NowProvider = () -> Date
    typealias ForegroundProvider = () -> Bool

    private let deviceLocation: DeviceLocationRepository
    private let liveLocation: LiveLocationRepository
    private let deviceStatus: DeviceStatusRepository
    private let diagnostics: LocationDiagnostics?
    private let sleeper: Sleeper
    private let policy: LocationSendPolicy
    private let configuration: LocationSendConfiguration
    private let now: NowProvider
    private let isForeground: ForegroundProvider
    private let canShare: @MainActor () -> Bool
    private let onSharingChanged: (Bool) -> Void
    private let onHistorySync: () -> Void
    private var readinessTask: Task<Void, Never>?
    private var refreshTimeout: Task<Void, Never>?
    private var requestedFreshAt: Date?
    private var wasReady = false

    private var streamTask: Task<Void, Never>?
    private var motionTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var pendingTask: Task<Void, Never>?
    private var pendingGeneration = 0
    private var currentMotionState: MotionState = .unknown
    private var lastSent: LocationSendPolicy.SentLocation?
    private var pending: LocationSendPolicy.PendingLocation?

    private let heartbeatInterval: TimeInterval = 30

    private(set) var isSharing = false

    init(
        deviceLocation: DeviceLocationRepository,
        liveLocation: LiveLocationRepository,
        deviceStatus: DeviceStatusRepository,
        diagnostics: LocationDiagnostics? = nil,
        sleeper: @escaping Sleeper = { try await Task.sleep(nanoseconds: $0) },
        policy: LocationSendPolicy = LocationSendPolicy(),
        configuration: LocationSendConfiguration = .baseline,
        now: @escaping NowProvider = Date.init,
        isForeground: @escaping ForegroundProvider = { true },
        canShare: @escaping @MainActor () -> Bool = { true },
        onSharingChanged: @escaping (Bool) -> Void = { _ in },
        onHistorySync: @escaping () -> Void = {}
    ) {
        self.deviceLocation = deviceLocation
        self.liveLocation = liveLocation
        self.deviceStatus = deviceStatus
        self.diagnostics = diagnostics
        self.sleeper = sleeper
        self.policy = policy
        self.configuration = configuration
        self.now = now
        self.isForeground = isForeground
        self.canShare = canShare
        self.onSharingChanged = onSharingChanged
        self.onHistorySync = onHistorySync
    }

    func start() {
        guard !isSharing, canShare() else { return }
        isSharing = true
        onSharingChanged(true)
        diagnostics?.startSession(batteryLevel: deviceStatus.batteryLevel)
        currentMotionState = deviceLocation.currentMotionState

        let stream = deviceLocation.observeFixes()
        streamTask = Task { [weak self] in
            for await fix in stream {
                guard !Task.isCancelled, let self, self.isSharing else { return }
                self.handle(fix, now: self.now())
            }
        }

        let motionStates = deviceLocation.observeMotionStates()
        motionTask = Task { [weak self] in
            for await state in motionStates {
                guard !Task.isCancelled, let self, self.isSharing else { return }
                guard state != self.currentMotionState else { continue }
                self.currentMotionState = state
                if let fix = self.deviceLocation.lastKnownFix {
                    self.handle(fix, now: self.now())
                }
            }
        }

        let interval = Self.nanoseconds(heartbeatInterval)
        heartbeatTask = Task { [weak self] in
            while true {
                guard !Task.isCancelled, let self else { return }
                do {
                    try await self.sleeper(interval)
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                if let fix = self.deviceLocation.lastKnownFix {
                    self.diagnostics?.recordHeartbeatAttempt()
                    self.handle(fix, now: self.now())
                }
            }
        }
        let readiness = liveLocation.observeSessionReadiness()
        readinessTask = Task { [weak self] in
            for await ready in readiness {
                guard !Task.isCancelled, let self, self.isSharing else { return }
                self.updateReadiness(ready)
            }
        }
        deviceLocation.requestPermission()
        deviceLocation.startTracking()
        updateReadiness(liveLocation.isSessionReady)
    }

    func stop() {
        readinessTask?.cancel()
        readinessTask = nil
        refreshTimeout?.cancel()
        refreshTimeout = nil
        requestedFreshAt = nil
        wasReady = false
        onSharingChanged(false)
        diagnostics?.stopSession(batteryLevel: deviceStatus.batteryLevel)
        streamTask?.cancel()
        motionTask?.cancel()
        heartbeatTask?.cancel()
        cancelPendingTask()
        streamTask = nil
        motionTask = nil
        heartbeatTask = nil
        lastSent = nil
        pending = nil
        currentMotionState = .unknown
        isSharing = false
        deviceLocation.stopTracking()
    }

    func handle(_ fix: LocationFix, now: Date = Date()) {
        guard canShare() else { return }
        if isSharing { updateReadiness(liveLocation.isSessionReady) }
        if let requestedFreshAt, liveLocation.isSessionReady {
            guard fix.timestamp >= requestedFreshAt else { return }
            self.requestedFreshAt = nil
            refreshTimeout?.cancel()
            refreshTimeout = nil
            cancelPendingTask()
            pending = nil
            lastSent = .init(fix: fix, sentAt: now, motionState: currentMotionState)
            liveLocation.sendLocation(fix, batteryLevel: deviceStatus.batteryLevel)
            onHistorySync()
            return
        }
        let decision = policy.decide(
            fix: fix,
            lastSent: lastSent,
            pending: pending,
            now: now,
            motionState: currentMotionState,
            config: configuration
        )
        switch decision {
        case .send(let sentFix, let reason):
            cancelPendingTask()
            pending = nil
            lastSent = .init(fix: sentFix, sentAt: now, motionState: currentMotionState)
            diagnostics?.recordPolicyDecision(outcome: .send, reason: reason.rawValue)
            liveLocation.sendLocation(sentFix, batteryLevel: deviceStatus.batteryLevel)
        case .hold(let held, let reason):
            pending = held
            diagnostics?.recordPolicyDecision(outcome: .hold, reason: reason.rawValue)
            schedulePendingIfNeeded(now: now)
        case .drop(let reason):
            diagnostics?.recordPolicyDecision(outcome: .drop, reason: reason.rawValue)
        }
    }

    private func updateReadiness(_ ready: Bool) {
        guard ready == liveLocation.isSessionReady else { return }
        guard ready != wasReady else { return }
        wasReady = ready
        refreshTimeout?.cancel()
        refreshTimeout = nil
        requestedFreshAt = nil
        guard ready, isSharing else { return }
        cancelPendingTask()
        pending = nil
        requestedFreshAt = now()
        deviceLocation.requestFreshLocation()
        refreshTimeout = Task { [weak self] in
            guard let self else { return }
            do { try await self.sleeper(Self.nanoseconds(10)) }
            catch { return }
            guard !Task.isCancelled, self.isSharing, self.liveLocation.isSessionReady else { return }
            self.onHistorySync()
        }
    }

    private func schedulePendingIfNeeded(now: Date) {
        guard isSharing, isForeground(), let pending, let lastSent else { return }
        cancelPendingTask()
        let minimum = configuration.mode(for: pending.motionState).minSendInterval
        let delay = max(0, minimum - now.timeIntervalSince(lastSent.sentAt))
        let generation = pendingGeneration
        pendingTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.sleeper(Self.nanoseconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  self.isSharing,
                  self.pendingGeneration == generation,
                  self.isForeground(),
                  let pending = self.pending else { return }
            self.pendingTask = nil
            self.handle(pending.fix, now: self.now())
        }
    }

    private func cancelPendingTask() {
        pendingGeneration += 1
        pendingTask?.cancel()
        pendingTask = nil
    }

    private static func nanoseconds(_ interval: TimeInterval) -> UInt64 {
        UInt64(max(0, interval) * 1_000_000_000)
    }
}
