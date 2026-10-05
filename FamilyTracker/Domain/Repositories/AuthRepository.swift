import Foundation

protocol AuthRepository {
    func login(email: String, password: String) async throws -> AuthSession
    func register(name: String, email: String, password: String) async throws -> AuthSession
    func fetchCurrentUser() async throws -> User
}

protocol SessionRepository: AnyObject {
    var accessToken: String? { get }
    func save(_ session: AuthSession)
    func clear()
}
