import Foundation

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let register: RegisterUseCase
    private let onAuthenticated: (User) -> Void

    init(register: RegisterUseCase, onAuthenticated: @escaping (User) -> Void) {
        self.register = register
        self.onAuthenticated = onAuthenticated
    }

    func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await register(name: name, email: email, password: password, confirmPassword: confirmPassword)
            onAuthenticated(user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
