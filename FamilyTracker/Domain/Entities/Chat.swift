import Foundation

enum ConversationType: String {
    case group
    case direct
}

struct ConversationMember: Identifiable {
    let id: String
    let name: String
    let avatar: String?
    let isOnline: Bool
}

struct Conversation: Identifiable {
    let id: String
    let type: ConversationType
    let groupId: String?
    let name: String?
    let avatarUrl: String?
    let members: [ConversationMember]
    var lastMessage: ChatMessage?
    var lastMessageAt: Date?
    var unreadCount: Int

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return members.map(\.name).joined(separator: ", ")
    }
}

enum ChatMessageType: String {
    case text
    case image
}

struct ChatAttachment {
    let url: String
    let width: Int?
    let height: Int?
    let mimeType: String?
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String?
    let type: ChatMessageType
    let content: String
    let attachment: ChatAttachment?
    let createdAt: Date

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct MessagePage {
    let messages: [ChatMessage]
    let hasMore: Bool
    let nextBefore: String?
}

struct TypingEvent {
    let conversationId: String
    let userId: String
    let name: String?
    let isTyping: Bool
}

/// Image ready to upload: already compressed, with metadata required by the backend.
struct ImageAttachmentInput {
    let data: Data
    let width: Int
    let height: Int
    let mimeType: String
    let blurhash: String
}
