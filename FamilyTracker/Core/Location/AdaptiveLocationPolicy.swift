import CoreLocation

struct LocationSettings: Equatable {
    let desiredAccuracy: CLLocationAccuracy
    let distanceFilter: CLLocationDistance
    let activityType: CLActivityType
    /// Stop continuous GPS and rely on significant-change monitoring (cell/Wi-Fi, ~500m, very low power).
    let significantChangesOnly: Bool
}

/// Chooses GPS accuracy from the current motion activity and power state.
struct AdaptiveLocationPolicy {
    var lowBatteryThreshold = 20

    func settings(for activity: MotionActivity, isLowPowerMode: Bool, batteryLevel: Int?) -> LocationSettings {
        let base: LocationSettings
        switch activity {
        case .stationary:
            base = LocationSettings(desiredAccuracy: kCLLocationAccuracyHundredMeters, distanceFilter: 100,
                                    activityType: .other, significantChangesOnly: true)
        case .walking, .running:
            base = LocationSettings(desiredAccuracy: kCLLocationAccuracyNearestTenMeters, distanceFilter: 20,
                                    activityType: .fitness, significantChangesOnly: false)
        case .cycling:
            base = LocationSettings(desiredAccuracy: kCLLocationAccuracyNearestTenMeters, distanceFilter: 30,
                                    activityType: .fitness, significantChangesOnly: false)
        case .automotive:
            base = LocationSettings(desiredAccuracy: kCLLocationAccuracyBestForNavigation, distanceFilter: 50,
                                    activityType: .automotiveNavigation, significantChangesOnly: false)
        case .unknown:
            base = LocationSettings(desiredAccuracy: kCLLocationAccuracyNearestTenMeters, distanceFilter: 25,
                                    activityType: .other, significantChangesOnly: false)
        }

        let isLowBattery = isLowPowerMode || (batteryLevel ?? 100) < lowBatteryThreshold
        return isLowBattery ? degrade(base) : base
    }

    private func degrade(_ settings: LocationSettings) -> LocationSettings {
        let accuracy: CLLocationAccuracy
        switch settings.desiredAccuracy {
        case kCLLocationAccuracyBestForNavigation, kCLLocationAccuracyBest:
            accuracy = kCLLocationAccuracyNearestTenMeters
        case kCLLocationAccuracyNearestTenMeters:
            accuracy = kCLLocationAccuracyHundredMeters
        default:
            accuracy = kCLLocationAccuracyKilometer
        }
        return LocationSettings(
            desiredAccuracy: accuracy,
            distanceFilter: settings.distanceFilter * 2,
            activityType: settings.activityType,
            significantChangesOnly: settings.significantChangesOnly
        )
    }
}
