import Foundation

/// REST for history/sending (reliable, returns the stored message) + Socket for live events.
final class ChatRepositoryImpl: ChatRepository {
    private let api: APIClient
    private let socket: SocketClient
    private let newMessages = AsyncBroadcaster<ChatMessage>()
    private let typing = AsyncBroadcaster<TypingEvent>()

    init(api: APIClient, socket: SocketClient) {
        self.api = api
        self.socket = socket

        socket.on(SocketEvent.chatNewMessage) { [weak self] payload in
            guard let dto = JSONPayload.decode(ChatMessageDTO.self, from: payload) else { return }
            self?.newMessages.send(dto.toDomain())
        }
        socket.on(SocketEvent.chatTyping) { [weak self] payload in
            guard let dto = JSONPayload.decode(TypingDTO.self, from: payload) else { return }
            self?.typing.send(dto.toDomain())
        }
    }

    func fetchConversations() async throws -> [Conversation] {
        try await withDomainErrors {
            let response = try await api.send(ChatEndpoint.conversations, as: APIResponseDTO<[ConversationDTO]>.self)
            guard response.success else { throw APIError.serverError(response.message ?? "Không thể tải hội thoại.") }
            return (response.data ?? []).map { $0.toDomain() }
        }
    }

    func fetchMessages(conversationId: String, before: String?) async throws -> MessagePage {
        try await withDomainErrors {
            let response = try await api.send(
                ChatEndpoint.messages(conversationId: conversationId, before: before), as: MessagePageDTO.self
            )
            guard response.success else { throw APIError.serverError(response.message ?? "Không thể tải tin nhắn.") }
            return MessagePage(
                messages: (response.data ?? []).map { $0.toDomain() },
                hasMore: response.hasMore ?? false,
                nextBefore: response.nextBefore
            )
        }
    }

    func sendText(_ text: String, conversationId: String) async throws -> ChatMessage {
        try await send(body: ["type": "text", "content": text], conversationId: conversationId)
    }

    func sendImage(attachmentUrl: String, caption: String?, image: ImageAttachmentInput, conversationId: String) async throws -> ChatMessage {
        var body: [String: Any] = [
            "type": "image",
            "attachmentUrl": attachmentUrl,
            "metadata": [
                "width": image.width,
                "height": image.height,
                "blurhash": image.blurhash,
                "mimeType": image.mimeType,
                "size": image.data.count
            ] as [String: Any]
        ]
        if let caption, !caption.isEmpty { body["content"] = caption }
        return try await send(body: body, conversationId: conversationId)
    }

    func markRead(conversationId: String, messageId: String?) async throws {
        try await withDomainErrors {
            _ = try await api.send(ChatEndpoint.markRead(conversationId: conversationId, messageId: messageId),
                                   as: APIResponseDTO<MarkReadDTO>.self)
        }
    }

    func openDirectConversation(userId: String) async throws -> Conversation {
        try await withDomainErrors {
            try await api.send(ChatEndpoint.openDirect(userId: userId), as: APIResponseDTO<ConversationDTO>.self)
                .unwrap(fallbackMessage: "Không thể mở cuộc trò chuyện.")
                .toDomain()
        }
    }

    func observeNewMessages() -> AsyncStream<ChatMessage> { newMessages.stream() }
    func observeTyping() -> AsyncStream<TypingEvent> { typing.stream() }

    func sendTyping(conversationId: String, isTyping: Bool) {
        guard socket.status == .connected else { return }
        socket.emit(SocketEvent.chatTyping, ["conversationId": conversationId, "isTyping": isTyping])
    }

    private func send(body: [String: Any], conversationId: String) async throws -> ChatMessage {
        try await withDomainErrors {
            try await api.send(ChatEndpoint.send(conversationId: conversationId, body: body), as: APIResponseDTO<ChatMessageDTO>.self)
                .unwrap(fallbackMessage: "Gửi tin nhắn thất bại.")
                .toDomain()
        }
    }
}

final class MediaRepositoryImpl: MediaRepository {
    private let api: APIClient
    private let uploader: ImageUploader
    private let processor: ImageProcessor

    init(api: APIClient, uploader: ImageUploader, processor: ImageProcessor = ImageProcessor()) {
        self.api = api
        self.uploader = uploader
        self.processor = processor
    }

    func prepareImage(_ data: Data) throws -> ImageAttachmentInput {
        let image = try processor.process(data)
        return ImageAttachmentInput(data: image.data, width: image.width, height: image.height,
                                    mimeType: image.mimeType, blurhash: image.blurhash)
    }

    func uploadChatImage(_ image: ImageAttachmentInput, conversationId: String) async throws -> String {
        let ticket = try await withDomainErrors {
            try await api.send(
                ChatEndpoint.uploadTicket(conversationId: conversationId, contentType: image.mimeType, contentLength: image.data.count),
                as: APIResponseDTO<UploadTicketDTO>.self
            ).unwrap(fallbackMessage: "Không thể tạo phiên tải ảnh.")
        }
        guard let url = URL(string: ticket.uploadUrl) else { throw DomainError.server("URL tải ảnh không hợp lệ.") }
        let target = UploadTarget(url: url, method: ticket.method ?? "PUT", headers: ticket.headers ?? [:])
        try await uploader.upload(image.data, to: target)
        return ticket.fileUrl
    }
}
