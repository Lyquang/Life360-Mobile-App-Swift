import CoreLocation

protocol LocationService: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var lastLocation: CLLocation? { get }
    var onLocationUpdate: ((CLLocation) -> Void)? { get set }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    func requestAuthorization()
    func start()
    func stop()
}

/// CLLocationManager + CoreMotion. GPS accuracy adapts to activity/battery; stationary users fall back
/// to significant-change monitoring so the GPS radio can sleep.
final class CLLocationService: NSObject, LocationService {
    private let manager = CLLocationManager()
    private let motion: MotionActivityService
    private let policy: AdaptiveLocationPolicy
    private let battery: BatterySnapshot?

    private var currentActivity: MotionActivity = .unknown
    private var appliedSettings: LocationSettings?
    private var isRunning = false

    private(set) var lastLocation: CLLocation?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    init(
        motion: MotionActivityService = MotionActivityService(),
        policy: AdaptiveLocationPolicy = AdaptiveLocationPolicy(),
        battery: BatterySnapshot? = nil
    ) {
        self.motion = motion
        self.policy = policy
        self.battery = battery
        super.init()
        manager.delegate = self
        manager.pausesLocationUpdatesAutomatically = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(powerStateDidChange),
            name: .NSProcessInfoPowerStateDidChange, object: nil
        )
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // iOS shows the "Change to Always Allow" prompt; needed for background sharing.
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func start() {
        isRunning = true
        configureBackgroundUpdates()
        motion.start { [weak self] activity in
            self?.currentActivity = activity
            self?.applyPolicy()
        }
        applyPolicy(force: true)
    }

    func stop() {
        isRunning = false
        appliedSettings = nil
        motion.stop()
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }

    // MARK: - Private

    private var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }

    private func configureBackgroundUpdates() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        // Setting this without the "location" background mode crashes at runtime.
        guard modes.contains("location") else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    private func applyPolicy(force: Bool = false) {
        guard isRunning, isAuthorized else { return }
        let settings = policy.settings(
            for: currentActivity,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            batteryLevel: battery?.level
        )
        guard force || settings != appliedSettings else { return }
        appliedSettings = settings

        manager.desiredAccuracy = settings.desiredAccuracy
        manager.distanceFilter = settings.distanceFilter
        manager.activityType = settings.activityType

        if settings.significantChangesOnly, CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.stopUpdatingLocation()
            manager.startMonitoringSignificantLocationChanges()
        } else {
            manager.stopMonitoringSignificantLocationChanges()
            manager.startUpdatingLocation()
        }
    }

    @objc private func powerStateDidChange() {
        DispatchQueue.main.async { [weak self] in self?.applyPolicy() }
    }
}

extension CLLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
        if isAuthorized {
            configureBackgroundUpdates()
            applyPolicy(force: true)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        lastLocation = location
        onLocationUpdate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown is transient; CoreLocation keeps trying.
    }
}
