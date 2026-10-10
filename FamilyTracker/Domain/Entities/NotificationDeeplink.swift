import Foundation

/// Where a tapped notification should take the user.
enum NotificationDeeplink: Equatable {
    case sos(userId: String)
    case member(userId: String)
    case conversation(id: String)

    init?(userInfo: [AnyHashable: Any]) {
        guard let kind = userInfo["kind"] as? String, let id = userInfo["id"] as? String,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        switch kind {
        case "sos": self = .sos(userId: id)
        case "member": self = .member(userId: id)
        case "conversation": self = .conversation(id: id)
        default: return nil
        }
    }

    var userInfo: [String: String] {
        switch self {
        case .sos(let id): return ["kind": "sos", "id": id]
        case .member(let id): return ["kind": "member", "id": id]
        case .conversation(let id): return ["kind": "conversation", "id": id]
        }
    }

    var kind: NotificationKind {
        switch self {
        case .sos: return .sos
        case .member: return .member
        case .conversation: return .conversation
        }
    }
}
