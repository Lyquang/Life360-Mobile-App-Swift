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

struct ChatUnreadSummary: Equatable {
    let totalUnread: Int
    let counts: [String: Int]
}

enum ChatMessageType: String {
    case text
    case image
    case voice
}

struct ChatAttachment {
    let url: String
    let width: Int?
    let height: Int?
    let mimeType: String?
    let size: Int?
    let blurhash: String?
}

enum ChatSOSKind: String, Sendable {
    case alert, assistance, unknown
}

struct ChatSOSMetadata: Equatable, Sendable {
    let id: String
    let kind: ChatSOSKind
    let responderId: String?
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String?
    let type: ChatMessageType
    let content: String
    let attachment: ChatAttachment?
    let mediaUrl: String?
    let duration: Double?
    let fileSize: Int?
    let mimeType: String?
    let createdAt: Date
    let sos: ChatSOSMetadata?
    let eventID: String?

    init(id: String, conversationId: String, senderId: String, senderName: String?, type: ChatMessageType,
         content: String, attachment: ChatAttachment?, mediaUrl: String?, duration: Double?, fileSize: Int?,
         mimeType: String?, createdAt: Date, sos: ChatSOSMetadata? = nil, eventID: String? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.type = type
        self.content = content
        self.attachment = attachment
        self.mediaUrl = mediaUrl
        self.duration = duration
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.sos = sos
        self.eventID = eventID
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// Bounded FIFO deduplication; evicting one old ID does not clear the whole set.
struct RecentChatIDs {
    private let capacity: Int
    private var ids: Set<String> = []
    private var order: [String] = []

    init(capacity: Int = 500) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    mutating func insert(_ id: String) -> Bool {
        guard ids.insert(id).inserted else { return false }
        order.append(id)
        if order.count > capacity { ids.remove(order.removeFirst()) }
        return true
    }

    mutating func clear() {
        ids.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
    }
}

/// Event IDs are scoped to an authenticated generation, not retained across accounts.
struct RecentChatEvents {
    private var generation: Int?
    private var ids: RecentChatIDs

    init(capacity: Int = 500) { ids = RecentChatIDs(capacity: capacity) }

    mutating func accept(_ eventID: String?, generation current: Int) -> Bool {
        if generation != current {
            ids.clear()
            generation = current
        }
        guard let eventID, !eventID.isEmpty else { return true }
        return ids.insert(eventID)
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

struct VoiceAttachmentInput {
    let fileURL: URL
    let duration: Double
    let fileSize: Int
    let mimeType: String
}
