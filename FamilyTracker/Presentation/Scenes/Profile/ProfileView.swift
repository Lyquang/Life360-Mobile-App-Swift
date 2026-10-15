import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var showLogoutConfirm = false
    @State private var showLogoutAllConfirm = false

    init(viewModel: @autoclosure @escaping () -> ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
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
                            Label {
                                Text(verbatim: L10n.tr("presence.profile.active"))
                            } icon: {
                                Image(systemName: "circle.fill")
                            }
                                .font(FTFont.caption())
                                .foregroundColor(FTColors.accent)
                        }
                    }
                    .padding(.vertical, FTSpacing.sm)
                }

                Section(L10n.tr("profile.section.settings")) {
                    LanguagePicker()
                }

                Section(L10n.tr("profile.section.app_info")) {
                    InfoRow(label: "Phiên bản", value: viewModel.appVersion)
                    InfoRow(label: "Backend", value: viewModel.backendHost)
                    HStack {
                        Text(verbatim: L10n.tr("profile.socket"))
                        Spacer()
                        AppLocalizedText(viewModel.connectionLabel)
                            .font(FTFont.footnote())
                            .foregroundColor(FTColors.textSecondary)
                    }
                }

                #if DEBUG
                Section(L10n.tr("profile.section.developer")) {
                    NavigationLink {
                        NetworkInspectorView()
                    } label: {
                        Label {
                            Text(verbatim: L10n.tr("profile.network_inspector"))
                        } icon: {
                            Image(systemName: "network")
                        }
                    }
                }
                #endif

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label {
                            Text(verbatim: L10n.tr("profile.logout"))
                        } icon: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    Button(role: .destructive) {
                        showLogoutAllConfirm = true
                    } label: {
                        Label {
                            Text(verbatim: L10n.tr("profile.logout_all"))
                        } icon: {
                            Image(systemName: "rectangle.stack.badge.minus")
                        }
                    }
                }
            }
            .navigationTitle(Text(verbatim: L10n.tr("profile.title")))
        }
        .onAppear { viewModel.start() }
        .confirmationDialog(Text(verbatim: L10n.tr("profile.logout.confirm_title")), isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button(L10n.tr("profile.logout"), role: .destructive, action: viewModel.logout)
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(verbatim: L10n.tr("profile.logout.confirm_message"))
        }
        .confirmationDialog(Text(verbatim: L10n.tr("profile.logout_all.confirm_title")), isPresented: $showLogoutAllConfirm,
                            titleVisibility: .visible) {
            Button(L10n.tr("profile.logout_all"), role: .destructive, action: viewModel.logoutAll)
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(verbatim: L10n.tr("profile.logout_all.confirm_message"))
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
