import CoreMotion

enum MotionActivity: Equatable {
    case stationary
    case walking
    case running
    case cycling
    case automotive
    case unknown
}

/// Wraps CMMotionActivityManager (M-series coprocessor, near-zero battery cost).
final class MotionActivityService {
    private let manager = CMMotionActivityManager()

    var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    func start(onChange: @escaping (MotionActivity) -> Void) {
        guard isAvailable else { return }
        manager.startActivityUpdates(to: .main) { activity in
            guard let activity, activity.confidence != .low else { return }
            onChange(Self.map(activity))
        }
    }

    func stop() {
        manager.stopActivityUpdates()
    }

    private static func map(_ activity: CMMotionActivity) -> MotionActivity {
        if activity.automotive { return .automotive }
        if activity.cycling { return .cycling }
        if activity.running { return .running }
        if activity.walking { return .walking }
        if activity.stationary { return .stationary }
        return .unknown
    }
}
