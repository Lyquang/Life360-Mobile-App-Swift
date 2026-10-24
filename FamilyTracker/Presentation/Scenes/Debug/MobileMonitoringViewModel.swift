#if DEBUG
import Foundation
import Combine

struct MobileMonitoringReport: Codable {
    let windows: [MobileMetricWindow]
    let metricKit: [MetricKitSummary]

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= 512 * 1_024 else { throw CocoaError(.fileWriteOutOfSpace) }
        return data
    }
}

@MainActor
final class MobileMonitoringViewModel: ObservableObject {
    @Published private(set) var windows: [MobileMetricWindow] = []
    @Published private(set) var metricKit: [MetricKitSummary] = []
    @Published private(set) var isLoading = false
    @Published var exportError = false
    private let readWindows: () async -> [MobileMetricWindow]
    private let readMetricKit: () -> [MetricKitSummary]

    init(readWindows: @escaping () async -> [MobileMetricWindow],
         readMetricKit: @escaping () -> [MetricKitSummary]) {
        self.readWindows = readWindows
        self.readMetricKit = readMetricKit
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let snapshot = await readWindows()
        guard !Task.isCancelled else { return }
        windows = snapshot
        metricKit = readMetricKit()
    }

    func export() async -> Data? {
        guard !isLoading else { return nil }
        await refresh()
        guard !Task.isCancelled else { return nil }
        do { return try MobileMonitoringReport(windows: windows, metricKit: metricKit).encoded() }
        catch { exportError = true; return nil }
    }

    func count(_ counter: MobileMetricCounter) -> String {
        number(windows.reduce(0.0) { $0 + Double($1.counters[counter] ?? 0) })
    }

    func bytes(_ keyPath: KeyPath<MobileMetricWindow, [MobileNetworkKind: Int]>) -> String {
        // A KeyPath selects a typed property, allowing one formatter for each byte counter.
        let bytes = windows.reduce(0.0) { total, window in
            total + window[keyPath: keyPath].values.reduce(0.0) { $0 + Double($1) }
        }
        return L10n.tr("monitor.bytes", number(bytes))
    }

    var battery: String {
        guard let level = windows.last?.batteryEnd else { return L10n.tr("monitor.unavailable") }
        return L10n.tr("monitor.percent", number(Double(level)))
    }

    var latestMetric: MetricKitSummary? { metricKit.last { $0.kind == .metrics } }

    func metric(_ field: MetricKitField, unitKey: String) -> String {
        guard let value = latestMetric?.values[field] else { return L10n.tr("monitor.unavailable") }
        return L10n.tr(unitKey, number(value))
    }

    private func number(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = L10n.language.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? L10n.tr("monitor.unavailable")
    }
}
#endif
