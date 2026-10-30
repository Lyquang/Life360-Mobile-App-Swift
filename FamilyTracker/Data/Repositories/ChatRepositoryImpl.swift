import Foundation

/// REST for history/sending (reliable, returns the stored message) + Socket for live events.
final class ChatRepositoryImpl: ChatRepository {
    private let api: APIClient
    private let socket: SocketClient
    private let newMessages = AsyncBroadcaster<ChatMessage>()
    private let conversationUpdates = AsyncBroadcaster<String>()
    private let typing = AsyncBroadcaster<TypingEvent>()
    private let sessionGeneration: () -> Int
    private let eventLock = NSLock()
    private var recentEvents = RecentChatEvents()

    init(api: APIClient, socket: SocketClient, sessionGeneration: @escaping () -> Int = { 0 }) {
        self.api = api
        self.socket = socket
        self.sessionGeneration = sessionGeneration

        socket.on(SocketEvent.chatNewMessage) { [weak self] payload in
            guard let self, let dto = JSONPayload.decode(ChatMessageDTO.self, from: payload),
                  self.acceptEvent(dto.eventId) else { return }
            self.newMessages.send(dto.toDomain())
        }
        socket.on(SocketEvent.chatTyping) { [weak self] payload in
            guard let dto = JSONPayload.decode(TypingDTO.self, from: payload) else { return }
            self?.typing.send(dto.toDomain())
        }
        socket.on(SocketEvent.chatConversationUpdated) { [weak self] payload in
            guard let update = JSONPayload.decode(ConversationUpdateEvent.self, from: payload) else { return }
            self?.conversationUpdates.send(update.conversationId)
        }
    }

    func fetchConversations() async throws -> [Conversation] {
        try await withDomainErrors {
            let response = try await api.send(ChatEndpoint.conversations, as: APIResponseDTO<[ConversationDTO]>.self)
            guard response.success else { throw APIError.serverError(response.message ?? "Không thể tải hội thoại.") }
            return (response.data ?? []).map { $0.toDomain() }
        }
    }

    func fetchUnreadSummary() async throws -> ChatUnreadSummary {
        try await withDomainErrors {
            let summary = try await api.send(
                ChatEndpoint.unreadSummary, as: APIResponseDTO<UnreadSummaryDTO>.self
            ).unwrap(fallbackMessage: "Không thể tải số tin chưa đọc.")
            return ChatUnreadSummary(
                totalUnread: summary.totalUnread,
                counts: Dictionary(summary.conversations.map { ($0.conversationId, $0.unreadCount) },
                                   uniquingKeysWith: { _, latest in latest })
            )
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
        body["conversationId"] = conversationId
        return try await sendWithAcknowledgement(body)
    }

    func sendVoice(mediaUrl: String, voice: VoiceAttachmentInput, conversationId: String) async throws -> ChatMessage {
        try await sendWithAcknowledgement([
            "conversationId": conversationId,
            "type": "voice",
            "mediaUrl": mediaUrl,
            "duration": voice.duration,
            "fileSize": voice.fileSize,
            "mimeType": voice.mimeType
        ])
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
    func observeConversationUpdates() -> AsyncStream<String> { conversationUpdates.stream() }
    func observeTyping() -> AsyncStream<TypingEvent> { typing.stream() }

    private func acceptEvent(_ eventID: String?) -> Bool {
        eventLock.lock(); defer { eventLock.unlock() }
        return recentEvents.accept(eventID, generation: sessionGeneration())
    }

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

    private func sendWithAcknowledgement(_ payload: [String: Any]) async throws -> ChatMessage {
        do {
            let raw = try await socket.emitWithAck(SocketEvent.chatSendMessage, payload, timeout: 10)
            guard let ack = JSONPayload.decode(SocketAcknowledgementDTO<ChatMessageDTO>.self, from: raw) else {
                throw SocketClientError.invalidAcknowledgement
            }
            guard ack.success, let message = ack.data else {
                if ack.status == 403 { throw MediaUploadError.forbidden }
                throw MediaUploadError.socketRejected(message: ack.message ?? "Gửi tin nhắn thất bại.")
            }
            return message.toDomain()
        } catch SocketClientError.acknowledgementTimeout {
            throw MediaUploadError.acknowledgementTimeout
        } catch SocketClientError.disconnected {
            throw MediaUploadError.acknowledgementTimeout
        }
    }
}

private struct ConversationUpdateEvent: Decodable {
    let conversationId: String
}

final class MediaRepositoryImpl: MediaRepository {
    private let uploader: MediaUploadService
    private let processor: ImageProcessor

    init(uploader: MediaUploadService, processor: ImageProcessor = ImageProcessor()) {
        self.uploader = uploader
        self.processor = processor
    }

    func prepareImage(_ data: Data) async throws -> ImageAttachmentInput {
        let processor = self.processor
        let image = try await Task.detached(priority: .userInitiated) {
            try processor.process(data)
        }.value
        return ImageAttachmentInput(data: image.data, width: image.width, height: image.height,
                                    mimeType: image.mimeType, blurhash: image.blurhash)
    }

    func uploadChatImage(_ image: ImageAttachmentInput, conversationId: String,
                         progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        let ticket = try await uploader.uploadWithFreshTicket(image.data, conversationId: conversationId,
                                                              kind: .image, progress: progress)
        return ticket.publicURL.absoluteString
    }

    func uploadVoice(_ voice: VoiceAttachmentInput, conversationId: String,
                     progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        let data = try Data(contentsOf: voice.fileURL, options: .mappedIfSafe)
        guard data.count == voice.fileSize else {
            throw MediaUploadError.fileSizeMismatch(expected: voice.fileSize, actual: data.count)
        }
        let ticket = try await uploader.uploadWithFreshTicket(data, conversationId: conversationId,
                                                              kind: .voice, progress: progress)
        return ticket.publicURL.absoluteString
    }
}
