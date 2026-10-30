import CoreLocation

/// A dedicated manager never starts the continuous sharing manager or its socket pipeline.
@MainActor
// Core Location delivers delegate callbacks on the run loop where the manager was created (main).
final class SOSCoreLocationDriver: NSObject, SOSLocationDriver, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onAuthorization: ((SOSLocationAuthorization) -> Void)?
    var onSample: ((SOSLocationSample) -> Void)?
    var onFailure: ((SOSLocationFailure) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var authorization: SOSLocationAuthorization {
        switch manager.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .unavailable
        }
    }

    func requestAuthorization() { manager.requestWhenInUseAuthorization() }
    func requestLocation() { manager.requestLocation() }

    func stop() {
        manager.stopUpdatingLocation()
        manager.delegate = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorization?(authorization)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else { onFailure?(.unavailable); return }
        onSample?(SOSLocationSample(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                    horizontalAccuracy: fix.horizontalAccuracy, timestamp: fix.timestamp))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied { onFailure?(.permissionDenied) }
        else { onFailure?(.unavailable) }
    }
}
