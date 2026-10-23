import Foundation

extension MobileMetricWindow {
    // `mutating` lets this struct method update the window's stored counters and buckets.
    mutating func apply(_ event: MobileMetricEvent) {
        switch event {
        case .increment(let counter):
            counters[counter] = saturatingAdd(counters[counter] ?? 0, 1)
        case .latency(let group, let milliseconds):
            guard milliseconds >= 0 else { return }
            var buckets = latencyBuckets[group] ?? [0, 0, 0, 0]
            let index: Int
            switch milliseconds {
            case ..<100: index = 0
            case ..<500: index = 1
            case ..<2_000: index = 2
            default: index = 3
            }
            buckets[index] = saturatingAdd(buckets[index], 1)
            latencyBuckets[group] = buckets
        case .bytes(let network, let sent, let received):
            guard sent >= 0, received >= 0 else { return }
            sentBytes[network] = saturatingAdd(sentBytes[network] ?? 0, sent)
            receivedBytes[network] = saturatingAdd(receivedBytes[network] ?? 0, received)
        case .batteryLevel(let level):
            guard (0...100).contains(level) else { return }
            if batteryStart == nil { batteryStart = level }
            batteryEnd = level
        case .horizontalAccuracy(let accuracy):
            let index: Int
            switch accuracy {
            case ..<0: index = 4
            case ..<10: index = 0
            case ..<50: index = 1
            case ..<100: index = 2
            default: index = accuracy.isFinite ? 3 : 4
            }
            horizontalAccuracyBuckets[index] = saturatingAdd(horizontalAccuracyBuckets[index], 1)
        case .state:
            break // The actor accounts for elapsed time before changing state.
        case .count(let counter, let amount):
            guard amount > 0 else { return }
            counters[counter] = saturatingAdd(counters[counter] ?? 0, amount)
        case .bufferSnapshot(let depth, let oldestAgeSeconds):
            guard (0...10_000).contains(depth) else { return }
            bufferDepthLatest = depth
            bufferDepthPeak = max(bufferDepthPeak ?? 0, depth)
            guard depth > 0, let age = oldestAgeSeconds, age.isFinite, age >= 0 else {
                bufferAgeBucketLatest = nil
                return
            }
            switch age {
            case ..<300: bufferAgeBucketLatest = 0
            case ..<1_800: bufferAgeBucketLatest = 1
            case ..<7_200: bufferAgeBucketLatest = 2
            case ..<86_400: bufferAgeBucketLatest = 3
            default: bufferAgeBucketLatest = 4
            }
        case .locationEmit(let motion):
            guard motion.group == .motion else { return }
            counters[.locationEmit] = saturatingAdd(counters[.locationEmit] ?? 0, 1)
            locationEmitsByMotion[motion] = saturatingAdd(locationEmitsByMotion[motion] ?? 0, 1)
        case .socketPayload(let event, let network, let sent, let received):
            guard sent >= 0, received >= 0 else { return }
            socketSentBytesByEvent[event] = saturatingAdd(socketSentBytesByEvent[event] ?? 0, sent)
            socketReceivedBytesByEvent[event] = saturatingAdd(socketReceivedBytesByEvent[event] ?? 0, received)
            socketSentBytesByNetwork[network] = saturatingAdd(socketSentBytesByNetwork[network] ?? 0, sent)
            socketReceivedBytesByNetwork[network] = saturatingAdd(socketReceivedBytesByNetwork[network] ?? 0, received)
        case .socketReady(let milliseconds):
            guard milliseconds >= 0 else { return }
            let index: Int
            switch milliseconds {
            case ..<100: index = 0
            case ..<500: index = 1
            case ..<2_000: index = 2
            default: index = 3
            }
            socketReadyLatencyBuckets[index] = saturatingAdd(socketReadyLatencyBuckets[index], 1)
        }
    }

    private func saturatingAdd(_ left: Int, _ right: Int) -> Int {
        left > Int.max - right ? Int.max : left + right
    }
}

actor MobileMetricsCollector: MobileMetricsRecording {
    private static let windowSeconds: TimeInterval = 15 * 60
    private let store: MobileMetricsStore
    private let now: @Sendable () -> Date
    private var enabled: Bool
    private var completed: [MobileMetricWindow]
    private var current: MobileMetricWindow?
    private var activeStates: [MobileMetricStateGroup: MobileMetricState] = [:]
    private var lastAdvancedAt: Date?

    init(store: MobileMetricsStore = .appStore, enabled: Bool = true,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
        #if DEBUG
        self.enabled = enabled
        self.completed = enabled ? store.load() : []
        if !enabled { store.clear() }
        #else
        self.enabled = false
        self.completed = []
        store.clear()
        #endif
    }

    func record(_ event: MobileMetricEvent) {
        guard enabled else { return }
        let date = now()
        guard advance(to: date) else { return }
        if case .state(let state) = event {
            activeStates[state.group] = state
        } else {
            current?.apply(event)
        }
    }

    func snapshot() -> [MobileMetricWindow] {
        guard enabled else { return [] }
        _ = advance(to: now())
        return completed + (current.map { [$0] } ?? [])
    }

    // Split long-lived states at UTC window boundaries without waking the app on a timer.
    private func advance(to date: Date) -> Bool {
        if current == nil {
            current = MobileMetricWindow(start: Self.windowStart(for: date))
            lastAdvancedAt = date
            return true
        }
        guard let previous = lastAdvancedAt, date >= previous else { return false }
        if date.timeIntervalSince(previous) > 24 * 60 * 60 {
            activeStates.removeAll()
            current = MobileMetricWindow(start: Self.windowStart(for: date))
            lastAdvancedAt = date
            completed.removeAll { $0.start < date.addingTimeInterval(-24 * 60 * 60) }
            store.save(completed)
            return true
        }
        var rotated = false
        while let window = current, date >= window.start.addingTimeInterval(Self.windowSeconds) {
            let boundary = window.start.addingTimeInterval(Self.windowSeconds)
            accrue(until: boundary)
            if let closed = current { completed.append(closed) }
            current = MobileMetricWindow(start: boundary)
            rotated = true
        }
        accrue(until: date)
        if rotated {
            completed.removeAll { $0.start < date.addingTimeInterval(-24 * 60 * 60) }
            completed = Array(completed.suffix(96))
            store.save(completed)
        }
        return true
    }

    private func accrue(until date: Date) {
        guard let previous = lastAdvancedAt else { return }
        let seconds = max(0, date.timeIntervalSince(previous))
        for state in activeStates.values {
            current?.secondsByState[state, default: 0] += seconds
        }
        lastAdvancedAt = date
    }

    private static func windowStart(for date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / windowSeconds) * windowSeconds)
    }

    func clear() {
        current = nil
        completed = []
        activeStates.removeAll()
        lastAdvancedAt = nil
        store.clear()
    }

    func setEnabled(_ value: Bool) {
        #if DEBUG
        if !value { clear() }
        enabled = value
        #else
        enabled = false
        clear()
        #endif
    }
}

enum WholeDeviceBatteryTrend {
    static func percentagePointsPerHour(start: Int?, end: Int?, seconds: TimeInterval,
                                        charged: Bool, powerModeChanged: Bool,
                                        thermalChanged: Bool) -> Double? {
        guard let start, let end, (0...100).contains(start), (0...100).contains(end),
              start >= end, seconds.isFinite, seconds >= 30 * 60,
              !charged, !powerModeChanged, !thermalChanged else { return nil }
        return Double(start - end) * 3_600 / seconds
    }
}
