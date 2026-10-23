import Foundation

#if DEBUG
import UIKit
#endif

/// In-memory, aggregate-only measurement. The Release implementation is inert.
final class LocationDiagnostics {
    enum PolicyOutcome: String {
        case send
        case hold
        case drop
    }

    enum DropReason: String {
        case invalidHorizontalAccuracy
    }

    struct Snapshot {
        let emitted: [String: Int]
        let heartbeatAttempts: Int
        let motionTransitions: Int
        let managerReconfigurations: Int
        let dropped: [String: Int]
        let offlineQueueEnqueues: Int
        let policyDecisions: [String: Int]
    }

    #if DEBUG
    private struct State {
        var startedAt: Date?
        var startBattery: Int?
        var currentMotion: MotionActivity = .unknown
        var segmentStartedAt: Date?
        var segmentBattery: Int?
        var segmentSeconds: [String: TimeInterval] = [:]
        var segmentBatteryDrop: [String: Int] = [:]
        var emitted: [String: Int] = [:]
        var heartbeatAttempts = 0
        var motionTransitions = 0
        var managerReconfigurations = 0
        var dropped: [String: Int] = [:]
        var offlineQueueEnqueues = 0
        var policyDecisions: [String: Int] = [:]
    }

    private let logger: NetworkLogger
    private let battery: BatterySnapshot
    private let recorder: MobileMetricsRecording?
    private let enabled: Bool
    private let summaryInterval: TimeInterval
    private let lock = NSLock()
    private var state = State()
    private var timer: DispatchSourceTimer?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    init(logger: NetworkLogger, battery: BatterySnapshot, enabled: Bool = true,
         summaryInterval: TimeInterval = 15 * 60, observesBackground: Bool = true,
         recorder: MobileMetricsRecording? = nil) {
        self.logger = logger
        self.battery = battery
        self.recorder = recorder
        self.enabled = enabled
        self.summaryInterval = summaryInterval
        if enabled && observesBackground {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
            ) { [weak self] _ in
                self?.logSummary()
                self?.timer?.cancel()
                self?.timer = nil
            }
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil
            ) { [weak self] _ in self?.resumeTimerIfNeeded() }
        }
    }

    deinit {
        timer?.cancel()
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
    }

    func startSession(batteryLevel: Int?, now: Date = Date()) {
        guard enabled else { return }
        lock.lock()
        state = State()
        state.startedAt = now
        state.startBattery = batteryLevel
        state.segmentStartedAt = now
        state.segmentBattery = batteryLevel
        lock.unlock()

        timer?.cancel()
        timer = nil
        resumeTimerIfNeeded()
    }

    func stopSession(batteryLevel: Int?, now: Date = Date()) {
        guard enabled else { return }
        lock.lock()
        guard state.startedAt != nil else { lock.unlock(); return }
        closeSegment(at: now, batteryLevel: batteryLevel)
        lock.unlock()
        logSummary(now: now, endBattery: batteryLevel)
        timer?.cancel()
        timer = nil
        lock.lock()
        state.startedAt = nil
        lock.unlock()
        recordMetric(.state(.motionOff))
    }

    func reset() {
        guard enabled else { return }
        timer?.cancel()
        timer = nil
        lock.lock()
        state = State()
        lock.unlock()
    }

    func recordMotion(_ motion: MotionActivity, now: Date = Date()) {
        guard enabled else { return }
        let level = battery.level
        lock.lock()
        guard state.startedAt != nil, motion != state.currentMotion else { lock.unlock(); return }
        closeSegment(at: now, batteryLevel: level)
        state.currentMotion = motion
        state.motionTransitions += 1
        state.segmentStartedAt = now
        state.segmentBattery = level
        lock.unlock()
        recordMetric(.state(Self.metricState(motion)))
    }

    func recordManagerReconfiguration() {
        update { $0.managerReconfigurations += 1 }
        recordMetric(.increment(.locationReconfiguration))
    }

    func recordDrop(_ reason: DropReason) {
        update { $0.dropped[reason.rawValue, default: 0] += 1 }
        recordMetric(.increment(.fixDropped))
    }

    func recordHeartbeatAttempt() {
        update { $0.heartbeatAttempts += 1 }
        recordMetric(.increment(.heartbeatAttempt))
    }

    func recordEmit() {
        var motion: MotionActivity?
        update { state in
            motion = state.currentMotion
            state.emitted[Self.name(state.currentMotion), default: 0] += 1
        }
        if let motion { recordMetric(.locationEmit(motion: Self.metricState(motion))) }
    }

    func recordOfflineEnqueue() {
        update { $0.offlineQueueEnqueues += 1 }
        recordMetric(.increment(.offlinePoint))
    }

    func recordFixReceived(horizontalAccuracy: Double) {
        recordMetrics([.increment(.fixReceived), .horizontalAccuracy(horizontalAccuracy)])
    }

    func recordFixAccepted() { recordMetric(.increment(.fixAccepted)) }

    func recordAccuracyMode(_ mode: MobileMetricState) { recordMetric(.state(mode)) }

    func recordPermission(_ permission: MobileMetricState, reduced: Bool, changed: Bool) {
        var events: [MobileMetricEvent] = []
        if changed { events.append(.increment(.locationPermissionChange)) }
        events.append(.state(permission))
        if permission == .permissionAlways || permission == .permissionWhenInUse {
            events.append(.state(reduced ? .permissionReducedAccuracy : .permissionFullAccuracy))
        }
        recordMetrics(events)
    }

    func recordPause() { recordMetric(.increment(.locationPause)) }

    func recordPolicyDecision(outcome: PolicyOutcome, reason: String) {
        update { $0.policyDecisions["\(outcome.rawValue).\(reason)", default: 0] += 1 }
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(emitted: state.emitted, heartbeatAttempts: state.heartbeatAttempts,
                        motionTransitions: state.motionTransitions,
                        managerReconfigurations: state.managerReconfigurations,
                        dropped: state.dropped, offlineQueueEnqueues: state.offlineQueueEnqueues,
                        policyDecisions: state.policyDecisions)
    }

    func summary(now: Date = Date(), endBattery: Int? = nil) -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }
        guard let startedAt = state.startedAt else { return nil }
        var durations = state.segmentSeconds
        if let segmentStartedAt = state.segmentStartedAt {
            durations[Self.name(state.currentMotion), default: 0] += max(0, now.timeIntervalSince(segmentStartedAt))
        }
        var result: [String: Any] = [
            "durationSeconds": max(0, now.timeIntervalSince(startedAt)),
            "emittedByMotionAtTransport": state.emitted,
            "heartbeatAttempts": state.heartbeatAttempts,
            "motionTransitions": state.motionTransitions,
            "managerReconfigurations": state.managerReconfigurations,
            "droppedByReason": state.dropped,
            "offlineQueueEnqueues": state.offlineQueueEnqueues,
            "sendPolicyDecisions": state.policyDecisions,
            "secondsByMotion": durations,
            "batteryDropByMotionPercentagePoints": state.segmentBatteryDrop,
            "offlineReplayUsesMotionAtEmitTime": true
        ]
        if let start = state.startBattery { result["startBatteryPercent"] = start }
        if let endBattery {
            result["endBatteryPercent"] = endBattery
            if let start = state.startBattery, start >= endBattery {
                result["batteryDropPercentagePoints"] = start - endBattery
            }
        }
        return DiagnosticRedactor.json(result) as? [String: Any]
    }

    func logSummary(now: Date = Date(), endBattery: Int? = nil) {
        guard enabled, let payload = summary(now: now, endBattery: endBattery) else { return }
        logger.logSocket(event: "location_diagnostics_summary", payload: payload)
    }

    private func update(_ change: (inout State) -> Void) {
        guard enabled else { return }
        lock.lock()
        if state.startedAt != nil { change(&state) }
        lock.unlock()
    }

    private func recordMetric(_ event: MobileMetricEvent) {
        recordMetrics([event])
    }

    private func recordMetrics(_ events: [MobileMetricEvent]) {
        guard enabled, let recorder else { return }
        Task { for event in events { await recorder.record(event) } }
    }

    private func resumeTimerIfNeeded() {
        guard enabled, timer == nil, UIApplication.shared.applicationState != .background else { return }
        lock.lock()
        let active = state.startedAt != nil
        lock.unlock()
        guard active else { return }
        let nextTimer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        nextTimer.schedule(deadline: .now() + summaryInterval, repeating: summaryInterval)
        nextTimer.setEventHandler { [weak self] in self?.logSummary() }
        timer = nextTimer
        nextTimer.resume()
    }

    /// Called with the diagnostics lock held.
    private func closeSegment(at now: Date, batteryLevel: Int?) {
        let name = Self.name(state.currentMotion)
        if let segmentStartedAt = state.segmentStartedAt {
            state.segmentSeconds[name, default: 0] += max(0, now.timeIntervalSince(segmentStartedAt))
        }
        if let start = state.segmentBattery, let end = batteryLevel, start >= end {
            state.segmentBatteryDrop[name, default: 0] += start - end
        }
        state.segmentStartedAt = nil
    }

    private static func name(_ motion: MotionActivity) -> String {
        switch motion {
        case .stationary: return "stationary"
        case .walking: return "walking"
        case .running: return "running"
        case .cycling: return "cycling"
        case .automotive: return "automotive"
        case .unknown: return "unknown"
        }
    }

    private static func metricState(_ motion: MotionActivity) -> MobileMetricState {
        switch motion {
        case .stationary: return .motionStationary
        case .walking: return .motionWalking
        case .running: return .motionRunning
        case .cycling: return .motionCycling
        case .automotive: return .motionAutomotive
        case .unknown: return .motionUnknown
        }
    }
    #else
    init(logger: NetworkLogger, battery: BatterySnapshot, enabled: Bool = true,
         summaryInterval: TimeInterval = 15 * 60, observesBackground: Bool = true,
         recorder: MobileMetricsRecording? = nil) {}
    func startSession(batteryLevel: Int?, now: Date = Date()) {}
    func stopSession(batteryLevel: Int?, now: Date = Date()) {}
    func reset() {}
    func recordMotion(_ motion: MotionActivity, now: Date = Date()) {}
    func recordManagerReconfiguration() {}
    func recordDrop(_ reason: DropReason) {}
    func recordHeartbeatAttempt() {}
    func recordEmit() {}
    func recordOfflineEnqueue() {}
    func recordFixReceived(horizontalAccuracy: Double) {}
    func recordFixAccepted() {}
    func recordAccuracyMode(_ mode: MobileMetricState) {}
    func recordPermission(_ permission: MobileMetricState, reduced: Bool, changed: Bool) {}
    func recordPause() {}
    func recordPolicyDecision(outcome: PolicyOutcome, reason: String) {}
    func snapshot() -> Snapshot {
        Snapshot(emitted: [:], heartbeatAttempts: 0, motionTransitions: 0,
                 managerReconfigurations: 0, dropped: [:], offlineQueueEnqueues: 0,
                 policyDecisions: [:])
    }
    func summary(now: Date = Date(), endBattery: Int? = nil) -> [String: Any]? { nil }
    func logSummary(now: Date = Date(), endBattery: Int? = nil) {}
    #endif
}
