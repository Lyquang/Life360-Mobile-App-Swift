import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var typingNames: [String] = []
    @Published var draft = ""
    @Published var errorMessage: String?

    let conversationId: String
    let title: String
    let currentUserId: String

    private let fetchMessages: FetchMessagesUseCase
    private let sendText: SendTextMessageUseCase
    private let sendImage: SendImageMessageUseCase
    private let markRead: MarkConversationReadUseCase
    private let observeNewMessages: ObserveNewMessagesUseCase
    private let observeTyping: ObserveTypingUseCase
    private let sendTyping: SendTypingUseCase

    private var nextBefore: String?
    private var tasks: [Task<Void, Never>] = []
    private var typingResetTask: Task<Void, Never>?
    private var isTypingSent = false
    private var typers: [String: String] = [:]

    init(
        conversationId: String,
        title: String,
        currentUserId: String,
        fetchMessages: FetchMessagesUseCase,
        sendText: SendTextMessageUseCase,
        sendImage: SendImageMessageUseCase,
        markRead: MarkConversationReadUseCase,
        observeNewMessages: ObserveNewMessagesUseCase,
        observeTyping: ObserveTypingUseCase,
        sendTyping: SendTypingUseCase
    ) {
        self.conversationId = conversationId
        self.title = title
        self.currentUserId = currentUserId
        self.fetchMessages = fetchMessages
        self.sendText = sendText
        self.sendImage = sendImage
        self.markRead = markRead
        self.observeNewMessages = observeNewMessages
        self.observeTyping = observeTyping
        self.sendTyping = sendTyping
    }

    deinit {
        tasks.forEach { $0.cancel() }
        typingResetTask?.cancel()
    }

    func isMine(_ message: ChatMessage) -> Bool { message.senderId == currentUserId }

    func start() async {
        if tasks.isEmpty {
            let messageStream = observeNewMessages()
            let typingStream = observeTyping()
            tasks.append(Task { [weak self] in
                for await message in messageStream { self?.receive(message) }
            })
            tasks.append(Task { [weak self] in
                for await event in typingStream { self?.receive(event) }
            })
        }
        await loadInitial()
    }

    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await fetchMessages(conversationId: conversationId)
            messages = page.messages
            hasMore = page.hasMore
            nextBefore = page.nextBefore
            await markRead(conversationId: conversationId, messageId: messages.last?.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadOlder() async {
        guard hasMore, !isLoading, let before = nextBefore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await fetchMessages(conversationId: conversationId, before: before)
            let known = Set(messages.map(\.id))
            messages.insert(contentsOf: page.messages.filter { !known.contains($0.id) }, at: 0)
            hasMore = page.hasMore
            nextBefore = page.nextBefore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send() async {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSending else { return }
        isSending = true
        draft = ""
        stopTyping()
        defer { isSending = false }
        do {
            append(try await sendText(text, conversationId: conversationId))
        } catch {
            draft = text
            errorMessage = error.localizedDescription
        }
    }

    func sendPhoto(_ data: Data) async {
        isSending = true
        defer { isSending = false }
        do {
            append(try await sendImage(imageData: data, caption: nil, conversationId: conversationId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func draftChanged() {
        guard !draft.isEmpty else { stopTyping(); return }
        if !isTypingSent {
            isTypingSent = true
            sendTyping(conversationId: conversationId, isTyping: true)
        }
        typingResetTask?.cancel()
        typingResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.stopTyping()
        }
    }

    func stopTyping() {
        typingResetTask?.cancel()
        guard isTypingSent else { return }
        isTypingSent = false
        sendTyping(conversationId: conversationId, isTyping: false)
    }

    // MARK: - Private

    private func receive(_ message: ChatMessage) {
        guard message.conversationId == conversationId else { return }
        append(message)
        typers[message.senderId] = nil
        typingNames = Array(typers.values)
        if !isMine(message) {
            Task { await markRead(conversationId: conversationId, messageId: message.id) }
        }
    }

    private func receive(_ event: TypingEvent) {
        guard event.conversationId == conversationId, event.userId != currentUserId else { return }
        typers[event.userId] = event.isTyping ? (event.name ?? L10n.text("Ai đó")) : nil
        typingNames = Array(typers.values)
    }

    private func append(_ message: ChatMessage) {
        guard !messages.contains(message) else { return }
        messages.append(message)
    }
}
