import Foundation

/// Named FamilyGroup (not Group/Circle) to avoid clashing with SwiftUI.Group and SwiftUI.Circle.
struct FamilyGroup: Identifiable, Equatable {
    let id: String
    let name: String
    var inviteCode: String? = nil
    var admin: User? = nil
    var members: [User]? = nil
    var conversationId: String? = nil
    var createdAt: String? = nil
    var updatedAt: String? = nil

    var memberCount: Int { members?.count ?? 0 }

    var onlineMembersCount: Int {
        members?.filter { $0.isOnline == true }.count ?? 0
    }

    static func == (lhs: FamilyGroup, rhs: FamilyGroup) -> Bool {
        lhs.id == rhs.id
    }
}
