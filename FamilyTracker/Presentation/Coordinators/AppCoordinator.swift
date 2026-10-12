import SwiftUI
import Combine

/// Root flow: launch → (Auth | Main). Owns the session lifecycle.
@MainActor
final class AppCoordinator: ObservableObject {
    enum State: Equatable {
        case launching
        case unauthenticated
        case authenticated
    }

    @Published private(set) var state: State = .launching
    private(set) var authCoordinator: AuthCoordinator?
    private(set) var mainCoordinator: MainTabCoordinator?

    private let container: AppContainer
    private var cancellables = Set<AnyCancellable>()
    private var expiredWhileLaunching = false

    init(container: AppContainer) {
        self.container = container
        container.sessionEvents.publisher
            .sink { [weak self] in self?.sessionExpired() }
            .store(in: &cancellables)
    }

    func start() async {
        guard state == .launching else { return }
        if let user = await container.restoreSession() {
            showMain(for: user)
        } else {
            showAuth()
            if expiredWhileLaunching {
                authCoordinator?.loginViewModel.errorMessage = L10n.text(
                    "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
                )
                expiredWhileLaunching = false
            }
        }
    }

    func logout(allDevices: Bool = false) {
        mainCoordinator?.stop()
        Task { [weak self] in
            guard let self else { return }
            let revoked = await self.container.logout(allDevices: allDevices)
            self.showAuth()
            if !revoked {
                self.authCoordinator?.loginViewModel.errorMessage = L10n.text(
                    "Đã đăng xuất trên thiết bị này, nhưng chưa thể xác nhận trên máy chủ."
                )
            }
        }
    }

    private func sessionExpired() {
        if state == .launching {
            expiredWhileLaunching = true
            return
        }
        guard state == .authenticated else { return }
        mainCoordinator?.stop()
        container.shareLocation.stop()
        showAuth()
        authCoordinator?.loginViewModel.errorMessage = L10n.text("Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.")
    }

    private func showAuth() {
        mainCoordinator = nil
        authCoordinator = AuthCoordinator(container: container) { [weak self] user in
            self?.showMain(for: user)
        }
        state = .unauthenticated
    }

    private func showMain(for user: User) {
        container.sessionEvents.reset()
        authCoordinator = nil
        let main = MainTabCoordinator(container: container, currentUser: user,
                                      onLogout: { [weak self] in self?.logout() },
                                      onLogoutAll: { [weak self] in self?.logout(allDevices: true) })
        mainCoordinator = main
        main.start()
        state = .authenticated
    }
}

struct AppCoordinatorView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            switch coordinator.state {
            case .launching:
                SplashView()
            case .unauthenticated:
                if let auth = coordinator.authCoordinator {
                    AuthCoordinatorView(coordinator: auth)
                        .transition(.opacity)
                }
            case .authenticated:
                if let main = coordinator.mainCoordinator {
                    MainTabView(coordinator: main)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.state)
        .task { await coordinator.start() }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            FTColors.primaryGradient.ignoresSafeArea()
            VStack(spacing: FTSpacing.md) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
}
