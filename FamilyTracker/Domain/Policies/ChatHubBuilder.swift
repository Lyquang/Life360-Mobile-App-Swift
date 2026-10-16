import Foundation

enum ChatHubBuilder {
    static func build(
        groups: [FamilyGroup],
        conversations: [Conversation],
        currentUserId: String
    ) -> ChatHubSnapshot {
        let groupsByID = Dictionary(groups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var matchedConversationIDs = Set<String>()
        var unmatchedGroupConversationIDs = [String]()
        var items = [ChatHubItem]()

        for group in groups {
            let matching = conversations.first { conversation in
                guard conversation.type == .group, conversation.groupId == group.id else { return false }
                return group.conversationId == nil || group.conversationId == conversation.id
            }
            if let matching { matchedConversationIDs.insert(matching.id) }
            items.append(groupItem(group, conversation: matching))
        }

        for conversation in conversations where !matchedConversationIDs.contains(conversation.id) {
            if conversation.type == .group {
                unmatchedGroupConversationIDs.append(conversation.id)
                items.append(orphanGroupItem(conversation))
            } else {
                items.append(directItem(conversation, currentUserId: currentUserId))
            }
        }

        let people = peopleIn(conversations: conversations, groupsByID: groupsByID,
                              currentUserId: currentUserId)
        return ChatHubSnapshot(
            items: items.sorted(by: precedes),
            people: people,
            unmatchedGroupConversationIDs: unmatchedGroupConversationIDs.sorted()
        )
    }

    static func search(
        _ snapshot: ChatHubSnapshot,
        query: String,
        filter: ChatHubFilter = .all
    ) -> ChatHubSearchResult {
        let tokens = normalized(query).split(whereSeparator: \.isWhitespace).map(String.init)
        let conversations = snapshot.items.filter { item in
            let matchesKind = filter == .all || (filter == .groups && item.kind == .group)
                || (filter == .direct && item.kind == .direct)
            return matchesKind && tokens.allSatisfy { normalized(item.title).contains($0) }
        }
        let people = filter == .groups ? [] : snapshot.people.filter { person in
            !tokens.isEmpty && tokens.allSatisfy { normalized(person.name).contains($0) }
        }
        return ChatHubSearchResult(conversations: conversations, people: people)
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased(with: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
    }

    private static func groupItem(_ group: FamilyGroup, conversation: Conversation?) -> ChatHubItem {
        let members = group.members?.isEmpty == false ? group.members : nil
        let conversationMembers = conversation?.members ?? []
        let memberCount = members?.count ?? (conversationMembers.isEmpty ? nil : conversationMembers.count)
        let onlineCount = members.map { $0.filter { $0.isOnline == true }.count }
            ?? (conversationMembers.isEmpty ? nil : conversationMembers.filter(\.isOnline).count)
        return ChatHubItem(
            id: "group:\(group.id)", kind: .group,
            conversationId: conversation?.id ?? group.conversationId,
            groupId: group.id, inviteCode: group.inviteCode,
            title: group.name, lastMessage: conversation?.lastMessage,
            lastMessageAt: conversation?.lastMessageAt, createdAt: parse(group.createdAt),
            unreadCount: conversation?.unreadCount ?? 0, memberCount: memberCount,
            onlineCount: onlineCount, isOnline: nil
        )
    }

    private static func orphanGroupItem(_ conversation: Conversation) -> ChatHubItem {
        ChatHubItem(
            id: "conversation:\(conversation.id)", kind: .group,
            conversationId: conversation.id, groupId: nil, inviteCode: nil,
            title: conversation.displayName,
            lastMessage: conversation.lastMessage, lastMessageAt: conversation.lastMessageAt,
            createdAt: nil, unreadCount: conversation.unreadCount,
            memberCount: conversation.members.isEmpty ? nil : conversation.members.count,
            onlineCount: conversation.members.isEmpty ? nil : conversation.members.filter(\.isOnline).count,
            isOnline: nil
        )
    }

    private static func directItem(_ conversation: Conversation, currentUserId: String) -> ChatHubItem {
        let other = conversation.members.first { $0.id != currentUserId }
        return ChatHubItem(
            id: "conversation:\(conversation.id)", kind: .direct,
            conversationId: conversation.id, groupId: nil, inviteCode: nil,
            title: conversation.displayName,
            lastMessage: conversation.lastMessage, lastMessageAt: conversation.lastMessageAt,
            createdAt: nil, unreadCount: conversation.unreadCount, memberCount: nil,
            onlineCount: nil, isOnline: other?.isOnline
        )
    }

    private static func peopleIn(
        conversations: [Conversation],
        groupsByID: [String: FamilyGroup],
        currentUserId: String
    ) -> [ChatHubPerson] {
        var peopleByID = [String: ChatHubPerson]()
        for conversation in conversations where conversation.type == .group {
            for member in conversation.members where member.id != currentUserId {
                peopleByID[member.id] = ChatHubPerson(id: member.id, name: member.name, isOnline: member.isOnline)
            }
        }
        for group in groupsByID.values {
            for member in group.members ?? [] where member.id != currentUserId {
                peopleByID[member.id] = ChatHubPerson(id: member.id, name: member.name, isOnline: member.isOnline)
            }
        }
        return peopleByID.values.sorted {
            let left = normalized($0.name)
            let right = normalized($1.name)
            return left == right ? $0.id < $1.id : left < right
        }
    }

    private static func precedes(_ lhs: ChatHubItem, _ rhs: ChatHubItem) -> Bool {
        switch (lhs.lastMessageAt, rhs.lastMessageAt) {
        case let (left?, right?) where left != right: return left > right
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        if lhs.activityDate != rhs.activityDate {
            return (lhs.activityDate ?? .distantPast) > (rhs.activityDate ?? .distantPast)
        }
        return lhs.id < rhs.id
    }

    private static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
