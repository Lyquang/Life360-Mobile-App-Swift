import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let login: LoginUseCase
    private let onAuthenticated: (User) -> Void

    init(login: LoginUseCase, onAuthenticated: @escaping (User) -> Void) {
        self.login = login
        self.onAuthenticated = onAuthenticated
    }

    func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await login(email: email, password: password)
            onAuthenticated(user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
