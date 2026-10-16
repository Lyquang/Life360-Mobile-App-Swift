import SwiftUI

/// Group details + member list, presented by ChatHubCoordinator.
struct GroupDetailView: View {
    let group: FamilyGroup
    @ObservedObject var viewModel: CircleListViewModel
    let currentUserId: String
    let onOpenChat: (() -> Void)?
    let onMessageMember: (User) -> Void
    let onRetryMembers: () -> Void
    let onRetryDirectChat: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: FTSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(FTColors.primaryGradient)
                                .frame(width: 80, height: 80)
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }

                        Text(group.name)
                            .font(FTFont.title3())

                        if let code = group.inviteCode {
                            VStack(spacing: FTSpacing.xs) {
                                Text(verbatim: L10n.tr("groups.invite_code.title"))
                                    .font(FTFont.caption())
                                    .foregroundColor(FTColors.textSecondary)
                                HStack(spacing: FTSpacing.sm) {
                                    Text(code)
                                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                                        .foregroundColor(FTColors.primary)
                                        .tracking(8)
                                    Button {
                                        UIPasteboard.general.string = code
                                    } label: {
                                        Image(systemName: "doc.on.doc.fill")
                                            .foregroundColor(FTColors.primary)
                                    }
                                }
                                .padding(FTSpacing.md)
                                .background(FTColors.primary.opacity(0.08))
                                .cornerRadius(FTRadius.md)
                            }
                        }

                        if let onOpenChat {
                            Button(action: onOpenChat) {
                                Label {
                                    Text(verbatim: L10n.tr("groups.action.chat"))
                                } icon: {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                }
                                    .font(FTFont.subheadline())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FTColors.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section(L10n.plural("members.count", count: viewModel.members.count)) {
                    if viewModel.isMembersLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let error = viewModel.membersErrorMessage {
                        VStack(alignment: .leading, spacing: FTSpacing.sm) {
                            Text(error)
                                .foregroundColor(FTColors.textSecondary)
                            Button(L10n.tr("common.action.retry"), action: onRetryMembers)
                        }
                    } else {
                        ForEach(viewModel.members) { member in
                            let isCurrentUser = member.id == currentUserId
                            MemberRowView(
                                member: member,
                                isCurrentUser: isCurrentUser,
                                isOpeningChat: viewModel.openingDirectMemberId == member.id,
                                isMessageDisabled: viewModel.isOpeningDirectChat,
                                onMessageTap: isCurrentUser ? nil : { onMessageMember(member) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !isCurrentUser {
                                    Button {
                                        onMessageMember(member)
                                    } label: {
                                        Label {
                                            Text(verbatim: L10n.tr("members.action.message"))
                                        } icon: {
                                            Image(systemName: "message.fill")
                                        }
                                    }
                                    .tint(FTColors.primary)
                                    .disabled(viewModel.isOpeningDirectChat)
                                }
                            }
                        }

                        if isCurrentUserOnly {
                            AppLocalizedText(
                                group.inviteCode == nil
                                    ? "Hãy mời thêm người thân vào nhóm."
                                    : "Hãy chia sẻ mã mời phía trên để thêm người thân."
                            )
                            .font(FTFont.footnote())
                            .foregroundColor(FTColors.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle(Text(verbatim: L10n.tr("groups.detail.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("common.action.close"), action: onClose)
                }
            }
        }
        .alert(item: $viewModel.directChatFailure) { failure in
            Alert(
                title: Text(verbatim: L10n.tr("chat.direct.open_failed")),
                message: Text(verbatim: failure.message),
                primaryButton: .default(Text(verbatim: L10n.tr("common.action.retry")), action: onRetryDirectChat),
                secondaryButton: .cancel(Text(verbatim: L10n.tr("common.action.close")))
            )
        }
    }

    private var isCurrentUserOnly: Bool {
        viewModel.members.count == 1 && viewModel.members.first?.id == currentUserId
    }
}
