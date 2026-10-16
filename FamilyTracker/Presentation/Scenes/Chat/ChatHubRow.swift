import SwiftUI

struct ChatHubRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let item: ChatHubItem
    let language: AppLanguage
    let now: Date
    let onOpen: () -> Void
    let onInfo: (() -> Void)?

    private var largeText: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .trailing, spacing: FTSpacing.xs) {
            HStack(alignment: .top, spacing: FTSpacing.sm) {
                Button(action: onOpen) {
                    mainContent
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint(item.conversationId == nil
                    ? L10n.tr("chat.hub.accessibility.open_info", language: language) : "")

                if !largeText, let onInfo {
                    infoButton(onInfo)
                }
            }

            if largeText {
                HStack(spacing: FTSpacing.sm) {
                    Spacer(minLength: 0)
                    timestamp
                    unreadBadge
                    if let onInfo { infoButton(onInfo) }
                }
            }
        }
        .padding(.vertical, FTSpacing.xs)
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            avatar
            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: FTSpacing.sm) {
                    Text(verbatim: item.title)
                        .font(.headline)
                        .fontWeight(item.unreadCount > 0 ? .bold : .semibold)
                        .foregroundColor(FTColors.textPrimary)
                        .lineLimit(largeText ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !largeText { timestamp }
                }

                HStack(alignment: .firstTextBaseline, spacing: FTSpacing.sm) {
                    Text(verbatim: ChatHubFormat.preview(item.lastMessage, language: language))
                        .font(.subheadline)
                        .fontWeight(item.unreadCount > 0 ? .semibold : .regular)
                        .foregroundColor(FTColors.textSecondary)
                        .lineLimit(largeText ? 2 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !largeText { unreadBadge }
                }

                if item.kind == .group {
                    Text(verbatim: groupStatus)
                        .font(.caption)
                        .foregroundColor(FTColors.textSecondary)
                        .lineLimit(largeText ? 2 : 1)
                } else if let isOnline = item.isOnline {
                    Text(verbatim: L10n.tr(
                        isOnline ? "chat.hub.presence.online" : "chat.hub.presence.offline",
                        language: language
                    ))
                    .font(.caption)
                    .foregroundColor(FTColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var avatar: some View {
        if item.kind == .group {
            ZStack {
                Circle().fill(FTColors.primary).frame(width: 48, height: 48)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)
        } else {
            MemberAvatarView(name: item.title, size: .medium,
                             isOnline: item.isOnline == true, batteryLevel: nil)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var timestamp: some View {
        if let text = ChatHubFormat.timestamp(item.lastMessageAt, now: now,
                                              language: language, calendar: calendar) {
            Text(verbatim: text)
                .font(.caption)
                .foregroundColor(FTColors.textTertiary)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var unreadBadge: some View {
        if item.unreadCount > 0 {
            Text(verbatim: item.unreadCount > 99 ? "99+" : "\(item.unreadCount)")
                .font(.caption)
                .foregroundColor(.white)
                .frame(minWidth: 22, minHeight: 22)
                .background(FTColors.danger, in: Capsule())
                .accessibilityHidden(true)
        }
    }

    private func infoButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.system(size: 20))
                .foregroundColor(FTColors.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(L10n.tr("chat.hub.action.group_info", language: language))
        .help(L10n.tr("chat.hub.action.group_info", language: language))
    }

    private var groupStatus: String {
        guard let members = item.memberCount, let online = item.onlineCount else {
            return L10n.tr("chat.hub.members.unavailable", language: language)
        }
        return "\(L10n.plural("members.count", count: members, language: language)) · "
            + L10n.plural("presence.online_count", count: online, language: language)
    }

    private var accessibilitySummary: String {
        var parts = [item.title, L10n.tr(item.kind == .group
            ? "chat.hub.kind.group" : "chat.hub.kind.direct", language: language)]
        if item.kind == .group { parts.append(groupStatus) }
        else if let online = item.isOnline {
            parts.append(L10n.tr(online ? "chat.hub.presence.online" : "chat.hub.presence.offline",
                                 language: language))
        }
        if item.unreadCount > 0 {
            parts.append(L10n.tr("chat.hub.accessibility.unread", item.unreadCount, language: language))
        }
        parts.append(ChatHubFormat.preview(item.lastMessage, language: language))
        if let time = ChatHubFormat.timestamp(item.lastMessageAt, now: now,
                                              language: language, calendar: calendar) {
            parts.append(time)
        }
        return parts.joined(separator: ", ")
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = language.locale
        calendar.timeZone = .current
        return calendar
    }
}

#if DEBUG
private struct ChatHubRowPreviews: PreviewProvider {
    static var previews: some View {
        List {
            ChatHubRow(item: group(message: .image), language: .vietnamese,
                       now: Date(), onOpen: {}, onInfo: {})
            ChatHubRow(item: group(message: nil), language: .vietnamese,
                       now: Date(), onOpen: {}, onInfo: {})
            ChatHubRow(item: direct(message: .text), language: .vietnamese,
                       now: Date(), onOpen: {}, onInfo: nil)
            ChatHubRow(item: direct(message: .text, online: true), language: .vietnamese,
                       now: Date(), onOpen: {}, onInfo: nil)
            ChatHubRow(item: direct(message: .voice), language: .vietnamese,
                       now: Date(), onOpen: {}, onInfo: nil)
        }
        .previewDisplayName("Image, text, voice, offline")

        List {
            ChatHubRow(item: direct(message: .voice), language: .vietnamese,
                       now: Date(), onOpen: {}, onInfo: nil)
        }
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Long name at largest text")
    }

    private static func group(message type: ChatMessageType?) -> ChatHubItem {
        ChatHubItem(id: "group:g1", kind: .group, conversationId: "c1", groupId: "g1",
                    inviteCode: "123456", title: "Gia đình Quang", lastMessage: message(type),
                    lastMessageAt: type == nil ? nil : Date(), createdAt: nil,
                    unreadCount: type == nil ? 0 : 2, memberCount: 3, onlineCount: 2, isOnline: nil)
    }

    private static func direct(message type: ChatMessageType, online: Bool = false) -> ChatHubItem {
        ChatHubItem(id: "conversation:d1", kind: .direct, conversationId: "d1", groupId: nil,
                    inviteCode: nil,
                    title: "Nguyễn Thị Thanh Nhật Quang với tên rất dài để kiểm tra bố cục",
                    lastMessage: message(type), lastMessageAt: Date(), createdAt: nil,
                    unreadCount: 1, memberCount: nil, onlineCount: nil, isOnline: online)
    }

    private static func message(_ type: ChatMessageType?) -> ChatMessage? {
        guard let type else { return nil }
        return ChatMessage(id: "m1", conversationId: "c1", senderId: "u2", senderName: "Đạt",
                           type: type, content: type == .text ? "Xin chào cả nhà" : "",
                           attachment: nil, mediaUrl: nil, duration: nil, fileSize: nil,
                           mimeType: nil, createdAt: Date())
    }
}
#endif
