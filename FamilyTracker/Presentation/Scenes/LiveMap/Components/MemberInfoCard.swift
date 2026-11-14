import SwiftUI

enum MemberLocationText {
    static func updated(_ timestamp: String, language: AppLanguage) -> String {
        guard let date = ISO8601.date(from: timestamp) else {
            return L10n.tr("map.member.unknown_time", language: language)
        }
        let formatted: String
        if Calendar.current.isDateInToday(date) {
            formatted = L10n.time(date, language: language)
        } else {
            let formatter = DateFormatter()
            formatter.locale = language.locale
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatted = formatter.string(from: date)
        }
        return L10n.tr("members.updated_at", formatted, language: language)
    }
}

/// Contents of the map's selected-member panel. The parent owns scrolling/height.
struct MemberInfoCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize
    let member: MemberLocation
    let onDismiss: () -> Void
    let onNavigate: () -> Void
    let onShowJourney: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(alignment: .top, spacing: FTSpacing.md) {
                MemberAvatarView(name: member.name, size: .large, isOnline: nil, batteryLevel: nil)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    Text(verbatim: member.name).font(FTFont.title2())
                    Text(verbatim: MemberLocationText.updated(member.timestamp, language: AppLanguage(locale: locale)))
                        .font(FTFont.subheadline()).foregroundColor(FTColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .medium))
                        .frame(width: FTControl.minimumTarget, height: FTControl.minimumTarget)
                        .background(FTColors.surface, in: Circle())
                }
                .accessibilityLabel(Text(verbatim: L10n.tr("common.action.close", language: AppLanguage(locale: locale))))
            }
            actionLayout {
                Label {
                    AppLocalizedText("map.member.recorded_position")
                } icon: { Image(systemName: "mappin.circle").accessibilityHidden(true) }
                    .font(FTFont.body())
                Spacer(minLength: 0)
                if let battery = member.batteryLevel {
                    Label {
                        Text(verbatim: L10n.tr("common.battery_percent", battery, language: AppLanguage(locale: locale)))
                    } icon: { Image(systemName: "battery.100").accessibilityHidden(true) }
                        .font(FTFont.subheadline()).foregroundColor(FTColors.textSecondary)
                }
            }
            AppLocalizedText("map.member.recorded_hint")
                .font(FTFont.footnote()).foregroundColor(FTColors.textSecondary)
            DisclosureGroup {
                Text(verbatim: L10n.tr("common.coordinates", String(format: "%.4f", member.latitude),
                                      String(format: "%.4f", member.longitude), language: AppLanguage(locale: locale)))
                    .font(FTFont.footnote())
                    .textSelection(.enabled)
            } label: { AppLocalizedText("map.member.coordinates") }
                .font(FTFont.footnote())
            actionLayout {
                FTButton(title: "map.action.view_position", isLoading: false, action: onNavigate)
                FTButton(title: "map.action.journey", isLoading: false, action: onShowJourney, style: .outline)
            }
        }
        .foregroundColor(FTColors.textPrimary)
        .padding(FTSpacing.md)
        .accessibilityIdentifier("map.member_detail")
    }

    private var actionLayout: AnyLayout {
        textSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: FTSpacing.sm))
            : AnyLayout(HStackLayout(spacing: FTSpacing.sm))
    }
}
