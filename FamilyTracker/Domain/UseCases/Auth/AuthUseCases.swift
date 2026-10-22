import Foundation
import UIKit

struct LoginUseCase {
    let auth: AuthRepository
    let session: SessionRepository
    let realtime: RealtimeSessionRepository

    func callAsFunction(email: String, password: String) async throws -> User {
        guard !email.isEmpty, !password.isEmpty else {
            throw DomainError.validation("Vui lòng nhập email và mật khẩu.")
        }
        let result = try await auth.login(
            email: email.lowercased().trimmingCharacters(in: .whitespaces),
            password: password
        )
        do { try session.save(result) }
        catch { session.clear(); throw error }
        realtime.connect(token: result.tokens.accessToken)
        return result.user
    }
}

struct RegisterUseCase {
    let auth: AuthRepository
    let session: SessionRepository
    let realtime: RealtimeSessionRepository

    func callAsFunction(name: String, email: String, password: String, confirmPassword: String) async throws -> User {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else { throw DomainError.validation("Vui lòng nhập tên của bạn.") }
        guard Self.isValidEmail(normalizedEmail) else { throw DomainError.validation("Email không hợp lệ.") }
        guard password.count >= 6 else { throw DomainError.validation("Mật khẩu phải có ít nhất 6 ký tự.") }
        guard password == confirmPassword else { throw DomainError.validation("Mật khẩu xác nhận không khớp.") }

        let result = try await auth.register(name: trimmedName, email: normalizedEmail, password: password)
        do { try session.save(result) }
        catch { session.clear(); throw error }
        realtime.connect(token: result.tokens.accessToken)
        return result.user
    }

    static func isValidEmail(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }
}

// MARK: - Google Sign-In UseCase

/// Điều phối toàn bộ luồng Google Sign-In:
/// 1. Lấy Google ID Token qua SDK
/// 2. Gửi lên backend /auth/social-login
/// 3. Lưu JWT vào Keychain và kết nối Socket
struct GoogleSignInUseCase {
    let googleSignIn: GoogleSignInServiceProtocol
    let auth: AuthRepository
    let session: SessionRepository
    let realtime: RealtimeSessionRepository
// mainActor này đảm bảo rằng tất cả các thao tác liên quan đến UI và session đều được thực hiện trên main thread.
    @MainActor
    func callAsFunction(presentingViewController: UIViewController) async throws -> User {
        // 1. Lấy Google ID Token từ SDK
        let idToken = try await googleSignIn.signIn(presentingViewController: presentingViewController)
        // 2. Gửi ID Token lên backend → nhận AuthSession (JWT + user)
        let result = try await auth.socialLogin(idToken: idToken)
        // 3. Lưu token an toàn vào Keychain và kết nối realtime
        do { try session.save(result) }
        catch { session.clear(); throw error }
        realtime.connect(token: result.tokens.accessToken)
        return result.user
    }
}

/// Restores the previous session from the stored token. Returns nil when the user must log in again.
struct RestoreSessionUseCase {
    let auth: AuthRepository
    let session: SessionRepository
    let realtime: RealtimeSessionRepository

    func callAsFunction() async -> User? {
        guard let token = session.accessToken else { return nil }
        do {
            let user = try await auth.fetchCurrentUser()
            realtime.connect(token: token)
            return user
        } catch DomainError.unauthorized {
            session.clear()
            return nil
        } catch {
            return nil
        }
    }
}

@MainActor
struct LogoutUseCase {
    let auth: AuthRepository
    let session: SessionRepository
    let realtime: RealtimeSessionRepository
    let shareLocation: ShareLocationUseCase

    func callAsFunction(allDevices: Bool = false) async -> Bool {
        defer {
            shareLocation.stop()
            realtime.disconnect()
            session.clear()
        }
        do {
            if allDevices { try await auth.logoutAll() }
            else if let refreshToken = session.tokens?.refreshToken {
                try await auth.logout(refreshToken: refreshToken)
            } else {
                return false
            }
            return true
        } catch {
            return false
        }
    }
}

@MainActor
struct ChangePasswordUseCase {
    let auth: AuthRepository
    let session: SessionRepository
    let realtime: RealtimeSessionRepository
    let shareLocation: ShareLocationUseCase

    func callAsFunction(current: String, new: String) async throws {
        try await auth.changePassword(currentPassword: current, newPassword: new)
        shareLocation.stop()
        realtime.disconnect()
        session.clear()
    }
}
