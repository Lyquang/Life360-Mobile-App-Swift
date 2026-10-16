import Foundation

protocol ChatRepository: AnyObject {
    func fetchConversations() async throws -> [Conversation]
    func fetchUnreadSummary() async throws -> ChatUnreadSummary
    func fetchMessages(conversationId: String, before: String?) async throws -> MessagePage
    func sendText(_ text: String, conversationId: String) async throws -> ChatMessage
    func sendImage(attachmentUrl: String, caption: String?, image: ImageAttachmentInput, conversationId: String) async throws -> ChatMessage
    func sendVoice(mediaUrl: String, voice: VoiceAttachmentInput, conversationId: String) async throws -> ChatMessage
    func markRead(conversationId: String, messageId: String?) async throws
    func openDirectConversation(userId: String) async throws -> Conversation
    func observeNewMessages() -> AsyncStream<ChatMessage>
    func observeConversationUpdates() -> AsyncStream<String>
    func observeTyping() -> AsyncStream<TypingEvent>
    func sendTyping(conversationId: String, isTyping: Bool)
}

protocol MediaRepository {
    /// Resizes, compresses and computes blurhash for raw image bytes picked by the user.
    func prepareImage(_ data: Data) async throws -> ImageAttachmentInput
    /// Returns the public file URL to attach to a chat message.
    func uploadChatImage(_ image: ImageAttachmentInput, conversationId: String,
                         progress: @escaping @Sendable (Double) -> Void) async throws -> String
    func uploadVoice(_ voice: VoiceAttachmentInput, conversationId: String,
                     progress: @escaping @Sendable (Double) -> Void) async throws -> String
}
