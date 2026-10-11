// MARK: - RegisterViewModel.swift

import Foundation
import UIKit
import GoogleSignIn

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let register: RegisterUseCase
    private let googleSignInUseCase: GoogleSignInUseCase
    private let onAuthenticated: (User) -> Void

    init(register: RegisterUseCase,
         googleSignIn: GoogleSignInUseCase,
         onAuthenticated: @escaping (User) -> Void) {
        self.register = register
        self.googleSignInUseCase = googleSignIn
        self.onAuthenticated = onAuthenticated
    }

    // MARK: - Email / Password Register

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

    // MARK: - Google Sign-In (cũng dùng social-login, tự động tạo tài khoản nếu chưa có)

    func signInWithGoogle() async {
        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            errorMessage = "Không thể mở Google Sign-In."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user = try await googleSignInUseCase(presentingViewController: rootVC)
            onAuthenticated(user)
        } catch let error as NSError where error.domain == "com.google.GIDSignIn" && error.code == -5 {
            // User tự tắt sheet Google → không hiện thông báo lỗi
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
            return "Không có kết nối mạng. Vui lòng kiểm tra lại."
        }
        if msg.contains("503") || msg.contains("service_unavailable") {
            return "Dịch vụ Google OAuth chưa được cấu hình. Vui lòng thử lại sau."
        }
        if msg.contains("401") || msg.contains("unauthorized") || msg.contains("invalid") {
            return "Token Google không hợp lệ hoặc đã hết hạn. Vui lòng thử lại."
        }
        return error.localizedDescription
    }
}
