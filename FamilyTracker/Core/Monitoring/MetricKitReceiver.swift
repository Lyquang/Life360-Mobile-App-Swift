import Foundation
import MetricKit

/// MetricKit reports arrive later than the activity they describe, usually on a daily cadence.
@MainActor
final class MetricKitReceiver: NSObject, MXMetricManagerSubscriber {
    private let manager: MXMetricManager
    private let store: MetricKitSummaryStore
    private(set) var summaries: [MetricKitSummary]
    private var isActive = false

    init(manager: MXMetricManager = .shared, store: MetricKitSummaryStore = MetricKitSummaryStore()) {
        self.manager = manager
        self.store = store
        summaries = store.load()
        super.init()
    }

    func start(clearPrevious: Bool = false) {
        if clearPrevious {
            summaries = []
            store.clear()
        }
        guard !isActive else { return }
        isActive = true
        manager.add(self)
        // Do not re-import pastPayloads after logout: they may cover the previous account.
    }

    func stop(clear: Bool) {
        if isActive { manager.remove(self) }
        isActive = false
        if clear {
            summaries = []
            store.clear()
        }
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let summaries = payloads.compactMap(MetricKitSummary.init(metricPayload:))
        Task { @MainActor [weak self] in self?.append(summaries) }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let summaries = payloads.compactMap(MetricKitSummary.init(diagnosticPayload:))
        Task { @MainActor [weak self] in self?.append(summaries) }
    }

    private func append(_ incoming: [MetricKitSummary]) {
        guard isActive, !incoming.isEmpty else { return }
        summaries = MetricKitSummary.merging(summaries, with: incoming)
        store.save(summaries)
    }
}
