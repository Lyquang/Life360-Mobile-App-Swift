import SwiftUI

/// Summary card for one group in the list.
struct GroupCard: View {
    let group: FamilyGroup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: FTSpacing.md) {
                HStack(spacing: FTSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(FTColors.primaryGradient)
                            .frame(width: 50, height: 50)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(FTFont.headline())
                            .foregroundColor(FTColors.textPrimary)

                        HStack(spacing: FTSpacing.xs) {
                            Text("\(group.memberCount) thành viên")
                                .font(FTFont.caption())
                                .foregroundColor(FTColors.textSecondary)
                            Text("•")
                                .foregroundColor(FTColors.textTertiary)
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(FTColors.accent)
                                    .frame(width: 6, height: 6)
                                Text("\(group.onlineMembersCount) online")
                                    .font(FTFont.caption())
                                    .foregroundColor(FTColors.accent)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(FTColors.textTertiary)
                }

                if let code = group.inviteCode {
                    Divider()
                    HStack {
                        Label("Mã mời:", systemImage: "key.fill")
                            .font(FTFont.caption())
                            .foregroundColor(FTColors.textSecondary)
                        Text(code)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(FTColors.primary)
                            .tracking(3)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = code
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(FTColors.textSecondary)
                        }
                    }
                }

                if let members = group.members, !members.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(members.prefix(5)) { member in
                            MemberAvatarView(name: member.name, size: .small, isOnline: member.isOnline ?? false, batteryLevel: nil)
                                .overlay(Circle().stroke(FTColors.card, lineWidth: 2))
                        }
                        if members.count > 5 {
                            Text("+\(members.count - 5)")
                                .font(FTFont.caption())
                                .foregroundColor(FTColors.textSecondary)
                                .padding(.leading, 12)
                        }
                        Spacer()
                    }
                }
            }
            .padding(FTSpacing.md)
            .ftCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}
