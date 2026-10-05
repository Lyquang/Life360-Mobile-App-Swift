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
                    size: .large,
                    isOnline: true,
                    batteryLevel: memberLocation.batteryLevel
                )
                .overlay(
                    Circle()
                        .stroke(
                            isCurrentUser ? FTColors.primary : Color.white,
                            lineWidth: isCurrentUser ? 3 : 2
                        )
                )
            }

            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 6)
                .shadow(color: Color.black.opacity(0.1), radius: 2)
        }
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
