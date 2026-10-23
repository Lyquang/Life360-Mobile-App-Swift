import CoreLocation

protocol LocationService: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var lastLocation: CLLocation? { get }
    var currentMotionActivity: MotionActivity { get }
    var onLocationUpdate: ((CLLocation) -> Void)? { get set }
    var onMotionChange: ((MotionActivity) -> Void)? { get set }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    func requestAuthorization()
    func start()
    func stop()
    func requestFreshLocation()
}

extension LocationService {
    func requestFreshLocation() {}
}

/// CLLocationManager + CoreMotion. GPS accuracy adapts to activity/battery; stationary users fall back
/// to significant-change monitoring so the GPS radio can sleep.
final class CLLocationService: NSObject, LocationService {
    private let manager = CLLocationManager()
    private var refreshManager: CLLocationManager?
    private let motion: MotionActivityService
    private let policy: AdaptiveLocationPolicy
    private let battery: BatterySnapshot?
    private let diagnostics: LocationDiagnostics?

    private(set) var currentMotionActivity: MotionActivity = .unknown
    private var appliedSettings: LocationSettings?
    private var isRunning = false
    private var lastAuthorization: CLAuthorizationStatus?
    private var lastPrecision: CLAccuracyAuthorization?

    private(set) var lastLocation: CLLocation?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onMotionChange: ((MotionActivity) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    init(
        motion: MotionActivityService = MotionActivityService(),
        policy: AdaptiveLocationPolicy = AdaptiveLocationPolicy(),
        battery: BatterySnapshot? = nil,
        diagnostics: LocationDiagnostics? = nil
    ) {
        self.motion = motion
        self.policy = policy
        self.battery = battery
        self.diagnostics = diagnostics
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
            guard let self else { return }
            self.diagnostics?.recordMotion(activity)
            let changed = activity != self.currentMotionActivity
            self.currentMotionActivity = activity
            if changed { self.onMotionChange?(activity) }
            self.applyPolicy()
        }
        applyPolicy(force: true)
    }

    func stop() {
        isRunning = false
        diagnostics?.recordAccuracyMode(.accuracyOff)
        appliedSettings = nil
        motion.stop()
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        refreshManager?.stopUpdatingLocation()
    }

    func requestFreshLocation() {
        guard isRunning, isAuthorized else { return }
        if refreshManager == nil {
            let oneShot = CLLocationManager()
            oneShot.delegate = self
            refreshManager = oneShot
        }
        refreshManager?.desiredAccuracy = manager.desiredAccuracy
        refreshManager?.requestLocation()
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
            for: currentMotionActivity,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            batteryLevel: battery?.level
        )
        guard force || settings != appliedSettings else { return }
        diagnostics?.recordManagerReconfiguration()
        diagnostics?.recordAccuracyMode(Self.accuracyMode(
            for: settings,
            significantAvailable: CLLocationManager.significantLocationChangeMonitoringAvailable()
        ))
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

    private static func accuracyMode(for settings: LocationSettings, significantAvailable: Bool) -> MobileMetricState {
        if settings.significantChangesOnly && significantAvailable { return .accuracySignificant }
        switch settings.desiredAccuracy {
        case kCLLocationAccuracyBestForNavigation, kCLLocationAccuracyBest: return .accuracyNavigation
        case kCLLocationAccuracyNearestTenMeters: return .accuracyTenMeters
        case kCLLocationAccuracyHundredMeters: return .accuracyHundredMeters
        case kCLLocationAccuracyKilometer: return .accuracyKilometer
        default: return .accuracyOther
        }
    }
}

extension CLLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager === self.manager else { return }
        let status = manager.authorizationStatus
        let precision = manager.accuracyAuthorization
        let changed = lastAuthorization != nil && (lastAuthorization != status || lastPrecision != precision)
        if lastAuthorization != status || lastPrecision != precision {
            let permission: MobileMetricState
            switch status {
            case .authorizedAlways: permission = .permissionAlways
            case .authorizedWhenInUse: permission = .permissionWhenInUse
            case .denied: permission = .permissionDenied
            case .restricted: permission = .permissionRestricted
            case .notDetermined: permission = .permissionUndetermined
            @unknown default: permission = .permissionUndetermined
            }
            diagnostics?.recordPermission(permission, reduced: precision == .reducedAccuracy, changed: changed)
            lastAuthorization = status
            lastPrecision = precision
        }
        onAuthorizationChange?(manager.authorizationStatus)
        if isAuthorized {
            configureBackgroundUpdates()
            applyPolicy(force: true)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRunning, isAuthorized else { return }
        guard let location = locations.last else { return }
        diagnostics?.recordFixReceived(horizontalAccuracy: location.horizontalAccuracy)
        guard location.horizontalAccuracy >= 0 else {
            diagnostics?.recordDrop(.invalidHorizontalAccuracy)
            return
        }
        lastLocation = location
        diagnostics?.recordFixAccepted()
        onLocationUpdate?(location)
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        guard manager === self.manager else { return }
        diagnostics?.recordPause()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown is transient; CoreLocation keeps trying.
    }
}
