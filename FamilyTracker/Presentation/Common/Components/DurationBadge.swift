// MARK: - DurationBadge.swift
// Badge hiển thị thời gian một thành viên đang đứng yên tại một chỗ
// Dùng trong MapView trên avatar của thành viên
//
// Ví dụ: ⏱ 1 giờ 30 phút
//         (xuất hiện khi isStaying == true, tức là >= 5 phút)

import SwiftUI

// MARK: - DurationBadge
/// Badge nhỏ hiển thị "⏱ 30 phút" trên avatar thành viên trên bản đồ
struct DurationBadge: View {
    let durationFormatted: String  // "30 phút", "1 giờ 5 phút", ...
    let durationMinutes: Int

    /// Màu badge thay đổi theo thời gian ở: xanh → cam → đỏ
    private var badgeColor: Color {
        switch durationMinutes {
        case 0..<60:   return FTColors.accent          // Xanh lá: < 1 giờ
        case 60..<240: return FTColors.warning          // Vàng cam: 1–4 giờ
        default:       return FTColors.danger           // Đỏ: > 4 giờ
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(durationFormatted)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(badgeColor)
                .shadow(color: badgeColor.opacity(0.4), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - DurationBadgeLarge
/// Badge lớn hơn dùng trong danh sách thành viên (CircleView, GroupDetailView)
struct DurationBadgeLarge: View {
    let member: MemberLocation

    var body: some View {
        if member.isStaying, let formatted = member.durationFormatted {
            HStack(spacing: FTSpacing.xs) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Đang ở đây")
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textSecondary)
                    Text(formatted)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(stayColor(minutes: member.durationAtLocation ?? 0))
                }
            }
            .padding(.horizontal, FTSpacing.sm)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: FTRadius.sm)
                    .fill(stayColor(minutes: member.durationAtLocation ?? 0).opacity(0.1))
            )
        }
    }

    private func stayColor(minutes: Int) -> Color {
        switch minutes {
        case 0..<60:   return FTColors.accent
        case 60..<240: return FTColors.warning
        default:       return FTColors.danger
        }
    }
}

// MARK: - MemberAvatarWithDuration
/// Avatar thành viên kết hợp với badge thời gian đứng
/// (dùng ở MapView overlay)
struct MemberAvatarWithDuration: View {
    let location: MemberLocation
    let onTap: () -> Void

    @State private var pulse: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                ZStack {
                    // Pulse ring nếu đang ở yên lâu (>= 30 phút)
                    if (location.durationAtLocation ?? 0) >= 30 {
                        Circle()
                            .stroke(stayRingColor.opacity(pulse ? 0 : 0.5), lineWidth: 3)
                            .frame(width: 50, height: 50)
                            .scaleEffect(pulse ? 1.4 : 1.0)
                            .animation(
                                .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                                value: pulse
                            )
                    }

                    // Avatar circle
                    Circle()
                        .fill(FTColors.primaryGradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.black.opacity(0.2), radius: 4)

                    Text(location.initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                // Duration badge (hiển thị khi isStaying)
                if location.isStaying, let formatted = location.durationFormatted {
                    DurationBadge(
                        durationFormatted: formatted,
                        durationMinutes: location.durationAtLocation ?? 0
                    )
                    .transition(.scale.combined(with: .opacity))
                }

                // Tên
                Text(location.name.components(separatedBy: " ").first ?? location.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(FTColors.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear { pulse = true }
    }

    private var stayRingColor: Color {
        switch location.durationAtLocation ?? 0 {
        case 0..<60:   return FTColors.accent
        case 60..<240: return FTColors.warning
        default:       return FTColors.danger
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        DurationBadge(durationFormatted: "30 phút", durationMinutes: 30)
        DurationBadge(durationFormatted: "1 giờ 20 phút", durationMinutes: 80)
        DurationBadge(durationFormatted: "5 giờ", durationMinutes: 300)
    }
    .padding()
    .background(FTColors.background)
}
