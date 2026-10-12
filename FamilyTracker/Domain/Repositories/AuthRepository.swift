import Foundation

protocol AuthRepository {
    func login(email: String, password: String) async throws -> AuthSession
    func register(name: String, email: String, password: String) async throws -> AuthSession
    /// Xác thực bằng Google ID Token. Backend verify token với Google và trả về JWT của app.
    func socialLogin(idToken: String) async throws -> AuthSession
    func fetchCurrentUser() async throws -> User
    func logout(refreshToken: String) async throws
    func logoutAll() async throws
    func changePassword(currentPassword: String, newPassword: String) async throws
}

protocol SessionRepository: AnyObject {
    var accessToken: String? { get }
    var tokens: AuthTokens? { get }
    func save(_ session: AuthSession) throws
    func clear()
}
