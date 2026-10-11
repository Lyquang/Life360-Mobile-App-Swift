// MARK: - AuthCoordinator.swift
// Điều phối luồng Auth: Login ↔ Register, cả hai đều có nút Google Sign-In.

import SwiftUI

@MainActor
final class AuthCoordinator: ObservableObject {
    @Published var isShowingRegister = false

    let loginViewModel: LoginViewModel
    let registerViewModel: RegisterViewModel

    init(container: AppContainer, onAuthenticated: @escaping (User) -> Void) {
        // Tạo 1 lần, share cùng googleSignIn usecase instance
        let googleSignIn = container.googleSignIn

        loginViewModel = LoginViewModel(
            login: container.login,
            googleSignIn: googleSignIn,
            onAuthenticated: onAuthenticated
        )
        registerViewModel = RegisterViewModel(
            register: container.register,
            googleSignIn: googleSignIn,
            onAuthenticated: onAuthenticated
        )
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
