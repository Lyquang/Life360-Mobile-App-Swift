import CoreLocation

/// Adapts Core/Location (CLLocation) to the Domain (GeoPoint).
final class DeviceLocationRepositoryImpl: DeviceLocationRepository {
    private let service: LocationService
    private let broadcaster = AsyncBroadcaster<GeoPoint>()

    init(service: LocationService) {
        self.service = service
        service.onLocationUpdate = { [weak self] location in
            self?.broadcaster.send(Self.point(location))
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

    var lastKnownLocation: GeoPoint? { service.lastLocation.map(Self.point) }

    func requestPermission() { service.requestAuthorization() }
    func startTracking() { service.start() }
    func stopTracking() { service.stop() }
    func observeLocations() -> AsyncStream<GeoPoint> { broadcaster.stream() }

    private static func point(_ location: CLLocation) -> GeoPoint {
        GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
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
