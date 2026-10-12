import Foundation

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let fetchConversations: FetchConversationsUseCase
    private let observeNewMessages: ObserveNewMessagesUseCase
    private let currentUserId: String
    private var task: Task<Void, Never>?

    /// Conversation currently open on screen; its unread counter stays at 0.
    var activeConversationId: String?

    init(currentUserId: String, fetchConversations: FetchConversationsUseCase, observeNewMessages: ObserveNewMessagesUseCase) {
        self.currentUserId = currentUserId
        self.fetchConversations = fetchConversations
        self.observeNewMessages = observeNewMessages
    }

    deinit {
        task?.cancel()
    }

    var totalUnread: Int { conversations.reduce(0) { $0 + $1.unreadCount } }

    func start() {
        guard task == nil else { return }
        let stream = observeNewMessages()
        task = Task { [weak self] in
            for await message in stream { self?.apply(message) }
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await fetchConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].unreadCount = 0
    }

    private func apply(_ message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == message.conversationId }) else {
            Task { await load() }
            return
        }
        var conversation = conversations.remove(at: index)
        conversation.lastMessage = message
        conversation.lastMessageAt = message.createdAt
        if message.senderId != currentUserId, message.conversationId != activeConversationId {
            conversation.unreadCount += 1
        }
        conversations.insert(conversation, at: 0)
    }
}
