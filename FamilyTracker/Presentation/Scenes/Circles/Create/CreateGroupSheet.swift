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
                        Text(verbatim: L10n.tr("circles.create.title"))
                            .font(FTFont.title3())
                        Text(verbatim: L10n.tr("circles.create.subtitle"))
                            .font(FTFont.subheadline())
                            .foregroundColor(FTColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: FTSpacing.md) {
                        FTTextField(title: "Tên nhóm", placeholder: "VD: Gia đình Nguyễn", icon: "person.3.fill", text: $groupName)

                        if let error = viewModel.errorMessage {
                            Text(verbatim: L10n.message(error))
                                .font(FTFont.caption())
                                .foregroundColor(FTColors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, FTSpacing.md)

                    HStack(spacing: FTSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(FTColors.primary)
                        Text(verbatim: L10n.tr("circles.create.invite_hint"))
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
            .navigationTitle(Text(verbatim: L10n.tr("circles.create.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onClose) { Text(verbatim: L10n.tr("common.cancel")) }
                }
            }
        }
        .onDisappear { viewModel.errorMessage = nil }
        .hideKeyboardOnTap()
    }
}
