import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var connectionState: RealtimeConnectionState

    let user: User
    let backendHost: String

    private let observeConnection: ObserveConnectionStateUseCase
    private let onLogout: () -> Void
    private var task: Task<Void, Never>?

    init(user: User, backendHost: String, observeConnection: ObserveConnectionStateUseCase, onLogout: @escaping () -> Void) {
        self.user = user
        self.backendHost = backendHost
        self.observeConnection = observeConnection
        self.onLogout = onLogout
        self.connectionState = observeConnection.current
    }

    deinit {
        task?.cancel()
    }

    var connectionLabel: String {
        switch connectionState {
        case .connected: return "Đã kết nối ✅"
        case .connecting: return "Đang kết nối…"
        case .disconnected: return "Chưa kết nối ❌"
        }
    }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    func start() {
        guard task == nil else { return }
        let stream = observeConnection()
        connectionState = observeConnection.current
        task = Task { [weak self] in
            for await state in stream { self?.connectionState = state }
        }
    }

    func logout() {
        onLogout()
    }
}
