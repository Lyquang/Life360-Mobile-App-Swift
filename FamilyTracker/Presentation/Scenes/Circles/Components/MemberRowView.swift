// MARK: - MemberRowView.swift
// Component hiển thị một thành viên trong danh sách

import SwiftUI

struct MemberRowView: View {
    let member: User
    
    var body: some View {
        HStack(spacing: FTSpacing.md) {
            // Avatar với trạng thái online
            MemberAvatarView(
                name: member.name,
                size: .medium,
                isOnline: member.isOnline ?? false,
                batteryLevel: member.batteryLevel
            )
            
            // Member info
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(FTFont.subheadline())
                    .foregroundColor(FTColors.textPrimary)
                
                Text(member.email)
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)
                
                // Online status
                HStack(spacing: 4) {
                    Circle()
                        .fill(member.isOnline == true ? FTColors.accent : FTColors.textTertiary)
                        .frame(width: 6, height: 6)
                    AppLocalizedText(member.isOnline == true ? "Đang online" : "Offline")
                        .font(FTFont.caption())
                        .foregroundColor(
                            member.isOnline == true ? FTColors.accent : FTColors.textTertiary
                        )
                }
            }
            
            Spacer()
            
            // Battery level
            if let battery = member.batteryLevel {
                BatteryIndicatorView(level: battery)
            }
        }
        .padding(.vertical, FTSpacing.xs)
    }
}
