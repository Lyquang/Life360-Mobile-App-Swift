import XCTest
@testable import FamilyTracker

@MainActor
final class DirectMessageFlowTests: XCTestCase {
    func testOpenDirectChatUsesMemberIDAndBlocksSecondRequest() async {
        let chat = ChatRepositoryMock()
        let expected = conversation(id: "direct-1", date: nil, unread: 0)
        let gate = DirectConversationGate()
        chat.openHandler = { _ in try await gate.wait() }
        let viewModel = makeCircleViewModel(chat: chat)
        let member = User(id: "member-1", name: "Nguyễn Ánh", email: "member@example.com")
        let other = User(id: "member-2", name: "Bảo Ngọc", email: "other@example.com")

        let firstTask = Task { await viewModel.openDirectChat(with: member) }
        while chat.openedUserIDs.isEmpty { await Task.yield() }
        let blockedRoute = await viewModel.openDirectChat(with: other)

        XCTAssertNil(blockedRoute)
        XCTAssertEqual(viewModel.openingDirectMemberId, "member-1")
        await gate.succeed(with: expected)
        let route = await firstTask.value

        XCTAssertEqual(chat.openedUserIDs, ["member-1"])
        XCTAssertEqual(route?.conversation.id, expected.id)
        XCTAssertEqual(route?.fallbackTitle, "Nguyễn Ánh")
        XCTAssertNil(viewModel.openingDirectMemberId)
    }

    func testForbiddenAndNetworkErrorsAreFriendly() async {
        let chat = ChatRepositoryMock()
        let viewModel = makeCircleViewModel(chat: chat)
        let member = User(id: "member-1", name: "Nguyễn Ánh", email: "member@example.com")

        chat.openResult = .failure(DomainError.forbidden)
        let forbiddenRoute = await viewModel.openDirectChat(with: member)
        XCTAssertNil(forbiddenRoute)
        XCTAssertEqual(viewModel.directChatFailure?.message, L10n.text("Người này không còn trong nhóm."))

        chat.openResult = .failure(DomainError.network("offline"))
        let networkRoute = await viewModel.retryDirectChat()
        XCTAssertNil(networkRoute)
        XCTAssertEqual(viewModel.directChatFailure?.message, L10n.text("Không có kết nối mạng. Hãy thử lại."))
    }

    func testNonChat403KeepsExistingUserFacingBehavior() {
        let endpoint = PlaceEndpoint.list(groupId: "group-1")
        XCTAssertEqual(endpoint.path, "/groups/group-1/places")
        let error = APIError.http(status: 403, code: "FORBIDDEN", message: nil, errors: []).domainError
        XCTAssertEqual(error, .forbidden)
        XCTAssertEqual(error.localizedDescription, "Bạn không có quyền truy cập dữ liệu này.")
    }

    func testUpsertInsertsConversationWhenMissing() {
        let list = makeConversationListViewModel()
        list.upsert(conversation(id: "direct-1", date: date(10), unread: 1))

        XCTAssertEqual(list.conversations.map(\.id), ["direct-1"])
        XCTAssertEqual(list.conversations.first?.unreadCount, 1)
    }

    func testUpsertUsesIncomingActivityWhenItIsNewer() {
        let list = makeConversationListViewModel()
        list.upsert(conversation(id: "direct-1", date: date(10), unread: 5))
        list.upsert(conversation(id: "direct-1", date: date(20), unread: 2))

        XCTAssertEqual(list.conversations.count, 1)
        XCTAssertEqual(list.conversations.first?.lastMessageAt, date(20))
        XCTAssertEqual(list.conversations.first?.unreadCount, 2)
    }

    func testUpsertKeepsExistingActivityWhenItIsNewer() {
        let list = makeConversationListViewModel()
        list.upsert(conversation(id: "direct-1", date: date(20), unread: 7))
        list.upsert(conversation(id: "direct-1", date: date(10), unread: 1))

        XCTAssertEqual(list.conversations.count, 1)
        XCTAssertEqual(list.conversations.first?.lastMessageAt, date(20))
        XCTAssertEqual(list.conversations.first?.unreadCount, 7)
    }

    func testPendingRouteIsConsumedExactlyOnceAfterProgrammaticDismiss() {
        var store = DirectChatSheetRouteStore()
        let route = CircleListViewModel.DirectChatRoute(
            conversation: conversation(id: "direct-1", date: nil, unread: 0),
            fallbackTitle: "Nguyễn Ánh"
        )

        store.stage(route)

        XCTAssertEqual(store.consume()?.conversation.id, "direct-1")
        XCTAssertNil(store.consume())
    }

    func testInteractiveDismissWithoutSuccessfulRouteDoesNotNavigate() {
        var store = DirectChatSheetRouteStore()
        store.discard()
        XCTAssertNil(store.consume())
    }

    func testInteractiveDismissCancelsAndIgnoresLateRequestResult() async {
        let chat = ChatRepositoryMock()
        let gate = DirectConversationGate()
        chat.openHandler = { _ in try await gate.wait() }
        let viewModel = makeCircleViewModel(chat: chat)
        let member = User(id: "member-1", name: "Nguyễn Ánh", email: "member@example.com")
        let task = Task { await viewModel.openDirectChat(with: member) }
        while chat.openedUserIDs.isEmpty { await Task.yield() }

        task.cancel()
        viewModel.cancelDirectChatOpening()
        await gate.succeed(with: conversation(id: "direct-1", date: nil, unread: 0))

        let ignoredRoute = await task.value
        XCTAssertNil(ignoredRoute)
        XCTAssertNil(viewModel.openingDirectMemberId)
        XCTAssertNil(viewModel.directChatFailure)
    }

    func testLocalizedNamesPreserveUnicodeAndLongContent() {
        let accented = "Nguyễn Ánh"
        let longName = String(repeating: "Nguyễn Hoàng Minh Anh ", count: 12)

        XCTAssertEqual(
            L10n.format("Nhắn tin cho %@", accented, language: .vietnamese),
            "Nhắn tin cho Nguyễn Ánh"
        )
        XCTAssertEqual(
            L10n.format("Nhắn tin cho %@", accented, language: .english),
            "Message Nguyễn Ánh"
        )
        XCTAssertTrue(L10n.format("Hãy gửi lời chào đến %@", longName, language: .vietnamese).contains(longName))
        XCTAssertTrue(L10n.format("Hãy gửi lời chào đến %@", longName, language: .english).contains(longName))
    }

    func testDirectConversationResponseDecodes() throws {
        let data = Data(#"{"success":true,"data":{"id":"direct-1","type":"direct","groupId":null,"name":"","avatarUrl":null,"members":[],"unreadCount":0}}"#.utf8)
        let response = try BackendJSONCoding.makeDecoder().decode(
            APIResponseDTO<ConversationDTO>.self,
            from: data
        )

        let conversation = try response.unwrap(fallbackMessage: "decode failed").toDomain()
        XCTAssertEqual(conversation.id, "direct-1")
        XCTAssertEqual(conversation.type, .direct)
        XCTAssertTrue(conversation.displayName.isEmpty)
    }

    private func makeCircleViewModel(chat: ChatRepositoryMock) -> CircleListViewModel {
        let circle = CircleRepositoryMock()
        let live = LiveLocationRepositoryMock()
        return CircleListViewModel(
            fetchMyCircles: FetchMyCirclesUseCase(repository: circle),
            createCircle: CreateCircleUseCase(repository: circle),
            joinCircle: JoinCircleUseCase(repository: circle),
            fetchMembers: FetchCircleMembersUseCase(repository: circle),
            observePresence: ObservePresenceUseCase(repository: live),
            openDirectChat: OpenDirectChatUseCase(repository: chat)
        )
    }

    private func makeConversationListViewModel() -> ConversationListViewModel {
        let chat = ChatRepositoryMock()
        return ConversationListViewModel(
            currentUserId: "me",
            fetchConversations: FetchConversationsUseCase(repository: chat),
            observeNewMessages: ObserveNewMessagesUseCase(repository: chat)
        )
    }

    private func conversation(id: String, date: Date?, unread: Int) -> Conversation {
        Conversation(
            id: id,
            type: .direct,
            groupId: nil,
            name: "Nguyễn Ánh",
            avatarUrl: nil,
            members: [],
            lastMessage: nil,
            lastMessageAt: date,
            unreadCount: unread
        )
    }

    private func date(_ interval: TimeInterval) -> Date {
        Date(timeIntervalSince1970: interval)
    }
}

private final class CircleRepositoryMock: CircleRepository {
    func fetchMyCircles() async throws -> [FamilyGroup] { [] }
    func createCircle(name: String) async throws -> FamilyGroup { FamilyGroup(id: "group", name: name) }
    func joinCircle(inviteCode: String) async throws -> FamilyGroup { FamilyGroup(id: "group", name: "Group") }
    func fetchMembers(circleId: String) async throws -> [User] { [] }
}

private final class LiveLocationRepositoryMock: LiveLocationRepository {
    func observeMemberLocations() -> AsyncStream<MemberLocation> { AsyncStream { $0.finish() } }
    func observeStayAlerts() -> AsyncStream<LocationStayAlert> { AsyncStream { $0.finish() } }
    func observePresence() -> AsyncStream<MemberPresence> { AsyncStream { $0.finish() } }
    func sendLocation(_ point: GeoPoint, batteryLevel: Int?) {}
}

private final class ChatRepositoryMock: ChatRepository {
    var openedUserIDs: [String] = []
    var openHandler: ((String) async throws -> Conversation)?
    var openResult: Result<Conversation, Error> = .success(
        Conversation(id: "direct", type: .direct, groupId: nil, name: "Member", avatarUrl: nil,
                     members: [], lastMessage: nil, lastMessageAt: nil, unreadCount: 0)
    )

    func fetchConversations() async throws -> [Conversation] { [] }
    func fetchMessages(conversationId: String, before: String?) async throws -> MessagePage {
        MessagePage(messages: [], hasMore: false, nextBefore: nil)
    }
    func sendText(_ text: String, conversationId: String) async throws -> ChatMessage { fatalError("Unused") }
    func sendImage(attachmentUrl: String, caption: String?, image: ImageAttachmentInput,
                   conversationId: String) async throws -> ChatMessage { fatalError("Unused") }
    func sendVoice(mediaUrl: String, voice: VoiceAttachmentInput,
                   conversationId: String) async throws -> ChatMessage { fatalError("Unused") }
    func markRead(conversationId: String, messageId: String?) async throws {}
    func openDirectConversation(userId: String) async throws -> Conversation {
        openedUserIDs.append(userId)
        if let openHandler { return try await openHandler(userId) }
        return try openResult.get()
    }
    func observeNewMessages() -> AsyncStream<ChatMessage> { AsyncStream { $0.finish() } }
    func observeTyping() -> AsyncStream<TypingEvent> { AsyncStream { $0.finish() } }
    func sendTyping(conversationId: String, isTyping: Bool) {}
}

private actor DirectConversationGate {
    private var continuation: CheckedContinuation<Conversation, Error>?

    func wait() async throws -> Conversation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func succeed(with conversation: Conversation) {
        continuation?.resume(returning: conversation)
        continuation = nil
    }
}
