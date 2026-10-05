#if DEBUG
import SwiftUI
import PulseUI

struct NetworkInspectorView: View {
    @StateObject private var coordinator = DebugCoordinator()

    var body: some View {
        ConsoleView()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: coordinator.exportForAI) { Image(systemName: "doc.badge.arrow.up") }
                        .accessibilityLabel("Export JSON for AI")
                        .accessibilityIdentifier("pulse.exportAI")
                        .help("Export JSON for AI")
                }
            }
            .fileExporter(isPresented: $coordinator.isExporting, document: coordinator.report,
                          contentType: .json, defaultFilename: "FamilyTracker-AI-Diagnostics") { result in
                if case .failure(let error) = result { coordinator.errorMessage = error.localizedDescription }
            }
            .alert("Export failed", isPresented: Binding(
                get: { coordinator.errorMessage != nil },
                set: { if !$0 { coordinator.errorMessage = nil } }
            )) {
                Button("OK") { coordinator.errorMessage = nil }
            } message: { Text(coordinator.errorMessage ?? "") }
    }
}
#endif
