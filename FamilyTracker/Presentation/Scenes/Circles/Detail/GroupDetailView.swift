import SwiftUI

/// Group details + member list (presented as a sheet by CirclesCoordinator).
struct GroupDetailView: View {
    let group: FamilyGroup
    @ObservedObject var viewModel: CircleListViewModel
    let onOpenChat: (() -> Void)?
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
                                Text("Mã mời nhóm")
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
                                Label("Nhắn tin nhóm", systemImage: "bubble.left.and.bubble.right.fill")
                                    .font(FTFont.subheadline())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FTColors.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Thành viên (\(viewModel.members.count))") {
                    if viewModel.isMembersLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.members) { member in
                            MemberRowView(member: member)
                        }
                    }
                }
            }
            .navigationTitle("Chi tiết nhóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onClose)
                }
            }
        }
    }
}
