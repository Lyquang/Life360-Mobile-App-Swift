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
    private var observer: NSObjectProtocol?

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var level: Int? {
        refresh()
        return snapshot.level
    }

    private func refresh() {
        let value = UIDevice.current.batteryLevel
        snapshot.level = value >= 0 ? Int((value * 100).rounded()) : nil
    }
}
