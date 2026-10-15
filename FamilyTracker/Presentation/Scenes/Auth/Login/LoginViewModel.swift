// MARK: - LoginViewModel.swift

import Foundation
import UIKit
import GoogleSignIn

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let login: LoginUseCase
    private let googleSignInUseCase: GoogleSignInUseCase
    private let onAuthenticated: (User) -> Void

    init(login: LoginUseCase,
         googleSignIn: GoogleSignInUseCase,
         onAuthenticated: @escaping (User) -> Void) {
        self.login = login
        self.googleSignInUseCase = googleSignIn
        self.onAuthenticated = onAuthenticated
    }

    // MARK: - Email / Password Login

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

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        // Tìm presenting ViewController từ key window
        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            errorMessage = L10n.tr("auth.error.google_unavailable")
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user = try await googleSignInUseCase(presentingViewController: rootVC)
            onAuthenticated(user)
        } catch let error as NSError where error.domain == "com.google.GIDSignIn" && error.code == -5 {
            // GIDSignInErrorCode.canceled (-5) — user tự tắt sheet, không hiện lỗi
            return
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Helpers

    func clearError() {
        errorMessage = nil
    }

    private func friendlyError(_ error: Error) -> String {
        if let domainErr = error as? DomainError {
            return domainErr.localizedDescription
        }
        let msg = error.localizedDescription.lowercased()
        if msg.contains("network") || msg.contains("mạng") || msg.contains("internet") {
            return L10n.tr("error.network_unavailable")
        }
        if msg.contains("503") || msg.contains("service_unavailable") {
            return L10n.tr("auth.error.google_not_configured")
        }
        if msg.contains("401") || msg.contains("unauthorized") || msg.contains("invalid") {
            return L10n.tr("auth.error.google_token_invalid")
        }
        return L10n.tr("auth.error.google_failed")
    }
}
