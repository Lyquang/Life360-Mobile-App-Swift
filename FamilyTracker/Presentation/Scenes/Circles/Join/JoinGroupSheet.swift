import SwiftUI

struct JoinGroupSheet: View {
    @ObservedObject var viewModel: CircleListViewModel
    let onClose: () -> Void

    @State private var inviteCode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: FTSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(FTColors.accent.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(FTColors.accent)
                }
                .padding(.top, FTSpacing.lg)

                VStack(spacing: FTSpacing.xs) {
                    Text(verbatim: L10n.tr("groups.join.title"))
                        .font(FTFont.title3())
                    Text(verbatim: L10n.tr("groups.join.subtitle"))
                        .font(FTFont.subheadline())
                        .foregroundColor(FTColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: FTSpacing.sm) {
                    Text(verbatim: L10n.tr("groups.invite_code.title"))
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField(text: $inviteCode) {
                        Text(verbatim: "123456")
                    }
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .tracking(8)
                        .onChange(of: inviteCode) { newValue in
                            let sanitized = String(newValue.filter(\.isNumber).prefix(6))
                            if sanitized != newValue { inviteCode = sanitized }
                            viewModel.errorMessage = nil
                        }
                        .padding(FTSpacing.md)
                        .background(FTColors.surface)
                        .cornerRadius(FTRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: FTRadius.md)
                                .stroke(inviteCode.count == 6 ? FTColors.accent : FTColors.primary.opacity(0.3), lineWidth: 2)
                        )

                    Text(verbatim: L10n.tr("groups.invite_code.length", inviteCode.count))
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, FTSpacing.md)

                if let error = viewModel.errorMessage {
                    HStack(spacing: FTSpacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(verbatim: L10n.message(error))
                    }
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.danger)
                    .padding(.horizontal, FTSpacing.md)
                }

                FTButton(title: "Tham gia nhóm", isLoading: viewModel.isLoading) {
                    Task {
                        if await viewModel.joinGroup(inviteCode: inviteCode) { onClose() }
                    }
                }
                .padding(.horizontal, FTSpacing.md)
                .disabled(inviteCode.count != 6)
                .opacity(inviteCode.count == 6 ? 1.0 : 0.5)

                Spacer()
            }
            .navigationTitle(Text(verbatim: L10n.tr("groups.join.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("common.cancel"), action: onClose)
                }
            }
        }
        .onDisappear { viewModel.errorMessage = nil }
        .hideKeyboardOnTap()
    }
}
