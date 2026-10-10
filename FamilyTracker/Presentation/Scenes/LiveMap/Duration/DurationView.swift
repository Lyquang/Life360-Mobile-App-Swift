// MARK: - DurationView.swift
// Tab "Ở đây": how long each member has been stationary + milestone alerts (Feature 1).

import SwiftUI

struct DurationView: View {
    @StateObject private var viewModel: DurationViewModel

    init(viewModel: @autoclosure @escaping () -> DurationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                FTColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView {
                        LazyVStack(spacing: FTSpacing.md) {
                            if viewModel.memberLocations.isEmpty {
                                FTEmptyView(
                                    icon: "clock.badge.questionmark",
                                    title: "Chưa có dữ liệu",
                                    subtitle: "Dữ liệu thời gian đứng yên sẽ xuất hiện khi các thành viên bật GPS.",
                                    actionTitle: nil,
                                    action: nil
                                )
                                .padding(.top, FTSpacing.xxl)
                            } else {
                                ForEach(viewModel.memberLocations) { member in
                                    DurationMemberCard(member: member)
                                }
                            }
                        }
                        .padding(FTSpacing.md)
                    }
                }

                if !viewModel.stayAlerts.isEmpty {
                    VStack {
                        StayAlertStack(
                            alerts: $viewModel.stayAlerts,
                            onNavigate: nil,
                            onDismiss: viewModel.dismiss
                        )
                        .padding(.top, FTSpacing.sm)
                        Spacer()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { viewModel.start() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Đang ở đâu")
                    .font(FTFont.title2())
                    .foregroundColor(FTColors.textPrimary)
                Text("Thời gian thành viên đứng yên")
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)
            }
            Spacer()
            HStack(spacing: FTSpacing.sm) {
                legendDot(color: FTColors.accent, label: "< 1 giờ")
                legendDot(color: FTColors.warning, label: "1–4 giờ")
                legendDot(color: FTColors.danger, label: "> 4 giờ")
            }
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.top, FTSpacing.md)
        .padding(.bottom, FTSpacing.sm)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 8, height: 8)
            AppLocalizedText(label).font(.system(size: 10)).foregroundColor(FTColors.textTertiary)
        }
    }
}

struct DurationMemberCard: View {
    @Environment(\.locale) private var locale
    let member: MemberLocation

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            MemberAvatarWithDuration(location: member, onTap: {})

            VStack(alignment: .leading, spacing: 6) {
                Text(member.name)
                    .font(FTFont.headline())
                    .foregroundColor(FTColors.textPrimary)

                if member.isStaying {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text("Đã ở đây \(L10n.duration(minutes: member.durationAtLocation ?? 0, language: AppLanguage(locale: locale)))")
                            .font(FTFont.subheadline())
                    }
                    .foregroundColor(stayColor)

                    if ISO8601.date(from: member.durationSince) != nil {
                        Text("Từ lúc \(DisplayFormat.time(iso: member.durationSince))")
                            .font(FTFont.caption())
                            .foregroundColor(FTColors.textSecondary)
                    }
                } else {
                    Text("Đang di chuyển")
                        .font(FTFont.subheadline())
                        .foregroundColor(FTColors.textTertiary)
                }

                if let battery = member.batteryLevel {
                    Label("\(battery)%", systemImage: member.batteryIconName)
                        .font(FTFont.caption())
                        .foregroundColor(battery < 20 ? FTColors.danger : FTColors.textTertiary)
                }
            }

            Spacer()

            if member.isStaying {
                DurationBadgeLarge(member: member)
            }
        }
        .padding(FTSpacing.md)
        .ftCard()
    }

    private var stayColor: Color {
        DisplayFormat.stayColor(minutes: member.durationAtLocation ?? 0)
    }
}
