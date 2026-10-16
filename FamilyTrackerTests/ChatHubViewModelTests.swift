import XCTest
@testable import FamilyTracker

@MainActor
final class ChatHubViewModelTests: XCTestCase {
    func testLoadsGroupsConversationsAndCanonicalUnreadCount() async {
        let chat = HubChatRepositoryMock()
        chat.conversations = [conversation(id: "c1", groupID: "g1", unread: 1)]
        chat.summary = ChatUnreadSummary(totalUnread: 4, counts: ["c1": 4])
        let circles = HubCircleRepositoryMock()
        circles.groups = [FamilyGroup(id: "g1", name: "Family", conversationId: "c1")]
        let viewModel = makeViewModel(chat: chat, circles: circles)

        await viewModel.load()

        XCTAssertEqual(viewModel.snapshot.items.map(\.id), ["group:g1"])
        XCTAssertEqual(viewModel.snapshot.items.first?.unreadCount, 4)
        XCTAssertEqual(viewModel.totalUnread, 4)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testFailedRefreshKeepsPreviouslyLoadedRows() async {
        let chat = HubChatRepositoryMock()
        chat.conversations = [conversation(id: "c1", groupID: "g1")]
        let circles = HubCircleRepositoryMock()
        circles.groups = [FamilyGroup(id: "g1", name: "Family", conversationId: "c1")]
        let viewModel = makeViewModel(chat: chat, circles: circles)
        await viewModel.load()

        chat.fetchError = DomainError.network("Offline")
        await viewModel.load()

        XCTAssertEqual(viewModel.snapshot.items.map(\.id), ["group:g1"])
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testUnreadFailureKeepsChatsVisibleWithConversationCounts() async {
        let chat = HubChatRepositoryMock()
        chat.conversations = [conversation(id: "c1", groupID: "g1", unread: 2)]
        chat.summaryError = DomainError.network("Offline")
        let circles = HubCircleRepositoryMock()
        circles.groups = [FamilyGroup(id: "g1", name: "Family", conversationId: "c1")]
        let viewModel = makeViewModel(chat: chat, circles: circles)

        await viewModel.load()

        XCTAssertEqual(viewModel.snapshot.items.map(\.id), ["group:g1"])
        XCTAssertEqual(viewModel.totalUnread, 2)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testNewMessageUpdatesPreviewAndUnreadWithoutDuplicateEvent() async {
        let chat = HubChatRepositoryMock()
        chat.conversations = [conversation(id: "c1", groupID: "g1")]
        let circles = HubCircleRepositoryMock()
        circles.groups = [FamilyGroup(id: "g1", name: "Family", conversationId: "c1")]
        let viewModel = makeViewModel(chat: chat, circles: circles)
        await viewModel.load()
        viewModel.start()
        let message = ChatMessage(
            id: "m1", conversationId: "c1", senderId: "u2", senderName: "Đạt",
            type: .text, content: "Hello", attachment: nil, mediaUrl: nil,
            duration: nil, fileSize: nil, mimeType: nil, createdAt: Date()
        )
        chat.send(message)
        chat.send(message)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(viewModel.snapshot.items.first?.lastMessage?.id, "m1")
        XCTAssertEqual(viewModel.snapshot.items.first?.unreadCount, 1)
        XCTAssertEqual(viewModel.totalUnread, 1)
        viewModel.stop()
    }

    func testUpsertGroupAppearsBeforeBackgroundReconciliation() async {
        let chat = HubChatRepositoryMock()
        let circles = HubCircleRepositoryMock()
        let viewModel = makeViewModel(chat: chat, circles: circles)

        viewModel.upsert(FamilyGroup(id: "new", name: "New family"))

        XCTAssertEqual(viewModel.snapshot.items.map(\.id), ["group:new"])
        viewModel.stop()
    }

    func testPresenceChangesGroupOnlineCountWithoutReordering() async throws {
        let chat = HubChatRepositoryMock()
        chat.conversations = [conversation(id: "c1", groupID: "g1")]
        let circles = HubCircleRepositoryMock()
        circles.groups = [FamilyGroup(id: "g1", name: "Family", members: [
            User(id: "u2", name: "Đạt", email: "", isOnline: false)
        ], conversationId: "c1")]
        let live = HubLiveRepositoryMock()
        let viewModel = makeViewModel(chat: chat, circles: circles, live: live)
        await viewModel.load()
        viewModel.start()

        live.send(MemberPresence(userId: "u2", isOnline: true))
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.snapshot.items.map(\.id), ["group:g1"])
        XCTAssertEqual(viewModel.snapshot.items.first?.onlineCount, 1)
        viewModel.stop()
    }

    func testConversationUpdateTriggersBackgroundReconciliation() async {
        let chat = HubChatRepositoryMock()
        let circles = HubCircleRepositoryMock()
        let viewModel = makeViewModel(chat: chat, circles: circles)
        await viewModel.load()
        viewModel.start()

        chat.sendConversationUpdate("c1")
        for _ in 0..<100 {
            if await chat.numberOfFetches() >= 2 { break }
            await Task.yield()
        }

        let fetchCount = await chat.numberOfFetches()
        XCTAssertGreaterThanOrEqual(fetchCount, 2)
        viewModel.stop()
    }

    func testUnreadSummaryDTODecodesDocumentedResponse() throws {
        let json = """
        {"success":true,"data":{"totalUnread":5,"conversations":[
          {"conversationId":"c1","unreadCount":3,"lastReadMessageId":"m1"}]}}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(APIResponseDTO<UnreadSummaryDTO>.self, from: json)

        XCTAssertEqual(response.data?.totalUnread, 5)
        XCTAssertEqual(response.data?.conversations.first?.unreadCount, 3)
    }

    private func makeViewModel(
        chat: HubChatRepositoryMock,
        circles: HubCircleRepositoryMock,
        live: HubLiveRepositoryMock = HubLiveRepositoryMock()
    ) -> ChatHubViewModel {
        return ChatHubViewModel(
            currentUserId: "u1",
            fetchGroups: FetchMyCirclesUseCase(repository: circles),
            fetchConversations: FetchConversationsUseCase(repository: chat),
            fetchUnreadSummary: FetchUnreadSummaryUseCase(repository: chat),
            observeNewMessages: ObserveNewMessagesUseCase(repository: chat),
            observeConversationUpdates: ObserveConversationUpdatesUseCase(repository: chat),
            observePresence: ObservePresenceUseCase(repository: live),
            markConversationRead: MarkConversationReadUseCase(repository: chat)
        )
    }

    private func conversation(id: String, groupID: String, unread: Int = 0) -> Conversation {
        Conversation(id: id, type: .group, groupId: groupID, name: "Family", avatarUrl: nil,
                     members: [], lastMessage: nil, lastMessageAt: nil, unreadCount: unread)
    }
}

private final class HubCircleRepositoryMock: CircleRepository {
    var groups = [FamilyGroup]()
    func fetchMyCircles() async throws -> [FamilyGroup] { groups }
    func createCircle(name: String) async throws -> FamilyGroup { fatalError("Unused") }
    func joinCircle(inviteCode: String) async throws -> FamilyGroup { fatalError("Unused") }
    func fetchMembers(circleId: String) async throws -> [User] { [] }
}

private final class HubChatRepositoryMock: ChatRepository {
    var conversations = [Conversation]()
    var summary = ChatUnreadSummary(totalUnread: 0, counts: [:])
    var fetchError: Error?
    var summaryError: Error?
    private let fetchCounter = HubFetchCounter()
    private var messageContinuation: AsyncStream<ChatMessage>.Continuation?
    private var updateContinuation: AsyncStream<String>.Continuation?

    func fetchConversations() async throws -> [Conversation] {
        await fetchCounter.increment()
        if let fetchError { throw fetchError }
        return conversations
    }
    func fetchUnreadSummary() async throws -> ChatUnreadSummary {
        if let summaryError { throw summaryError }
        return summary
    }
    func fetchMessages(conversationId: String, before: String?) async throws -> MessagePage {
        MessagePage(messages: [], hasMore: false, nextBefore: nil)
    }
    func sendText(_ text: String, conversationId: String) async throws -> ChatMessage { fatalError("Unused") }
    func sendImage(attachmentUrl: String, caption: String?, image: ImageAttachmentInput,
                   conversationId: String) async throws -> ChatMessage { fatalError("Unused") }
    func sendVoice(mediaUrl: String, voice: VoiceAttachmentInput,
                   conversationId: String) async throws -> ChatMessage { fatalError("Unused") }
    func markRead(conversationId: String, messageId: String?) async throws {}
    func openDirectConversation(userId: String) async throws -> Conversation { fatalError("Unused") }
    func observeNewMessages() -> AsyncStream<ChatMessage> {
        AsyncStream { messageContinuation = $0 }
    }
    func observeConversationUpdates() -> AsyncStream<String> {
        AsyncStream { updateContinuation = $0 }
    }
    func observeTyping() -> AsyncStream<TypingEvent> { AsyncStream { $0.finish() } }
    func sendTyping(conversationId: String, isTyping: Bool) {}
    func send(_ message: ChatMessage) { messageContinuation?.yield(message) }
    func sendConversationUpdate(_ id: String) { updateContinuation?.yield(id) }
    func numberOfFetches() async -> Int { await fetchCounter.count }
}

private actor HubFetchCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

private final class HubLiveRepositoryMock: LiveLocationRepository {
    private var presenceContinuation: AsyncStream<MemberPresence>.Continuation?
    func observeMemberLocations() -> AsyncStream<MemberLocation> { AsyncStream { $0.finish() } }
    func observeStayAlerts() -> AsyncStream<LocationStayAlert> { AsyncStream { $0.finish() } }
    func observePresence() -> AsyncStream<MemberPresence> {
        AsyncStream { presenceContinuation = $0 }
    }
    func send(_ update: MemberPresence) { presenceContinuation?.yield(update) }
    @MainActor func sendLocation(_ fix: LocationFix, batteryLevel: Int?) {}
}
