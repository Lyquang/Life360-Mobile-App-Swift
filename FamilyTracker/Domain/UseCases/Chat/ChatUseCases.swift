import Foundation

struct FetchConversationsUseCase {
    let repository: ChatRepository
    func callAsFunction() async throws -> [Conversation] { try await repository.fetchConversations() }
}

struct FetchMessagesUseCase {
    let repository: ChatRepository

    func callAsFunction(conversationId: String, before: String? = nil) async throws -> MessagePage {
        try await repository.fetchMessages(conversationId: conversationId, before: before)
    }
}

struct SendTextMessageUseCase {
    let repository: ChatRepository

    func callAsFunction(_ text: String, conversationId: String) async throws -> ChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.validation("Tin nhắn trống.") }
        return try await repository.sendText(trimmed, conversationId: conversationId)
    }
}

struct PrepareImageUseCase {
    let media: MediaRepository
    func callAsFunction(_ data: Data) async throws -> ImageAttachmentInput { try await media.prepareImage(data) }
}

struct UploadImageUseCase {
    let media: MediaRepository
    func callAsFunction(_ image: ImageAttachmentInput, conversationId: String,
                        progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        try await media.uploadChatImage(image, conversationId: conversationId, progress: progress)
    }
}

struct SendImageMessageUseCase {
    let chat: ChatRepository

    func callAsFunction(image: ImageAttachmentInput, publicURL: String, caption: String?,
                        conversationId: String) async throws -> ChatMessage {
        try await chat.sendImage(attachmentUrl: publicURL, caption: caption, image: image,
                                 conversationId: conversationId)
    }
}

struct UploadVoiceUseCase {
    let media: MediaRepository
    func callAsFunction(_ voice: VoiceAttachmentInput, conversationId: String,
                        progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        try await media.uploadVoice(voice, conversationId: conversationId, progress: progress)
    }
}

struct SendVoiceMessageUseCase {
    let chat: ChatRepository
    func callAsFunction(voice: VoiceAttachmentInput, publicURL: String,
                        conversationId: String) async throws -> ChatMessage {
        try await chat.sendVoice(mediaUrl: publicURL, voice: voice, conversationId: conversationId)
    }
}

struct MarkConversationReadUseCase {
    let repository: ChatRepository

    func callAsFunction(conversationId: String, messageId: String? = nil) async {
        try? await repository.markRead(conversationId: conversationId, messageId: messageId)
    }
}

struct OpenDirectChatUseCase {
    let repository: ChatRepository
    func callAsFunction(userId: String) async throws -> Conversation {
        try await repository.openDirectConversation(userId: userId)
    }
}

struct ObserveNewMessagesUseCase {
    let repository: ChatRepository
    func callAsFunction() -> AsyncStream<ChatMessage> { repository.observeNewMessages() }
}

struct ObserveTypingUseCase {
    let repository: ChatRepository
    func callAsFunction() -> AsyncStream<TypingEvent> { repository.observeTyping() }
}

struct SendTypingUseCase {
    let repository: ChatRepository
    func callAsFunction(conversationId: String, isTyping: Bool) {
        repository.sendTyping(conversationId: conversationId, isTyping: isTyping)
    }
}
