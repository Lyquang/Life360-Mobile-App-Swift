// MARK: - CircleListView.swift
// Danh sách nhóm. Sheets (tạo/tham gia/chi tiết) do CirclesCoordinator điều phối.

import SwiftUI

struct CircleListView: View {
    @ObservedObject var viewModel: CircleListViewModel
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onSelect: (FamilyGroup) -> Void

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
                } else if viewModel.groups.isEmpty {
                    Spacer()
                    FTEmptyView(
                        icon: "person.3.fill",
                        title: "Chưa có nhóm nào",
                        subtitle: "Tạo nhóm mới hoặc tham gia bằng mã mời từ người thân",
                        actionTitle: "Tạo nhóm đầu tiên",
                        action: onCreate
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: FTSpacing.md) {
                            ForEach(viewModel.groups) { group in
                                GroupCard(group: group) { onSelect(group) }
                            }
                        }
                        .padding(FTSpacing.md)
                    }
                    .refreshable { await viewModel.loadGroups() }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.startObservingPresence()
            await viewModel.loadGroups()
        }
        .ftSuccessToast($viewModel.successMessage)
        .ftErrorAlert($viewModel.loadErrorMessage)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nhóm của tôi")
                    .font(FTFont.title2())
                    .foregroundColor(FTColors.textPrimary)
                Text("\(viewModel.groups.count) nhóm")
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)
            }

            Spacer()

            HStack(spacing: FTSpacing.sm) {
                Button(action: onJoin) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FTColors.primary)
                        .frame(width: 40, height: 40)
                        .background(FTColors.primary.opacity(0.12))
                        .clipShape(Circle())
                }

                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(FTColors.primaryGradient)
                        .clipShape(Circle())
                        .shadow(color: FTColors.primary.opacity(0.4), radius: 8)
                }
            }
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.top, FTSpacing.md)
        .padding(.bottom, FTSpacing.sm)
    }
}
