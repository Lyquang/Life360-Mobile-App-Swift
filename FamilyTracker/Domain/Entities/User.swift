import Foundation

struct User: Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
    var avatar: String? = nil
    var batteryLevel: Int? = nil
    var isOnline: Bool? = nil
    var createdAt: String? = nil
    var updatedAt: String? = nil

    var initials: String { name.initials }

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

struct AuthSession {
    let user: User
    let token: String
}
