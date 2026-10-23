import Foundation
import Network

/// One passive path observer while Debug metrics are enabled; it never probes the network.
final class NetworkPathObserver {
    private let recorder: MobileMetricsRecording
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "familytracker.metrics.network-path")
    private var monitor: NWPathMonitor?
    private var generation = 0
    private var current: MobileNetworkKind = .unknown

    init(recorder: MobileMetricsRecording) { self.recorder = recorder }

    var networkKind: MobileNetworkKind {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func start() {
        lock.lock()
        guard monitor == nil else { lock.unlock(); return }
        let observer = NWPathMonitor()
        generation += 1
        let activeGeneration = generation
        monitor = observer
        lock.unlock()
        observer.pathUpdateHandler = { [weak self] path in
            self?.update(path, generation: activeGeneration)
        }
        observer.start(queue: queue)
    }

    func stop() {
        lock.lock()
        let old = monitor
        monitor = nil
        generation += 1
        current = .unknown
        lock.unlock()
        old?.cancel()
    }

    private func update(_ path: NWPath, generation receivedGeneration: Int) {
        let kind = Self.classify(satisfied: path.status == .satisfied,
                                 cellular: path.usesInterfaceType(.cellular),
                                 wifi: path.usesInterfaceType(.wifi))
        lock.lock()
        guard monitor != nil, generation == receivedGeneration else { lock.unlock(); return }
        current = kind
        lock.unlock()
        let state: MobileMetricState
        switch kind {
        case .wifi: state = .networkWifi
        case .cellular: state = .networkCellular
        case .other: state = .networkOther
        case .offline: state = .networkOffline
        case .unknown: state = .networkUnknown
        }
        Task { [recorder] in await recorder.record(.state(state)) }
    }

    static func classify(satisfied: Bool, cellular: Bool, wifi: Bool) -> MobileNetworkKind {
        if !satisfied { return .offline }
        if cellular { return .cellular }
        if wifi { return .wifi }
        return .other
    }

    deinit { monitor?.cancel() }
}
