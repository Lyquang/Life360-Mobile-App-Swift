#if DEBUG
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DebugCoordinator: ObservableObject {
    @Published var isPresented = false
    @Published var isExporting = false
    @Published var errorMessage: String?
    @Published var report = DiagnosticReportDocument()

    func open() { isPresented = true }
    func monitoringView() -> MobileMonitoringView {
        let container = CompositionRoot.container
        return MobileMonitoringView(model: MobileMonitoringViewModel(
            readWindows: { await container.mobileMetrics.snapshot() },
            readMetricKit: { container.metricKitReceiver?.summaries ?? [] }
        ))
    }
    func exportForAI() {
        do {
            report = DiagnosticReportDocument(data: try PulseDiagnostics.shared.report())
            isExporting = true
        } catch { errorMessage = error.localizedDescription }
    }
}

struct DiagnosticReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data = Data()
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct DebugOverlay: ViewModifier {
    @StateObject private var coordinator = DebugCoordinator()
    func body(content: Content) -> some View {
        content
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-PulseConsole") { coordinator.open() }
            }
            .background {
                // Keep the developer shortcut without occupying app safe-area space.
                Button(action: coordinator.open) { Color.clear.frame(width: 1, height: 1) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    .accessibilityHidden(true)
                    .opacity(0)
            }
            .sheet(isPresented: $coordinator.isPresented) {
                NavigationStack {
                    NetworkInspectorView()
                }
            }
    }
}
#endif
