import SwiftUI

/// Custom pin shown on the live map.
struct MapMemberPin: View {
    let memberLocation: MemberLocation
    let isCurrentUser: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isCurrentUser {
                    Circle()
                        .fill(FTColors.primary.opacity(0.2))
                        .frame(width: 56, height: 56)
                }

                MemberAvatarView(
                    name: memberLocation.name,
                    size: .medium,
                    isOnline: nil,
                    batteryLevel: memberLocation.batteryLevel
                )
                .overlay(
                    Circle()
                        .stroke(
                            isCurrentUser ? FTColors.primary : FTColors.background,
                            lineWidth: isCurrentUser ? 3 : 2
                        )
                )
            }

            Triangle()
                .fill(FTColors.background)
                .frame(width: 12, height: 6)
                .shadow(color: Color.black.opacity(0.1), radius: 2)
            Text(verbatim: memberLocation.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(FTColors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(FTColors.background, in: Capsule())
                .accessibilityHidden(true)
        }
        .frame(width: 80)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
