import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var showLogoutConfirm = false
    let onNotifications: () -> Void

    init(viewModel: @autoclosure @escaping () -> ProfileViewModel, onNotifications: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onNotifications = onNotifications
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: FTSpacing.md) {
                        MemberAvatarView(name: viewModel.user.name, size: .xlarge, isOnline: true, batteryLevel: nil)

                        VStack(alignment: .leading, spacing: FTSpacing.xs) {
                            Text(viewModel.user.name)
                                .font(FTFont.title3())
                            Text(viewModel.user.email)
                                .font(FTFont.subheadline())
                                .foregroundColor(FTColors.textSecondary)
                            Label("Đang hoạt động", systemImage: "circle.fill")
                                .font(FTFont.caption())
                                .foregroundColor(FTColors.accent)
                        }
                    }
                    .padding(.vertical, FTSpacing.sm)
                }

                Section("Cài đặt") {
                    LanguagePicker()
                    Button(action: onNotifications) { Label("Thông báo", systemImage: "bell.badge") }
                }

                Section("Thông tin ứng dụng") {
                    InfoRow(label: "Phiên bản", value: viewModel.appVersion)
                    InfoRow(label: "Backend", value: viewModel.backendHost)
                    HStack {
                        Text("Socket")
                        Spacer()
                        AppLocalizedText(viewModel.connectionLabel)
                            .font(FTFont.footnote())
                            .foregroundColor(FTColors.textSecondary)
                    }
                }

                #if DEBUG
                Section("Developer") {
                    NavigationLink {
                        NetworkInspectorView()
                    } label: {
                        Label("Network Inspector", systemImage: "network")
                    }
                }
                #endif

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Tài khoản")
        }
        .onAppear { viewModel.start() }
        .confirmationDialog("Đăng xuất khỏi FamilyTracker?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive, action: viewModel.logout)
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bạn sẽ cần đăng nhập lại để sử dụng ứng dụng.")
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            AppLocalizedText(label)
                .foregroundColor(FTColors.textPrimary)
            Spacer()
            Text(value)
                .font(FTFont.footnote())
                .foregroundColor(FTColors.textSecondary)
        }
    }
}
