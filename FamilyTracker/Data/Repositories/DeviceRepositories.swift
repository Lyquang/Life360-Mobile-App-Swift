import CoreLocation

/// Adapts Core/Location (CLLocation) to framework-independent Domain values.
final class DeviceLocationRepositoryImpl: DeviceLocationRepository {
    private let service: LocationService
    private let broadcaster = AsyncBroadcaster<GeoPoint>()
    private let fixBroadcaster = AsyncBroadcaster<LocationFix>()

    init(service: LocationService) {
        self.service = service
        service.onLocationUpdate = { [weak self] location in
            guard let self else { return }
            let fix = Self.fix(location)
            self.fixBroadcaster.send(fix)
            self.broadcaster.send(fix.point)
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

    func requestPermission() { service.requestAuthorization() }
    func startTracking() { service.start() }
    func stopTracking() { service.stop() }
    func observeLocations() -> AsyncStream<GeoPoint> { broadcaster.stream() }
    func observeFixes() -> AsyncStream<LocationFix> { fixBroadcaster.stream() }

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
