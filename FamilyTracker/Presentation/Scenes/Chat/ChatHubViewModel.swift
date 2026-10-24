import Foundation

@MainActor
final class ChatHubViewModel: ObservableObject {
    @Published private(set) var snapshot = ChatHubSnapshot(items: [], people: [], unmatchedGroupConversationIDs: [])
    @Published private(set) var totalUnread = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private(set) var activeConversationId: String?

    private let currentUserId: String
    private let fetchGroups: FetchMyCirclesUseCase
    private let fetchConversations: FetchConversationsUseCase
    private let fetchUnreadSummary: FetchUnreadSummaryUseCase
    private let observeNewMessages: ObserveNewMessagesUseCase
    private let observeConversationUpdates: ObserveConversationUpdatesUseCase
    private let observePresence: ObservePresenceUseCase
    private let markConversationRead: MarkConversationReadUseCase

    private var groups = [FamilyGroup]()
    private var conversations = [Conversation]()
    private var messageTask: Task<Void, Never>?
    private var conversationUpdateTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    private var presenceFlushTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var pendingPresence = [String: Bool]()
    private var seenMessageIDs = Set<String>()

    init(
        currentUserId: String,
        fetchGroups: FetchMyCirclesUseCase,
        fetchConversations: FetchConversationsUseCase,
        fetchUnreadSummary: FetchUnreadSummaryUseCase,
        observeNewMessages: ObserveNewMessagesUseCase,
        observeConversationUpdates: ObserveConversationUpdatesUseCase,
        observePresence: ObservePresenceUseCase,
        markConversationRead: MarkConversationReadUseCase
    ) {
        self.currentUserId = currentUserId
        self.fetchGroups = fetchGroups
        self.fetchConversations = fetchConversations
        self.fetchUnreadSummary = fetchUnreadSummary
        self.observeNewMessages = observeNewMessages
        self.observeConversationUpdates = observeConversationUpdates
        self.observePresence = observePresence
        self.markConversationRead = markConversationRead
    }

    deinit {
        messageTask?.cancel()
        conversationUpdateTask?.cancel()
        presenceTask?.cancel()
        presenceFlushTask?.cancel()
        refreshTask?.cancel()
        loadTask?.cancel()
    }

    func start() {
        if messageTask == nil {
            let messages = observeNewMessages()
            messageTask = Task { [weak self] in
                for await message in messages {
                    guard !Task.isCancelled else { break }
                    self?.receive(message)
                }
            }
        }
        if presenceTask == nil {
            let updates = observePresence()
            presenceTask = Task { [weak self] in
                for await update in updates {
                    guard !Task.isCancelled else { break }
                    self?.queuePresence(update)
                }
            }
        }
        if conversationUpdateTask == nil {
            let updates = observeConversationUpdates()
            conversationUpdateTask = Task { [weak self] in
                for await _ in updates {
                    guard !Task.isCancelled else { break }
                    self?.refreshInBackground()
                }
            }
        }
    }

    func stop() {
        messageTask?.cancel()
        messageTask = nil
        conversationUpdateTask?.cancel()
        conversationUpdateTask = nil
        presenceTask?.cancel()
        presenceTask = nil
        presenceFlushTask?.cancel()
        presenceFlushTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        loadTask?.cancel()
        loadTask = nil
        pendingPresence.removeAll()
    }

    func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoad()
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        let signpost = PerformanceSignposts.begin(.loadChats)
        defer { PerformanceSignposts.end(.loadChats, signpost) }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let fetchedGroups = fetchGroups()
            async let fetchedConversations = fetchConversations()
            async let fetchedUnread = unreadResult()
            let (newGroups, newConversations, unreadResult) = try await (
                fetchedGroups, fetchedConversations, fetchedUnread
            )
            guard !Task.isCancelled else { return }
            groups = newGroups
            switch unreadResult {
            case .success(let summary):
                conversations = newConversations.map { conversation in
                    var copy = conversation
                    copy.unreadCount = summary.counts[conversation.id] ?? 0
                    return copy
                }
                totalUnread = max(0, summary.totalUnread)
            case .failure(let error):
                conversations = newConversations
                totalUnread = newConversations.reduce(0) { $0 + $1.unreadCount }
                errorMessage = L10n.message(error.localizedDescription)
            }
            rebuild()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = L10n.message(error.localizedDescription)
        }
    }

    func refreshInBackground() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.load()
            self?.refreshTask = nil
        }
    }

    func upsert(_ group: FamilyGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        rebuild()
        refreshInBackground()
    }

    func group(id: String) -> FamilyGroup? {
        groups.first { $0.id == id }
    }

    func upsert(_ incoming: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == incoming.id }) {
            var merged = incoming
            let existing = conversations[index]
            if let previous = existing.lastMessageAt,
               incoming.lastMessageAt.map({ previous > $0 }) ?? true {
                merged.lastMessage = existing.lastMessage
                merged.lastMessageAt = previous
                merged.unreadCount = existing.unreadCount
            }
            conversations[index] = merged
        } else {
            conversations.append(incoming)
        }
        rebuild()
        refreshInBackground()
    }

    func didOpenConversation(_ id: String) {
        activeConversationId = id
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            let unread = conversations[index].unreadCount
            conversations[index].unreadCount = 0
            totalUnread = max(0, totalUnread - unread)
            rebuild()
        }
        Task { [weak self] in
            await self?.markConversationRead(conversationId: id)
            await self?.reconcileUnread()
        }
    }

    func didCloseConversation(_ id: String) {
        if activeConversationId == id { activeConversationId = nil }
    }

    private func receive(_ message: ChatMessage) {
        guard seenMessageIDs.insert(message.id).inserted else { return }
        if seenMessageIDs.count > 500 { seenMessageIDs.removeAll(keepingCapacity: true) }
        guard let index = conversations.firstIndex(where: { $0.id == message.conversationId }) else {
            refreshInBackground()
            return
        }
        if let previous = conversations[index].lastMessageAt, previous > message.createdAt { return }
        conversations[index].lastMessage = message
        conversations[index].lastMessageAt = message.createdAt
        if message.senderId != currentUserId, activeConversationId != message.conversationId {
            conversations[index].unreadCount += 1
            totalUnread += 1
        }
        rebuild()
    }

    private func queuePresence(_ update: MemberPresence) {
        pendingPresence[update.userId] = update.isOnline
        guard presenceFlushTask == nil else { return }
        presenceFlushTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) }
            catch { return }
            self?.flushPresence()
        }
    }

    private func flushPresence() {
        presenceFlushTask = nil
        let changes = pendingPresence
        pendingPresence.removeAll()
        guard !changes.isEmpty else { return }
        for index in groups.indices {
            guard var members = groups[index].members else { continue }
            for memberIndex in members.indices {
                if let status = changes[members[memberIndex].id] { members[memberIndex].isOnline = status }
            }
            groups[index].members = members
        }
        for index in conversations.indices {
            let old = conversations[index]
            let members = old.members.map { member in
                ConversationMember(id: member.id, name: member.name, avatar: member.avatar,
                                   isOnline: changes[member.id] ?? member.isOnline)
            }
            conversations[index] = Conversation(
                id: old.id, type: old.type, groupId: old.groupId, name: old.name,
                avatarUrl: old.avatarUrl, members: members, lastMessage: old.lastMessage,
                lastMessageAt: old.lastMessageAt, unreadCount: old.unreadCount
            )
        }
        rebuild()
    }

    private func reconcileUnread() async {
        do {
            let latest = try await fetchUnreadSummary()
            guard !Task.isCancelled else { return }
            totalUnread = max(0, latest.totalUnread)
            for index in conversations.indices {
                conversations[index].unreadCount = activeConversationId == conversations[index].id
                    ? 0 : latest.counts[conversations[index].id] ?? 0
            }
            rebuild()
        } catch {
            // Keep the optimistic count until the next visible refresh.
        }
    }

    private func unreadResult() async -> Result<ChatUnreadSummary, Error> {
        do { return .success(try await fetchUnreadSummary()) }
        catch { return .failure(error) }
    }

    private func rebuild() {
        let next = ChatHubBuilder.build(groups: groups, conversations: conversations,
                                        currentUserId: currentUserId)
        if next.items != snapshot.items || next.people != snapshot.people {
            snapshot = next
        }
    }
}
