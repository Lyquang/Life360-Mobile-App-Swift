import SwiftUI

struct MemberRowView: View {
    let member: User
    var isCurrentUser = false
    var isOpeningChat = false
    var isMessageDisabled = false
    var onMessageTap: (() -> Void)?

    private var canMessage: Bool { !isCurrentUser && onMessageTap != nil }
    private var presenceKey: String { member.isOnline == true ? "Đang hoạt động" : "Offline" }

    var body: some View {
        if canMessage {
            row
                .contextMenu {
                    Button(action: message) {
                        Label("Nhắn tin", systemImage: "message.fill")
                    }
                    .disabled(isMessageDisabled)
                }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: FTSpacing.md) {
            MemberAvatarView(
                name: member.name,
                size: .medium,
                isOnline: member.isOnline ?? false,
                batteryLevel: member.batteryLevel
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                HStack(spacing: FTSpacing.sm) {
                    Text(member.name)
                        .font(FTFont.subheadline())
                        .foregroundColor(FTColors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if isCurrentUser {
                        Text("Bạn")
                            .font(FTFont.caption())
                            .foregroundColor(FTColors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FTColors.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: FTSpacing.sm) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(member.isOnline == true ? FTColors.accent : FTColors.textTertiary)
                            .frame(width: 6, height: 6)
                        AppLocalizedText(presenceKey)
                            .font(FTFont.caption())
                            .foregroundColor(
                                member.isOnline == true ? FTColors.accent : FTColors.textTertiary
                            )
                    }

                    if let battery = member.batteryLevel {
                        BatteryIndicatorView(level: battery)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)

            if canMessage {
                messageControl
            }
        }
        .padding(.vertical, FTSpacing.xs)
    }

    private var messageControl: some View {
        Button(action: message) {
            Group {
                if isOpeningChat {
                    ProgressView()
                } else {
                    Image(systemName: "message.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(FTColors.primary)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isMessageDisabled)
        .accessibilityLabel(
            L10n.format(isOpeningChat ? "Đang mở cuộc trò chuyện với %@" : "Nhắn tin cho %@", member.name)
        )
        .accessibilityHint(isOpeningChat ? "" : L10n.text("Mở cuộc trò chuyện riêng"))
    }

    private var accessibilitySummary: String {
        var parts = [member.name]
        if isCurrentUser { parts.append(L10n.text("Bạn")) }
        parts.append(L10n.text(presenceKey))
        if let battery = member.batteryLevel {
            parts.append(L10n.format("Pin %lld phần trăm", battery))
        }
        return parts.joined(separator: ", ")
    }

    private func message() {
        guard !isMessageDisabled else { return }
        onMessageTap?()
    }
}

#Preview("Online") {
    List {
        MemberRowView(
            member: User(id: "member-1", name: "Nguyễn Ánh", email: "member@example.com",
                         batteryLevel: 82, isOnline: true),
            onMessageTap: {}
        )
    }
}

#Preview("Offline and low battery") {
    List {
        MemberRowView(
            member: User(id: "member-2", name: "Bảo Ngọc", email: "member@example.com",
                         batteryLevel: 9, isOnline: false),
            onMessageTap: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Current user") {
    List {
        MemberRowView(
            member: User(id: "me", name: "Minh Quang", email: "me@example.com",
                         batteryLevel: 95, isOnline: true),
            isCurrentUser: true
        )
    }
}

#Preview("Opening chat") {
    List {
        MemberRowView(
            member: User(id: "member-3", name: "Anh Quang", email: "member@example.com",
                         batteryLevel: 74, isOnline: true),
            isOpeningChat: true,
            isMessageDisabled: true,
            onMessageTap: {}
        )
    }
}

#Preview("Long name and accessibility type") {
    List {
        MemberRowView(
            member: User(
                id: "member-4",
                name: "Nguyễn Hoàng Minh Anh Với Một Cái Tên Rất Dài",
                email: "member@example.com",
                batteryLevel: 41,
                isOnline: false
            ),
            onMessageTap: {}
        )
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
