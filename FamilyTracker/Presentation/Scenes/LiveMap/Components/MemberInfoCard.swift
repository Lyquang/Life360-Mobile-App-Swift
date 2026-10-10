import SwiftUI

/// Floating card shown when a member pin is tapped.
struct MemberInfoCard: View {
    let member: MemberLocation
    let onDismiss: () -> Void
    let onNavigate: () -> Void
    let onShowJourney: () -> Void

    var body: some View {
        HStack(spacing: FTSpacing.md) {
            MemberAvatarView(name: member.name, size: .large, isOnline: true, batteryLevel: member.batteryLevel)

            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                Text(member.name)
                    .font(FTFont.headline())
                    .foregroundColor(FTColors.textPrimary)

                Text("Lat: \(String(format: "%.4f", member.latitude)), Lon: \(String(format: "%.4f", member.longitude))")
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)

                HStack(spacing: FTSpacing.sm) {
                    if let battery = member.batteryLevel {
                        BatteryIndicatorView(level: battery)
                    }
                    Text(updatedText)
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textTertiary)
                }
            }

            Spacer()

            VStack(spacing: FTSpacing.sm) {
                circleButton(icon: "location.fill", action: onNavigate)
                circleButton(icon: "figure.walk.motion", action: onShowJourney)
            }
        }
        .padding(FTSpacing.md)
        .ftCard()
        .padding(.horizontal, FTSpacing.md)
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(FTColors.textTertiary)
                    .padding(6)
                    .background(FTColors.surface)
                    .clipShape(Circle())
            }
            .offset(x: -8, y: -8)
        }
    }

    private var updatedText: LocalizedStringKey {
        ISO8601.date(from: member.timestamp) == nil
            ? "Vừa cập nhật"
            : "Cập nhật lúc \(DisplayFormat.time(iso: member.timestamp))"
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(FTColors.primary)
                .clipShape(Circle())
        }
    }
}
