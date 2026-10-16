import SwiftUI

struct ChatHubView: View {
    @ObservedObject var viewModel: ChatHubViewModel
    let openingPersonID: String?
    let onOpenChat: (ChatHubItem) -> Void
    let onGroupInfo: (ChatHubItem) -> Void
    let onOpenPerson: (ChatHubPerson) -> Void
    let onCreateGroup: () -> Void
    let onJoinGroup: () -> Void
    let onCopyInvite: (String) -> Void

    var body: some View {
        ChatHubContent(
            snapshot: viewModel.snapshot,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            openingPersonID: openingPersonID,
            onRefresh: { await viewModel.load() },
            onOpenChat: onOpenChat,
            onGroupInfo: onGroupInfo,
            onOpenPerson: onOpenPerson,
            onCreateGroup: onCreateGroup,
            onJoinGroup: onJoinGroup,
            onCopyInvite: onCopyInvite
        )
        .task {
            viewModel.start()
            await viewModel.load()
        }
    }
}

struct ChatHubContent: View {
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    @State private var filter: ChatHubFilter = .all

    let snapshot: ChatHubSnapshot
    let isLoading: Bool
    let errorMessage: String?
    let openingPersonID: String?
    let onRefresh: () async -> Void
    let onOpenChat: (ChatHubItem) -> Void
    let onGroupInfo: (ChatHubItem) -> Void
    let onOpenPerson: (ChatHubPerson) -> Void
    let onCreateGroup: () -> Void
    let onJoinGroup: () -> Void
    let onCopyInvite: (String) -> Void

    private var language: AppLanguage { AppLanguage(locale: locale) }
    private var results: ChatHubSearchResult {
        ChatHubBuilder.search(snapshot, query: searchText, filter: filter)
    }

    var body: some View {
        Group {
            if isLoading && snapshot.items.isEmpty {
                ProgressView(L10n.tr("chat.hub.loading", language: language))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .navigationTitle(Text(verbatim: L10n.tr("chat.hub.title", language: language)))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: onJoinGroup) {
                    Image(systemName: "qrcode")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.tr("chat.hub.action.join", language: language))

                Button(action: onCreateGroup) {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.tr("chat.hub.action.create", language: language))
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: L10n.tr("chat.hub.search.placeholder", language: language))
        .onDisappear { searchText = "" }
    }

    private var list: some View {
        List {
            Section {
                Picker(L10n.tr("chat.hub.filter.title", language: language), selection: $filter) {
                    Text(verbatim: L10n.tr("chat.hub.filter.all", language: language)).tag(ChatHubFilter.all)
                    Text(verbatim: L10n.tr("chat.hub.filter.groups", language: language)).tag(ChatHubFilter.groups)
                    Text(verbatim: L10n.tr("chat.hub.filter.direct", language: language)).tag(ChatHubFilter.direct)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowSeparator(.hidden)
            }

            if let errorMessage {
                Section {
                    HStack(spacing: FTSpacing.sm) {
                        Text(verbatim: errorMessage)
                            .font(.footnote)
                            .foregroundColor(FTColors.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button(L10n.tr("common.action.retry", language: language)) {
                            Task { await onRefresh() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if !results.conversations.isEmpty {
                Section {
                    ForEach(results.conversations) { item in
                        conversationRow(item)
                    }
                } header: {
                    if !searchText.isEmpty {
                        Text(verbatim: L10n.tr("chat.hub.section.chats", language: language))
                    }
                }
            }

            if !results.people.isEmpty {
                Section(L10n.tr("chat.hub.section.people", language: language)) {
                    ForEach(results.people) { person in
                        personRow(person)
                    }
                }
            }

            if results.conversations.isEmpty && results.people.isEmpty {
                Section {
                    emptyContent
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await onRefresh() }
    }

    private func conversationRow(_ item: ChatHubItem) -> some View {
        let canShowInfo = item.groupId != nil
        return ChatHubRow(
            item: item, language: language, now: Date(),
            onOpen: {
                if item.conversationId != nil { onOpenChat(item) }
                else if canShowInfo { onGroupInfo(item) }
            },
            onInfo: canShowInfo ? { onGroupInfo(item) } : nil
        )
        .contextMenu {
            if canShowInfo {
                Button(L10n.tr("chat.hub.action.group_info", language: language)) {
                    onGroupInfo(item)
                }
                if let code = item.inviteCode {
                    Button(L10n.tr("chat.hub.action.copy_invite", language: language)) {
                        onCopyInvite(code)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canShowInfo {
                Button {
                    onGroupInfo(item)
                } label: {
                    Label(L10n.tr("chat.hub.action.group_info", language: language),
                          systemImage: "info.circle")
                }
                .tint(FTColors.primary)
                if let code = item.inviteCode {
                    Button {
                        onCopyInvite(code)
                    } label: {
                        Label(L10n.tr("chat.hub.action.copy_invite", language: language),
                              systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }

    private func personRow(_ person: ChatHubPerson) -> some View {
        Button {
            onOpenPerson(person)
        } label: {
            HStack(spacing: FTSpacing.md) {
                MemberAvatarView(name: person.name, size: .medium,
                                 isOnline: person.isOnline == true, batteryLevel: nil)
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    Text(verbatim: person.name)
                        .font(.headline)
                        .foregroundColor(FTColors.textPrimary)
                        .lineLimit(2)
                    if let online = person.isOnline {
                        Text(verbatim: L10n.tr(online ? "chat.hub.presence.online"
                                              : "chat.hub.presence.offline", language: language))
                            .font(.caption)
                            .foregroundColor(FTColors.textSecondary)
                    }
                }
                Spacer(minLength: FTSpacing.xs)
                if openingPersonID == person.id {
                    ProgressView()
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(L10n.tr("chat.hub.opening_direct", language: language))
                } else {
                    Image(systemName: "message")
                        .foregroundColor(FTColors.primary)
                        .frame(width: 44, height: 44)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(openingPersonID != nil)
        .accessibilityLabel(L10n.tr("chat.hub.accessibility.message_person", person.name,
                                     language: language))
    }

    private var emptyContent: some View {
        VStack(spacing: FTSpacing.md) {
            Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(FTColors.textTertiary)
            Text(verbatim: L10n.tr(searchText.isEmpty ? "chat.hub.empty.groups"
                                  : "chat.hub.empty.search", language: language))
                .font(.headline)
                .multilineTextAlignment(.center)
            if searchText.isEmpty {
                HStack(spacing: FTSpacing.sm) {
                    Button(L10n.tr("chat.hub.action.create", language: language), action: onCreateGroup)
                        .buttonStyle(.borderedProminent)
                    Button(L10n.tr("chat.hub.action.join", language: language), action: onJoinGroup)
                        .buttonStyle(.bordered)
                }
            } else {
                Button(L10n.tr("chat.hub.action.clear_search", language: language)) {
                    searchText = ""
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.xl)
    }
}

#if DEBUG
private struct ChatHubContentPreviews: PreviewProvider {
    static let sampleItems = ChatHubSnapshot(
        items: ChatHubBuilder.build(
            groups: [FamilyGroup(id: "g1", name: "Gia đình Quang", inviteCode: "123456",
                                 members: [User(id: "u2", name: "Đạt", email: "", isOnline: true)],
                                 conversationId: "c1"),
                     FamilyGroup(id: "g2", name: "Nhóm chưa có tin nhắn")],
            conversations: [Conversation(
                id: "c1", type: .group, groupId: "g1", name: "Gia đình Quang", avatarUrl: nil,
                members: [], lastMessage: ChatMessage(
                    id: "m1", conversationId: "c1", senderId: "u2", senderName: "Đạt",
                    type: .image, content: "", attachment: nil, mediaUrl: nil,
                    duration: nil, fileSize: nil, mimeType: nil, createdAt: Date()),
                lastMessageAt: Date(), unreadCount: 2),
                Conversation(id: "d1", type: .direct, groupId: nil,
                             name: "Nguyễn Thị Thanh Nhật Quang với tên rất dài để kiểm tra bố cục",
                             avatarUrl: nil, members: [ConversationMember(
                                id: "u3", name: "Nhật Quang", avatar: nil, isOnline: false)],
                             lastMessage: nil, lastMessageAt: nil, unreadCount: 0)],
            currentUserId: "u1"
        ).items,
        people: [ChatHubPerson(id: "u3", name: "Nguyễn Thị Thanh Nhật Quang", isOnline: false)],
        unmatchedGroupConversationIDs: []
    )

    static var previews: some View {
        preview(snapshot: sampleItems, error: nil)
            .previewDisplayName("Chat, unread, offline, long name")
        preview(snapshot: sampleItems, error: nil)
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Largest Dynamic Type")
        preview(snapshot: sampleItems, error: nil)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        preview(snapshot: ChatHubSnapshot(items: [], people: [], unmatchedGroupConversationIDs: []), error: nil)
            .previewDisplayName("Empty")
        NavigationStack {
            ChatHubContent(
                snapshot: ChatHubSnapshot(items: [], people: [], unmatchedGroupConversationIDs: []),
                isLoading: true, errorMessage: nil, openingPersonID: nil,
                onRefresh: {}, onOpenChat: { _ in }, onGroupInfo: { _ in },
                onOpenPerson: { _ in }, onCreateGroup: {}, onJoinGroup: {}, onCopyInvite: { _ in }
            )
        }
        .previewDisplayName("Loading")
        preview(snapshot: sampleItems, error: L10n.tr("chat.hub.error.load"))
            .previewDisplayName("Error with cached data")
    }

    private static func preview(snapshot: ChatHubSnapshot, error: String?) -> some View {
        NavigationStack {
            ChatHubContent(
                snapshot: snapshot, isLoading: false, errorMessage: error, openingPersonID: nil,
                onRefresh: {}, onOpenChat: { _ in }, onGroupInfo: { _ in },
                onOpenPerson: { _ in }, onCreateGroup: {}, onJoinGroup: {}, onCopyInvite: { _ in }
            )
        }
    }
}
#endif
