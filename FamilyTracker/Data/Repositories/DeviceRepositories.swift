import CoreLocation

/// Adapts Core/Location (CLLocation) to framework-independent Domain values.
final class DeviceLocationRepositoryImpl: DeviceLocationRepository {
    private let service: LocationService
    private let broadcaster = AsyncBroadcaster<GeoPoint>()
    private let fixBroadcaster = AsyncBroadcaster<LocationFix>()
    private let motionBroadcaster = AsyncBroadcaster<MotionState>()

    init(service: LocationService) {
        self.service = service
        service.onLocationUpdate = { [weak self] location in
            guard let self else { return }
            let fix = Self.fix(location)
            self.fixBroadcaster.send(fix)
            self.broadcaster.send(fix.point)
        }
        service.onMotionChange = { [weak self] activity in
            self?.motionBroadcaster.send(Self.motionState(activity))
        }
    }

    var authorization: LocationAuthorization {
        switch service.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorizedAlways: return .always
        case .authorizedWhenInUse: return .whenInUse
        default: return .denied
        }
    }

    var lastKnownLocation: GeoPoint? { lastKnownFix?.point }
    var lastKnownFix: LocationFix? { service.lastLocation.map(Self.fix) }
    var currentMotionState: MotionState { Self.motionState(service.currentMotionActivity) }

    func requestPermission() { service.requestAuthorization() }
    func startTracking() { service.start() }
    func stopTracking() { service.stop() }
    func observeLocations() -> AsyncStream<GeoPoint> { broadcaster.stream() }
    func observeFixes() -> AsyncStream<LocationFix> { fixBroadcaster.stream() }
    func observeMotionStates() -> AsyncStream<MotionState> { motionBroadcaster.stream() }

    static func fix(_ location: CLLocation) -> LocationFix {
        LocationFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed,
            course: location.course
        )
    }

    private static func motionState(_ activity: MotionActivity) -> MotionState {
        switch activity {
        case .stationary: return .stationary
        case .walking: return .walking
        case .running: return .running
        case .cycling: return .cycling
        case .automotive: return .automotive
        case .unknown: return .unknown
        }
    }
}

@MainActor
final class DeviceStatusRepositoryImpl: DeviceStatusRepository {
    private let battery: BatteryMonitor

    init(battery: BatteryMonitor) {
        self.battery = battery
    }

    var batteryLevel: Int? { battery.level }
}

final class GeocodingRepositoryImpl: GeocodingRepository {
    private let geocoder: ReverseGeocoder
    private let cache: GeocodeCache

    init(geocoder: ReverseGeocoder, cache: GeocodeCache) {
        self.geocoder = geocoder
        self.cache = cache
    }

    func address(for point: GeoPoint) async -> String? {
        if let cached = cache.address(for: point) { return cached }
        guard let address = await geocoder.address(latitude: point.latitude, longitude: point.longitude) else { return nil }
        cache.store(address, for: point)
        return address
    }
}
