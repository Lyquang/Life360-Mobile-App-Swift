import SwiftUI

struct LiveMapHeader: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize
    let memberCount: Int
    let onMembers: () -> Void
    let onSearch: () -> Void

    var body: some View {
        VStack(spacing: FTSpacing.sm) {
            headerLayout {
                Text(verbatim: "FamilyTracker").font(FTFont.title3()).accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onMembers) {
                    Label {
                        Text(verbatim: memberCount.formatted(.number.locale(locale)))
                    } icon: { Image(systemName: "person.2").font(.system(size: 20)).accessibilityHidden(true) }
                        .font(FTFont.subheadline())
                        .padding(.horizontal, FTSpacing.md)
                        .frame(minHeight: FTControl.minimumTarget)
                        .background(FTColors.background, in: Capsule())
                }
                .accessibilityLabel(L10n.tr("map.action.members", language: AppLanguage(locale: locale)))
                .accessibilityIdentifier("map.members")
            }
            Button(action: onSearch) {
                HStack(spacing: FTSpacing.sm) {
                    Image(systemName: "magnifyingglass").font(.system(size: 20)).accessibilityHidden(true)
                    AppLocalizedText("search.field.placeholder")
                    Spacer(minLength: 0)
                }
                .font(FTFont.body()).foregroundColor(FTColors.fieldHint)
                .padding(.horizontal, FTSpacing.md).padding(.vertical, FTSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(FTColors.background, in: RoundedRectangle(cornerRadius: FTRadius.md))
                .overlay(RoundedRectangle(cornerRadius: FTRadius.md).stroke(FTColors.separator, lineWidth: 0.5))
            }
            .accessibilityIdentifier("map.search")
        }
        .foregroundColor(FTColors.textPrimary)
        .padding(.horizontal, FTSpacing.md).padding(.vertical, FTSpacing.sm)
        .background(.regularMaterial)
    }
    private var headerLayout: AnyLayout {
        textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: FTSpacing.xs))
            : AnyLayout(HStackLayout(spacing: FTSpacing.sm))
    }
}

struct MapConnectionNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: FTSpacing.sm) {
            Image(systemName: "wifi.exclamationmark").foregroundColor(FTColors.danger).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                AppLocalizedText("map.connection.disconnected").font(FTFont.subheadline().weight(.semibold))
                AppLocalizedText("map.connection.last_known").font(FTFont.footnote()).foregroundColor(FTColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FTSpacing.sm).background(FTColors.background, in: RoundedRectangle(cornerRadius: FTRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("map.connection_warning")
    }
}

struct MapMembersPanel: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize
    let members: [MemberLocation]
    let expanded: Bool
    let onToggle: () -> Void
    let onSelect: (MemberLocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            headingLayout {
                AppLocalizedText("map.members.title").font(FTFont.headline()).accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onToggle) {
                    AppLocalizedText(expanded ? "map.action.collapse_members" : "map.action.all_members")
                        .font(FTFont.subheadline()).foregroundColor(FTColors.primary)
                        .frame(minHeight: FTControl.minimumTarget)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if members.isEmpty {
                AppLocalizedText("map.members.empty")
                    .font(FTFont.subheadline()).foregroundColor(FTColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if expanded || textSize.isAccessibilitySize {
                ScrollView {
                    LazyVStack(spacing: FTSpacing.sm) {
                        ForEach(members) { member in memberButton(member) }
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FTSpacing.md) {
                        ForEach(members) { member in memberButton(member) }
                    }
                }
            }
        }
        .padding(.horizontal, FTSpacing.md).padding(.bottom, FTSpacing.md)
        .foregroundColor(FTColors.textPrimary)
        .accessibilityIdentifier("map.member_list")
    }

    private var headingLayout: AnyLayout {
        textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: FTSpacing.xs))
            : AnyLayout(HStackLayout(spacing: FTSpacing.sm))
    }

    private func memberButton(_ member: MemberLocation) -> some View {
        Button { onSelect(member) } label: {
            HStack(spacing: FTSpacing.sm) {
                MemberAvatarView(name: member.name, size: .medium, isOnline: nil, batteryLevel: nil)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    Text(verbatim: member.name).font(FTFont.subheadline()).foregroundColor(FTColors.textPrimary)
                    Text(verbatim: MemberLocationText.updated(member.timestamp, language: AppLanguage(locale: locale)))
                        .font(FTFont.caption()).foregroundColor(FTColors.textSecondary)
                }
                if expanded || textSize.isAccessibilitySize { Spacer(minLength: 0) }
            }
            .frame(minHeight: FTControl.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct LiveMapControls: View {
    let tracking: Bool
    let onRecenter: () -> Void
    let onSOS: () -> Void
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: FTSpacing.sm) {
                Button { onRecenter() } label: {
                    Image(systemName: tracking ? "location.fill" : "location")
                        .frame(width: 44, height: 44)
                        .background(FTColors.background, in: Circle())
                }
                .accessibilityLabel(L10n.tr("map.action.recenter"))
                .accessibilityValue(L10n.tr(tracking ? "map.tracking.following" : "map.tracking.browsing"))
                .accessibilityIdentifier("map.recenter")
                Button(action: onSOS) {
                    Image(systemName: "sos").frame(width: 44, height: 44)
                        .background(FTColors.background, in: Circle()).foregroundColor(FTColors.danger)
                }
                .accessibilityLabel(L10n.tr("map.action.request_sos"))
                .accessibilityIdentifier("map.sos")
            }
            .font(.system(size: 20)).tint(FTColors.primary)
        }
    }
}
