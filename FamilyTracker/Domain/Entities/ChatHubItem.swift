import Foundation

struct ChatHubItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case group
        case direct
    }

    let id: String
    let kind: Kind
    let conversationId: String?
    let groupId: String?
    let inviteCode: String?
    let title: String
    let lastMessage: ChatMessage?
    let lastMessageAt: Date?
    let createdAt: Date?
    let unreadCount: Int
    let memberCount: Int?
    let onlineCount: Int?
    let isOnline: Bool?

    var activityDate: Date? { lastMessageAt ?? createdAt }
}

struct ChatHubPerson: Identifiable, Equatable {
    let id: String
    let name: String
    let isOnline: Bool?
}

struct ChatHubSnapshot {
    let items: [ChatHubItem]
    let people: [ChatHubPerson]
    let unmatchedGroupConversationIDs: [String]
}

enum ChatHubFilter: Hashable {
    case all
    case groups
    case direct
}

struct ChatHubSearchResult {
    let conversations: [ChatHubItem]
    let people: [ChatHubPerson]
}
