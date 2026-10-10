import SwiftUI

struct ConversationListView: View {
    @ObservedObject var viewModel: ConversationListViewModel
    let onSelect: (Conversation) -> Void

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                ProgressView("Đang tải hội thoại...")
                    .progressViewStyle(CircularProgressViewStyle(tint: FTColors.primary))
            } else if viewModel.conversations.isEmpty {
                FTEmptyView(
                    icon: "bubble.left.and.bubble.right",
                    title: "Chưa có cuộc trò chuyện",
                    subtitle: viewModel.errorMessage ?? "Mỗi nhóm có sẵn một phòng chat chung.",
                    actionTitle: "Tải lại",
                    action: { Task { await viewModel.load() } }
                )
            } else {
                List(viewModel.conversations) { conversation in
                    Button { onSelect(conversation) } label: {
                        ConversationRow(conversation: conversation)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Tin nhắn")
        .task {
            viewModel.start()
            await viewModel.load()
        }
    }
}

private struct ConversationRow: View {
    @Environment(\.locale) private var locale
    let conversation: Conversation

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle()
                    .fill(FTColors.primaryGradient)
                    .frame(width: 48, height: 48)
                Image(systemName: conversation.type == .group ? "person.3.fill" : "person.fill")
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName)
                        .font(FTFont.headline())
                        .foregroundColor(FTColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let date = conversation.lastMessageAt {
                        Text(DisplayFormat.time(date))
                            .font(FTFont.caption())
                            .foregroundColor(FTColors.textTertiary)
                    }
                }
                HStack {
                    Text(preview)
                        .font(FTFont.subheadline())
                        .foregroundColor(FTColors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(FTFont.caption())
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(FTColors.danger)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, FTSpacing.xs)
        .contentShape(Rectangle())
    }

    private var preview: String {
        guard let message = conversation.lastMessage else { return L10n.text("Chưa có tin nhắn", language: AppLanguage(locale: locale)) }
        let sender = message.senderName.map { "\($0): " } ?? ""
        return sender + (message.type == .image ? L10n.text("📷 Hình ảnh", language: AppLanguage(locale: locale)) : message.content)
    }
}
