import UIKit

/// Thread-safe last-known battery value, readable from non-main contexts (e.g. CoreLocation callbacks).
final class BatterySnapshot {
    private let lock = NSLock()
    private var storedLevel: Int?

    var level: Int? {
        get { lock.lock(); defer { lock.unlock() }; return storedLevel }
        set { lock.lock(); storedLevel = newValue; lock.unlock() }
    }
}

/// Real battery level (UIDevice). Returns nil on the Simulator where the level is unknown.
@MainActor
final class BatteryMonitor {
    let snapshot = BatterySnapshot()
    var onMetricsEvents: (([MobileMetricEvent]) -> Void)? {
        didSet { reportDeviceState() }
    }
    private var observers: [NSObjectProtocol] = []

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        #if DEBUG
        let notifications: [Notification.Name] = [UIDevice.batteryLevelDidChangeNotification,
                                                  UIDevice.batteryStateDidChangeNotification,
                                                  .NSProcessInfoPowerStateDidChange,
                                                  ProcessInfo.thermalStateDidChangeNotification,
                                                  UIApplication.didEnterBackgroundNotification,
                                                  UIApplication.didBecomeActiveNotification]
        #else
        let notifications: [Notification.Name] = [UIDevice.batteryLevelDidChangeNotification]
        #endif
        for name in notifications {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reportDeviceState() }
            })
        }
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    var level: Int? {
        refresh()
        return snapshot.level
    }

    private func refresh() {
        let value = UIDevice.current.batteryLevel
        snapshot.level = value >= 0 ? Int((value * 100).rounded()) : nil
    }

    private func reportDeviceState() {
        refresh()
        guard let onMetricsEvents else { return }
        let batteryState: MobileMetricState
        switch UIDevice.current.batteryState {
        case .charging, .full: batteryState = .charging
        case .unplugged: batteryState = .unplugged
        case .unknown: batteryState = .batteryUnknown
        @unknown default: batteryState = .batteryUnknown
        }
        let thermal: MobileMetricState
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .thermalNominal
        case .fair: thermal = .thermalFair
        case .serious: thermal = .thermalSerious
        case .critical: thermal = .thermalCritical
        // `@unknown default` handles cases a future iOS SDK may add to this enum.
        @unknown default: thermal = .thermalCritical
        }
        var events: [MobileMetricEvent] = []
        if let level = snapshot.level { events.append(.batteryLevel(level)) }
        events.append(.state(batteryState))
        events.append(.state(ProcessInfo.processInfo.isLowPowerModeEnabled ? .lowPower : .normalPower))
        events.append(.state(thermal))
        events.append(.state(UIApplication.shared.applicationState == .background ? .background : .foreground))
        onMetricsEvents(events)
    }
}
