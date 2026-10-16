import XCTest
@testable import FamilyTracker

final class ChatHubBuilderTests: XCTestCase {
    func testMergesGroupConversationAndKeepsGroupWithoutMessages() {
        let member = User(id: "u2", name: "Đạt", email: "", isOnline: true)
        let groups = [
            FamilyGroup(id: "g1", name: "Gia đình", inviteCode: "123456",
                        members: [member], conversationId: "c1"),
            FamilyGroup(id: "g2", name: "Chưa chat", members: [member], conversationId: nil)
        ]
        let snapshot = ChatHubBuilder.build(
            groups: groups,
            conversations: [conversation("c1", groupID: "g1", date: date("2026-10-16T10:00:00Z"))],
            currentUserId: "u1"
        )

        XCTAssertEqual(snapshot.items.count, 2)
        XCTAssertEqual(snapshot.items.map(\.id), ["group:g1", "group:g2"])
        XCTAssertEqual(snapshot.items.first?.conversationId, "c1")
        XCTAssertEqual(snapshot.items.first?.memberCount, 1)
        XCTAssertEqual(snapshot.items.first?.onlineCount, 1)
        XCTAssertEqual(snapshot.items.first?.inviteCode, "123456")
        XCTAssertNil(snapshot.items.last?.conversationId)
    }

    func testGroupConversationIDIsAvailableBeforeConversationListLoads() {
        let snapshot = ChatHubBuilder.build(
            groups: [FamilyGroup(id: "g1", name: "Family", conversationId: "c1")],
            conversations: [], currentUserId: "u1"
        )

        XCTAssertEqual(snapshot.items.first?.conversationId, "c1")
    }

    func testOrphanConversationIsNotLostAndMismatchedLinkIsNotMerged() {
        let group = FamilyGroup(id: "g1", name: "Family", conversationId: "expected")
        let snapshot = ChatHubBuilder.build(
            groups: [group], conversations: [conversation("other", groupID: "g1")], currentUserId: "u1"
        )

        XCTAssertEqual(snapshot.items.map(\.id), ["conversation:other", "group:g1"])
        XCTAssertEqual(snapshot.unmatchedGroupConversationIDs, ["other"])
        XCTAssertEqual(snapshot.items.last?.conversationId, "expected")
    }

    func testEmptyMappedGroupMembersFallBackToConversationMembers() {
        let group = FamilyGroup(id: "g1", name: "Family", members: [], conversationId: "c1")
        let members = [
            ConversationMember(id: "u1", name: "Me", avatar: nil, isOnline: true),
            ConversationMember(id: "u2", name: "Đạt", avatar: nil, isOnline: false)
        ]
        let snapshot = ChatHubBuilder.build(
            groups: [group], conversations: [conversation("c1", groupID: "g1", members: members)],
            currentUserId: "u1"
        )

        XCTAssertEqual(snapshot.items.first?.memberCount, 2)
        XCTAssertEqual(snapshot.items.first?.onlineCount, 1)
    }

    func testSortUsesLastMessageThenStableIDNotPresence() {
        let old = conversation("old", date: date("2026-10-15T10:00:00Z"))
        let new = conversation("new", date: date("2026-10-16T10:00:00Z"))
        let first = ChatHubBuilder.build(groups: [], conversations: [old, new], currentUserId: "u1")
        let second = ChatHubBuilder.build(groups: [], conversations: [new, old], currentUserId: "u1")

        XCTAssertEqual(first.items.map(\.id), ["conversation:new", "conversation:old"])
        XCTAssertEqual(first.items.map(\.id), second.items.map(\.id))
    }

    func testSearchMatchesVietnameseTokensAndDStroke() {
        let group = FamilyGroup(id: "g1", name: "QUANG LÝ THANH NHẬT")
        let member = ConversationMember(id: "u2", name: "Đạt", avatar: nil, isOnline: false)
        let snapshot = ChatHubBuilder.build(
            groups: [group], conversations: [conversation("c1", groupID: "g1", members: [member])],
            currentUserId: "u1"
        )

        XCTAssertEqual(ChatHubBuilder.search(snapshot, query: "quang ly").conversations.map(\.id), ["group:g1"])
        XCTAssertEqual(ChatHubBuilder.search(snapshot, query: "nhat").conversations.map(\.id), ["group:g1"])
        XCTAssertEqual(ChatHubBuilder.search(snapshot, query: "dat").people.map(\.id), ["u2"])
        XCTAssertEqual(ChatHubBuilder.search(snapshot, query: "đạt").people.map(\.id), ["u2"])
        XCTAssertTrue(ChatHubBuilder.search(snapshot, query: "không có").conversations.isEmpty)
    }

    func testPeopleAreDeduplicatedByIDAndCurrentUserIsExcluded() {
        let same = ConversationMember(id: "u2", name: "Đạt", avatar: nil, isOnline: true)
        let own = ConversationMember(id: "u1", name: "Tôi", avatar: nil, isOnline: true)
        let snapshot = ChatHubBuilder.build(
            groups: [FamilyGroup(id: "g1", name: "One"), FamilyGroup(id: "g2", name: "Two")],
            conversations: [
                conversation("c1", groupID: "g1", members: [same, own]),
                conversation("c2", groupID: "g2", members: [same])
            ],
            currentUserId: "u1"
        )

        XCTAssertEqual(snapshot.people.map(\.id), ["u2"])
        XCTAssertEqual(ChatHubBuilder.search(snapshot, query: "dat", filter: .groups).people.count, 0)
    }

    func testDuplicateNamesRemainSeparateAndFiltersApply() {
        let snapshot = ChatHubBuilder.build(
            groups: [FamilyGroup(id: "g1", name: "Gia đình"), FamilyGroup(id: "g2", name: "Gia đình")],
            conversations: [conversation("d1", type: .direct, name: "Gia đình")],
            currentUserId: "u1"
        )

        XCTAssertEqual(ChatHubBuilder.search(snapshot, query: "gia dinh", filter: .groups).conversations.count, 2)
        XCTAssertEqual(ChatHubBuilder.search(snapshot, query: "gia dinh", filter: .direct).conversations.count, 1)
        XCTAssertEqual(Set(snapshot.items.map(\.id)).count, 3)
    }

    func testPreviewHandlesTextImageVoiceInBothLanguages() {
        let text = message(type: .text, content: "Xin chào")
        let image = message(type: .image, content: "")
        let voice = message(type: .voice, content: "")

        XCTAssertEqual(ChatHubFormat.preview(text, language: .vietnamese), "Đạt: Xin chào")
        XCTAssertEqual(ChatHubFormat.preview(image, language: .vietnamese), "Đạt: Ảnh")
        XCTAssertEqual(ChatHubFormat.preview(voice, language: .english), "Đạt: Voice message")
        XCTAssertEqual(ChatHubFormat.preview(nil, language: .english), "No messages yet")
    }

    func testTimestampUsesSelectedLanguageAndInjectedClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let now = date("2026-10-16T12:00:00Z")

        XCTAssertNotNil(ChatHubFormat.timestamp(date("2026-10-16T10:00:00Z"), now: now,
                                                language: .vietnamese, calendar: calendar))
        XCTAssertEqual(ChatHubFormat.timestamp(date("2026-10-15T10:00:00Z"), now: now,
                                               language: .vietnamese, calendar: calendar), "Hôm qua")
        XCTAssertEqual(ChatHubFormat.timestamp(date("2026-10-15T10:00:00Z"), now: now,
                                               language: .english, calendar: calendar), "Yesterday")
        XCTAssertNotNil(ChatHubFormat.timestamp(date("2026-10-13T10:00:00Z"), now: now,
                                                language: .english, calendar: calendar))
        XCTAssertNotNil(ChatHubFormat.timestamp(date("2025-10-13T10:00:00Z"), now: now,
                                                language: .english, calendar: calendar))
    }

    private func conversation(
        _ id: String,
        type: ConversationType = .group,
        groupID: String? = nil,
        name: String? = nil,
        members: [ConversationMember] = [],
        date: Date? = nil
    ) -> Conversation {
        Conversation(id: id, type: type, groupId: groupID, name: name, avatarUrl: nil,
                     members: members, lastMessage: nil, lastMessageAt: date, unreadCount: 0)
    }

    private func message(type: ChatMessageType, content: String) -> ChatMessage {
        ChatMessage(id: "m1", conversationId: "c1", senderId: "u2", senderName: "Đạt",
                    type: type, content: content, attachment: nil, mediaUrl: nil,
                    duration: nil, fileSize: nil, mimeType: nil, createdAt: date("2026-10-16T10:00:00Z"))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
