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

/// Streams the device location to the circle, following the backend contract:
/// send only when moved >= 50m or >= 30s since the last update, plus a heartbeat while stationary.
@MainActor
final class ShareLocationUseCase {
    private let deviceLocation: DeviceLocationRepository
    private let liveLocation: LiveLocationRepository
    private let deviceStatus: DeviceStatusRepository

    private let minDistance: Double
    private let minInterval: TimeInterval

    private var streamTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var lastSent: (fix: LocationFix, sentAt: Date)?

    private(set) var isSharing = false

    init(
        deviceLocation: DeviceLocationRepository,
        liveLocation: LiveLocationRepository,
        deviceStatus: DeviceStatusRepository,
        minDistance: Double = 50,
        minInterval: TimeInterval = 30
    ) {
        self.deviceLocation = deviceLocation
        self.liveLocation = liveLocation
        self.deviceStatus = deviceStatus
        self.minDistance = minDistance
        self.minInterval = minInterval
    }

    func start() {
        guard !isSharing else { return }
        isSharing = true
        deviceLocation.requestPermission()
        deviceLocation.startTracking()

        let stream = deviceLocation.observeFixes()
        streamTask = Task { [weak self] in
            for await fix in stream {
                self?.handle(fix)
            }
        }

        let interval = UInt64(minInterval * 1_000_000_000)
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                guard let self else { return }
                if let fix = self.deviceLocation.lastKnownFix {
                    self.handle(fix)
                }
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        heartbeatTask?.cancel()
        streamTask = nil
        heartbeatTask = nil
        lastSent = nil
        isSharing = false
        deviceLocation.stopTracking()
    }

    func handle(_ fix: LocationFix, now: Date = Date()) {
        if let last = lastSent,
           fix.point.distance(to: last.fix.point) < minDistance,
           now.timeIntervalSince(last.sentAt) < minInterval {
            return
        }
        lastSent = (fix, now)
        liveLocation.sendLocation(fix.point, batteryLevel: deviceStatus.batteryLevel)
    }
}
