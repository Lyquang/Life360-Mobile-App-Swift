import SwiftUI

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

    init(container: AppContainer) {
        self.container = container
    }

    func start() async {
        guard state == .launching else { return }
        if let user = await container.restoreSession() {
            showMain(for: user)
        } else {
            showAuth()
        }
    }

    func logout() {
        mainCoordinator?.stop()
        container.logout()
        showAuth()
    }

    private func showAuth() {
        mainCoordinator = nil
        authCoordinator = AuthCoordinator(container: container) { [weak self] user in
            self?.showMain(for: user)
        }
        state = .unauthenticated
    }

    private func showMain(for user: User) {
        authCoordinator = nil
        let main = MainTabCoordinator(container: container, currentUser: user) { [weak self] in
            self?.logout()
        }
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
