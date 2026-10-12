import Foundation

struct ConversationMemberDTO: Codable, Sendable {
    let id: String
    let name: String
    let avatar: String?
    let isOnline: Bool?
    let lastSeenAt: String?
}

struct ChatAttachmentDTO: Codable, Sendable {
    let url: String
    let mimeType: String?
    let width: Int?
    let height: Int?
    let size: Int?
    let blurhash: String?
}

struct ChatMessageDTO: Codable, Sendable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String?
    let type: String
    let content: String?
    let attachment: ChatAttachmentDTO?
    let mediaUrl: String?
    let duration: Double?
    let fileSize: Int?
    let mimeType: String?
    let createdAt: Date
}

struct ConversationDTO: Codable, Sendable {
    let id: String
    let type: String
    let groupId: String?
    let name: String?
    let avatarUrl: String?
    let members: [ConversationMemberDTO]?
    let lastMessage: ChatMessageDTO?
    let lastMessageAt: String?
    let unreadCount: Int?
    let lastReadMessageId: String?
    let createdAt: String?
    let updatedAt: String?
}

struct MessagePageDTO: Codable, Sendable {
    let success: Bool
    let count: Int?
    let hasMore: Bool?
    let nextBefore: String?
    let data: [ChatMessageDTO]?
    let message: String?
}

struct MarkReadDTO: Codable, Sendable {
    let conversationId: String
    let unreadCount: Int?
    let lastReadMessageId: String?
    let advanced: Bool?
}

struct UploadTicketDTO: Codable, Sendable {
    let uploadUrl: String
    let method: String?
    let headers: [String: String]?
    let fileUrl: String
    let key: String?
    let expiresIn: Int?
    let expiresAt: String?
}

struct PresignedMediaTicketDTO: Codable, Sendable {
    let uploadUrl: URL
    let method: String
    let headers: [String: String]
    let key: String
    let publicUrl: URL
    let expiresIn: Int
    let expiresAt: Date

    func toDomain() -> MediaUploadTicket {
        MediaUploadTicket(uploadURL: uploadUrl, method: method, headers: headers,
                          key: key, publicURL: publicUrl, expiresIn: expiresIn,
                          expiresAt: expiresAt)
    }
}

struct ConversationUnreadDTO: Codable, Sendable {
    let conversationId: String
    let unreadCount: Int
    let lastReadMessageId: String?
}

struct UnreadSummaryDTO: Codable, Sendable {
    let totalUnread: Int
    let conversations: [ConversationUnreadDTO]
}
