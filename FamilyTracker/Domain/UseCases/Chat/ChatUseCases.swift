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

/// Upload ticket → PUT bytes to storage → send image message (backend contract).
struct SendImageMessageUseCase {
    let chat: ChatRepository
    let media: MediaRepository

    func callAsFunction(imageData: Data, caption: String?, conversationId: String) async throws -> ChatMessage {
        let image = try media.prepareImage(imageData)
        let fileUrl = try await media.uploadChatImage(image, conversationId: conversationId)
        return try await chat.sendImage(attachmentUrl: fileUrl, caption: caption, image: image, conversationId: conversationId)
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
