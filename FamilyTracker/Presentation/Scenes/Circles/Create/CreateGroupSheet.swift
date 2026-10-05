import SwiftUI

struct CreateGroupSheet: View {
    @ObservedObject var viewModel: CircleListViewModel
    let onClose: () -> Void

    @State private var groupName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(FTColors.primaryGradient)
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .padding(.top, FTSpacing.lg)

                    VStack(spacing: FTSpacing.xs) {
                        Text("Tạo nhóm mới")
                            .font(FTFont.title3())
                        Text("Thêm thành viên bằng mã mời được tạo tự động")
                            .font(FTFont.subheadline())
                            .foregroundColor(FTColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: FTSpacing.md) {
                        FTTextField(title: "Tên nhóm", placeholder: "VD: Gia đình Nguyễn", icon: "person.3.fill", text: $groupName)

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(FTFont.caption())
                                .foregroundColor(FTColors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, FTSpacing.md)

                    HStack(spacing: FTSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(FTColors.primary)
                        Text("Sau khi tạo, bạn sẽ nhận được mã mời 6 chữ số để chia sẻ với gia đình.")
                            .font(FTFont.caption())
                            .foregroundColor(FTColors.textSecondary)
                    }
                    .padding(FTSpacing.md)
                    .background(FTColors.primary.opacity(0.08))
                    .cornerRadius(FTRadius.md)
                    .padding(.horizontal, FTSpacing.md)

                    FTButton(title: "Tạo nhóm", isLoading: viewModel.isLoading) {
                        Task {
                            if await viewModel.createGroup(name: groupName) { onClose() }
                        }
                    }
                    .padding(.horizontal, FTSpacing.md)
                }
            }
            .navigationTitle("Tạo nhóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy", action: onClose)
                }
            }
        }
        .onDisappear { viewModel.errorMessage = nil }
        .hideKeyboardOnTap()
    }
}
