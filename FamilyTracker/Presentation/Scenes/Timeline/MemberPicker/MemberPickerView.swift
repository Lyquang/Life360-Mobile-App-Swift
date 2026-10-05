// MARK: - MemberPickerView.swift
// Tab "Lộ trình": pick a member to view their day journey (Feature 2).

import SwiftUI

struct MemberPickerView: View {
    @ObservedObject var viewModel: MemberPickerViewModel
    let onSelectMember: (_ userId: String, _ name: String) -> Void
    let onShowHistory: () -> Void

    var body: some View {
        ZStack {
            FTColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if viewModel.isLoading && viewModel.groups.isEmpty {
                    Spacer()
                    ProgressView("Đang tải nhóm...")
                        .progressViewStyle(CircularProgressViewStyle(tint: FTColors.primary))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: FTSpacing.md) {
                            JourneyMemberRow(name: viewModel.currentUser.name, subtitle: "Lộ trình của tôi hôm nay", isMe: true) {
                                onSelectMember(viewModel.currentUser.id, viewModel.currentUser.name)
                            }

                            if viewModel.groups.isEmpty {
                                FTEmptyView(
                                    icon: "figure.walk.motion",
                                    title: "Chưa có nhóm",
                                    subtitle: "Tham gia hoặc tạo nhóm để xem lộ trình thành viên.",
                                    actionTitle: nil,
                                    action: nil
                                )
                            }

                            ForEach(viewModel.groups) { group in
                                GroupJourneySection(
                                    group: group,
                                    members: viewModel.otherMembers(of: group),
                                    isLoading: viewModel.loadingGroupIds.contains(group.id),
                                    onSelectMember: onSelectMember
                                )
                            }
                        }
                        .padding(FTSpacing.md)
                    }
                    .refreshable { await viewModel.load() }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.groups.isEmpty { await viewModel.load() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lộ trình hôm nay")
                    .font(FTFont.title2())
                    .foregroundColor(FTColors.textPrimary)
                Text("Chọn thành viên để xem hành trình")
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)
            }
            Spacer()
            Button(action: onShowHistory) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 24))
                    .foregroundColor(FTColors.primary)
            }
            .accessibilityLabel("Lịch sử vị trí hôm nay")
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.top, FTSpacing.md)
        .padding(.bottom, FTSpacing.sm)
    }
}

struct JourneyMemberRow: View {
    let name: String
    let subtitle: String
    let isMe: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: FTSpacing.md) {
                ZStack {
                    Circle()
                        .fill(isMe ? FTColors.primaryGradient : LinearGradient(
                            colors: [FTColors.accent, FTColors.accent.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 46, height: 46)
                    Text(String(name.prefix(2)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(name)
                            .font(FTFont.headline())
                            .foregroundColor(FTColors.textPrimary)
                        if isMe {
                            Text("Tôi")
                                .font(FTFont.caption())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FTColors.primary)
                                .cornerRadius(FTRadius.full)
                        }
                    }
                    Text(subtitle)
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(FTColors.textTertiary)
            }
            .padding(FTSpacing.md)
            .ftCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GroupJourneySection: View {
    let group: FamilyGroup
    let members: [User]
    let isLoading: Bool
    let onSelectMember: (_ userId: String, _ name: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 14))
                    .foregroundColor(FTColors.primary)
                Text(group.name)
                    .font(FTFont.subheadline())
                    .foregroundColor(FTColors.textPrimary)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, FTSpacing.sm)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(members) { member in
                    JourneyMemberRow(
                        name: member.name,
                        subtitle: member.isOnline == true ? "🟢 Đang online" : "⚫ Offline",
                        isMe: false,
                        onTap: { onSelectMember(member.id, member.name) }
                    )
                }
            }
        }
    }
}
