#if DEBUG
import SwiftUI

struct MobileMonitoringView: View {
    @StateObject var model: MobileMonitoringViewModel
    @State private var document = DiagnosticReportDocument()
    @State private var isExporting = false
    @State private var exportTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                if model.isLoading { ProgressView().accessibilityLabel(L10n.tr("monitor.loading")) }
                if model.windows.isEmpty { Text(L10n.tr("monitor.empty")) }
                row("monitor.battery", model.battery)
                row("monitor.fixes", model.count(.fixReceived))
                row("monitor.emits", model.count(.locationEmit))
                row("monitor.requests", model.count(.request))
                row("monitor.failures", model.count(.requestFailure))
            } footer: { Text(L10n.tr("monitor.coverage")) }
            Section(L10n.tr("monitor.network")) {
                row("monitor.rest_sent", model.bytes(\.sentBytes))
                row("monitor.rest_received", model.bytes(\.receivedBytes))
                row("monitor.media_sent", model.bytes(\.mediaSentBytesByNetwork))
                row("monitor.media_received", model.bytes(\.mediaReceivedBytesByNetwork))
                row("monitor.socket_sent", model.bytes(\.socketSentBytesByNetwork))
                row("monitor.socket_received", model.bytes(\.socketReceivedBytesByNetwork))
            }
            Section(L10n.tr("monitor.metrickit")) {
                if let report = model.latestMetric {
                    Text(report.end.formatted(.dateTime.locale(L10n.language.locale)))
                    row("monitor.cpu", model.metric(.cpuSeconds, unitKey: "monitor.seconds"))
                    row("monitor.background_location", model.metric(.backgroundLocationSeconds, unitKey: "monitor.seconds"))
                    row("monitor.memory", model.metric(.peakMemoryBytes, unitKey: "monitor.bytes"))
                } else { Text(L10n.tr("monitor.metric_pending")) }
            }
        }
        .navigationTitle(L10n.tr("monitor.title"))
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .toolbar {
            Button {
                guard exportTask == nil else { return }
                exportTask = Task { @MainActor in
                    defer { exportTask = nil }
                    guard let data = await model.export(), !Task.isCancelled else { return }
                    document = DiagnosticReportDocument(data: data)
                    isExporting = true
                }
            } label: {
                Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.tr("monitor.export"))
            .disabled(model.isLoading || exportTask != nil)
        }
        .onDisappear { exportTask?.cancel(); exportTask = nil }
        .fileExporter(isPresented: $isExporting, document: document, contentType: .json,
                      defaultFilename: "FamilyTracker-Metrics") { result in
            if case .failure = result { model.exportError = true }
        }
        .alert(L10n.tr("monitor.export_error"), isPresented: $model.exportError) {
            Button(L10n.tr("monitor.ok"), role: .cancel) {}
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr(key)).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
