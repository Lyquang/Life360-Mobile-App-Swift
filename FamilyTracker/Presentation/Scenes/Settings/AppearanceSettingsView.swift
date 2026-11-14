import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var settings: AppearanceSettings
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            Section {
                ForEach(AppAppearance.allCases) { appearance in
                    Button { settings.select(appearance) } label: {
                        HStack(spacing: FTSpacing.md) {
                            Image(systemName: appearance.symbol).font(.system(size: 22))
                                .foregroundColor(FTColors.primary)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                                AppLocalizedText(appearance.key).font(FTFont.body())
                                AppLocalizedText(appearance.descriptionKey)
                                    .font(FTFont.footnote()).foregroundColor(FTColors.textSecondary)
                            }
                            Spacer(minLength: FTSpacing.sm)
                            Image(systemName: settings.selection == appearance ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(settings.selection == appearance ? FTColors.primary : FTColors.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .foregroundColor(FTColors.textPrimary)
                        .frame(minHeight: FTControl.minimumTarget)
                        .padding(.vertical, FTSpacing.xs)
                    }
                    .accessibilityIdentifier("appearance.\(appearance.rawValue)")
                    .accessibilityAddTraits(settings.selection == appearance ? .isSelected : [])
                }
            } footer: {
                AppLocalizedText("appearance.footer.device")
            }
        }
        .navigationTitle(Text(verbatim: L10n.tr("appearance.title", language: AppLanguage(locale: locale))))
        .navigationBarTitleDisplayMode(.inline)
    }
}
