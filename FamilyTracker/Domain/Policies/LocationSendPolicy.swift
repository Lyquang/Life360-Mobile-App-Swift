import Foundation

enum MotionState: String, CaseIterable, Sendable {
    case stationary
    case walking
    case running
    case cycling
    case automotive
    case unknown
}

struct LocationSendConfiguration: Sendable, Equatable {
    struct Mode: Sendable, Equatable {
        let minSendInterval: TimeInterval
        let targetInterval: TimeInterval
        let minDistance: Double
        let maxDistance: Double
        let maxHeartbeatAge: TimeInterval
    }

    let stationary: Mode
    let walking: Mode
    let running: Mode
    let cycling: Mode
    let automotive: Mode
    let unknown: Mode

    func mode(for state: MotionState) -> Mode {
        switch state {
        case .stationary: return stationary
        case .walking: return walking
        case .running: return running
        case .cycling: return cycling
        case .automotive: return automotive
        case .unknown: return unknown
        }
    }

    static let baseline = LocationSendConfiguration(
        stationary: Mode(minSendInterval: 30, targetInterval: 30,
                         minDistance: 50, maxDistance: 50, maxHeartbeatAge: 30),
        walking: Mode(minSendInterval: 20, targetInterval: 20,
                      minDistance: 20, maxDistance: 75, maxHeartbeatAge: 60),
        running: Mode(minSendInterval: 20, targetInterval: 20,
                      minDistance: 20, maxDistance: 75, maxHeartbeatAge: 60),
        cycling: Mode(minSendInterval: 15, targetInterval: 15,
                      minDistance: 30, maxDistance: 150, maxHeartbeatAge: 45),
        automotive: Mode(minSendInterval: 10, targetInterval: 10,
                         minDistance: 50, maxDistance: 250, maxHeartbeatAge: 30),
        unknown: Mode(minSendInterval: 20, targetInterval: 20,
                      minDistance: 25, maxDistance: 100, maxHeartbeatAge: 60)
    )
}

struct LocationSendPolicy {
    struct SentLocation: Equatable, Sendable {
        let fix: LocationFix
        let sentAt: Date
        let motionState: MotionState
    }

    struct PendingLocation: Equatable, Sendable {
        let fix: LocationFix
        let heldAt: Date
        let motionState: MotionState
    }

    enum SendReason: String, Equatable, Sendable {
        case firstFix
        case motionChanged
        case moved
        case heartbeatDue
        case trailingEdge
    }

    enum HoldReason: String, Equatable, Sendable {
        case minimumInterval
    }

    enum DropReason: String, Equatable, Sendable {
        case withinAccuracyOrDistanceThreshold
    }

    enum Decision: Equatable, Sendable {
        case send(LocationFix, SendReason)
        case hold(PendingLocation, HoldReason)
        case drop(DropReason)
    }

    func decide(
        fix: LocationFix,
        lastSent: SentLocation?,
        pending: PendingLocation?,
        now: Date,
        motionState: MotionState,
        config: LocationSendConfiguration = .baseline
    ) -> Decision {
        guard let lastSent else { return .send(fix, .firstFix) }
        if motionState != lastSent.motionState { return .send(fix, .motionChanged) }

        let mode = config.mode(for: motionState)
        let elapsed = max(0, now.timeIntervalSince(lastSent.sentAt))
        let currentMoved = hasMoved(fix, since: lastSent.fix, mode: mode)

        if elapsed < mode.minSendInterval {
            if currentMoved {
                return .hold(
                    PendingLocation(fix: fix, heldAt: pending?.heldAt ?? now, motionState: motionState),
                    .minimumInterval
                )
            }
            if let pending { return .hold(pending, .minimumInterval) }
            return .drop(.withinAccuracyOrDistanceThreshold)
        }

        if elapsed >= mode.maxHeartbeatAge { return .send(fix, .heartbeatDue) }
        if let pending,
           fix == pending.fix,
           hasMoved(pending.fix, since: lastSent.fix, mode: mode) {
            return .send(pending.fix, .trailingEdge)
        }
        if currentMoved { return .send(fix, .moved) }
        if let pending, hasMoved(pending.fix, since: lastSent.fix, mode: mode) {
            return .send(pending.fix, .trailingEdge)
        }
        return .drop(.withinAccuracyOrDistanceThreshold)
    }

    private func hasMoved(
        _ fix: LocationFix,
        since previous: LocationFix,
        mode: LocationSendConfiguration.Mode
    ) -> Bool {
        let distance = fix.point.distance(to: previous.point)
        let speed = resolvedSpeed(for: fix, since: previous, distance: distance)
        let dynamicDistance = min(mode.maxDistance, max(mode.minDistance, speed * mode.targetInterval))
        return distance >= max(dynamicDistance, max(0, fix.horizontalAccuracy))
    }

    private func resolvedSpeed(for fix: LocationFix, since previous: LocationFix, distance: Double) -> Double {
        if fix.speed >= 0 { return fix.speed }
        let elapsed = fix.timestamp.timeIntervalSince(previous.timestamp)
        return elapsed > 0 ? distance / elapsed : 0
    }
}
