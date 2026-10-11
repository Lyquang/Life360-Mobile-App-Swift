// MARK: - GoogleSignInService.swift
// Wrapper mỏng quanh GoogleSignIn SDK.
// Tách biệt SDK khỏi Domain layer để dễ test và thay thế.

import UIKit
import GoogleSignIn

// MARK: - Protocol (cho phép mock trong unit test)

protocol GoogleSignInServiceProtocol: Sendable {
    /// Hiển thị Google Sign-In sheet và trả về Google ID Token (không phải access token).
    /// Backend dùng ID Token để verify với Google.
    func signIn(presentingViewController: UIViewController) async throws -> String
    /// Huỷ session Google phía client (không ảnh hưởng backend JWT).
    func signOut()
}

// MARK: - Implementation

final class GoogleSignInService: GoogleSignInServiceProtocol {

    // iOS Client ID — dùng để khởi tạo Google Sign-In flow trên thiết bị.
    // Backend dùng Web Client ID riêng (serverClientID) để verify token.
    static let iOSClientID  = "144558699513-j2tppssoktc7trltn5h5st64btu38cc1.apps.googleusercontent.com"
    static let webClientID  = "144558699513-4r1qsk1hqkrfo30eoqsnnrklr9mmg6ob.apps.googleusercontent.com"

    init() {
        // Cấu hình GIDSignIn với iOS Client ID và serverClientID (Web).
        // serverClientID khiến SDK embed đúng aud claim vào ID Token
        // để backend (dùng GOOGLE_CLIENT_ID = Web Client ID) verify được.
        let config = GIDConfiguration(
            clientID: Self.iOSClientID,
            serverClientID: Self.webClientID
        )
        GIDSignIn.sharedInstance.configuration = config
    }

    func signIn(presentingViewController: UIViewController) async throws -> String {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let idToken = result.user.idToken?.tokenString, !idToken.isEmpty else {
            throw DomainError.server("Không lấy được Google ID Token. Vui lòng thử lại.")
        }
        return idToken
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}
