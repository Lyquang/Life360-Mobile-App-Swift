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
        let start = Date(timeIntervalSince1970:
            floor(date.timeIntervalSince1970 / Self.windowSeconds) * Self.windowSeconds)
        if let old = current, start > old.start {
            completed.append(old)
            completed.removeAll { $0.start < date.addingTimeInterval(-24 * 60 * 60) }
            completed = Array(completed.suffix(96))
            store.save(completed)
            current = nil
        }
        if current == nil { current = MobileMetricWindow(start: start) }
        guard current?.start == start else { return } // Ignore a clock moving backwards.
        current?.apply(event)
    }

    func snapshot() -> [MobileMetricWindow] {
        guard enabled else { return [] }
        return completed + (current.map { [$0] } ?? [])
    }

    func clear() {
        current = nil
        completed = []
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
