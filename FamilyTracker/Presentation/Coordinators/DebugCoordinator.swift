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
            .safeAreaInset(edge: .top, alignment: .trailing, spacing: 0) {
                Button(action: coordinator.open) {
                    Image(systemName: "waveform.path.ecg")
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Open Pulse Debugger")
                .accessibilityIdentifier("pulse.open")
                .help("Pulse (Command-Shift-L)")
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .padding(.trailing, 12)
            }
            .sheet(isPresented: $coordinator.isPresented) {
                NavigationStack {
                    NetworkInspectorView()
                }
            }
    }
}
#endif
