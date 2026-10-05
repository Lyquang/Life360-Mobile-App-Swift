import SwiftUI

@MainActor
final class AuthCoordinator: ObservableObject {
    @Published var isShowingRegister = false

    let loginViewModel: LoginViewModel
    let registerViewModel: RegisterViewModel

    init(container: AppContainer, onAuthenticated: @escaping (User) -> Void) {
        loginViewModel = LoginViewModel(login: container.login, onAuthenticated: onAuthenticated)
        registerViewModel = RegisterViewModel(register: container.register, onAuthenticated: onAuthenticated)
    }

    func showRegister() {
        registerViewModel.clearError()
        isShowingRegister = true
    }
}

struct AuthCoordinatorView: View {
    @ObservedObject var coordinator: AuthCoordinator

    var body: some View {
        LoginView(viewModel: coordinator.loginViewModel, onRegister: coordinator.showRegister)
            .sheet(isPresented: $coordinator.isShowingRegister) {
                RegisterView(viewModel: coordinator.registerViewModel)
            }
    }
}
