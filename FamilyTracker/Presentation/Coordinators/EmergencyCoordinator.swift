import SwiftUI

/// App-wide SOS flow: incoming alerts appear over any tab; sending is confirmed from any screen.
@MainActor
final class EmergencyCoordinator: ObservableObject {
    @Published var incomingAlert: SOSAlert?
    @Published var isConfirmingSOS = false
    @Published private(set) var isSending = false

    var onShowLocation: ((SOSAlert) -> Void)?

    private let observeSOS: ObserveSOSAlertsUseCase
    private let sendSOS: SendSOSUseCase
    private var observeTask: Task<Void, Never>?
    private var autoDismissTask: Task<Void, Never>?

    init(observeSOS: ObserveSOSAlertsUseCase, sendSOS: SendSOSUseCase) {
        self.observeSOS = observeSOS
        self.sendSOS = sendSOS
    }

    func start() {
        guard observeTask == nil else { return }
        let stream = observeSOS()
        observeTask = Task { [weak self] in
            for await alert in stream { self?.present(alert) }
        }
    }

    func stop() {
        observeTask?.cancel()
        autoDismissTask?.cancel()
        observeTask = nil
    }

    func requestSOS() {
        isConfirmingSOS = true
    }

    func confirmSOS() {
        isSending = true
        sendSOS()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.isSending = false
        }
    }

    func dismissAlert() {
        incomingAlert = nil
    }

    func showAlertLocation() {
        guard let alert = incomingAlert else { return }
        onShowLocation?(alert)
    }

    private func present(_ alert: SOSAlert) {
        incomingAlert = alert
        autoDismissTask?.cancel()
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled, self?.incomingAlert?.id == alert.id else { return }
            self?.incomingAlert = nil
        }
    }
}

struct EmergencyPresentation: ViewModifier {
    @ObservedObject var coordinator: EmergencyCoordinator

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let alert = coordinator.incomingAlert {
                    SOSAlertBanner(
                        alert: alert,
                        onDismiss: coordinator.dismissAlert,
                        onNavigate: coordinator.showAlertLocation
                    )
                    .padding(.top, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: coordinator.incomingAlert?.id)
            .confirmationDialog(
                "Gửi SOS Khẩn Cấp?",
                isPresented: $coordinator.isConfirmingSOS,
                titleVisibility: .visible
            ) {
                Button("Gửi SOS ngay", role: .destructive) { coordinator.confirmSOS() }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Tất cả thành viên trong nhóm sẽ nhận được cảnh báo khẩn cấp từ bạn.")
            }
    }
}
