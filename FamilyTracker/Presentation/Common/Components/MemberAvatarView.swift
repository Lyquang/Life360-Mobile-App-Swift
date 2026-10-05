// MARK: - MemberAvatarView.swift
// Component hiển thị Avatar của thành viên với trạng thái online và pin
//
// KIẾN THỨC:
// - enum trong Swift rất mạnh, có thể có associated values và computed properties
// - ViewBuilder cho phép tạo các component linh hoạt

import SwiftUI

// MARK: - Avatar Size Options
enum AvatarSize {
    case small   // 32pt - dùng trong list compact
    case medium  // 48pt - dùng trong member list
    case large   // 64pt - dùng trên bản đồ
    case xlarge  // 80pt - dùng trong profile

    var dimension: CGFloat {
        switch self {
        case .small:  return 32
        case .medium: return 48
        case .large:  return 64
        case .xlarge: return 80
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .small:  return 12
        case .medium: return 18
        case .large:  return 24
        case .xlarge: return 30
        }
    }
    
    var onlineDotSize: CGFloat {
        switch self {
        case .small:  return 8
        case .medium: return 10
        case .large:  return 14
        case .xlarge: return 16
        }
    }
}

// MARK: - MemberAvatarView
struct MemberAvatarView: View {
    let name: String
    let size: AvatarSize
    let isOnline: Bool
    let batteryLevel: Int?
    
    // Màu avatar được tạo ra từ tên (mỗi người có màu khác nhau)
    private var avatarColor: Color {
        let colors: [Color] = [
            Color(red: 0.38, green: 0.30, blue: 0.95), // Indigo
            Color(red: 0.06, green: 0.78, blue: 0.55), // Teal
            Color(red: 0.98, green: 0.45, blue: 0.14), // Orange
            Color(red: 0.80, green: 0.25, blue: 0.90), // Purple
            Color(red: 0.96, green: 0.30, blue: 0.30), // Red
            Color(red: 0.14, green: 0.60, blue: 0.98), // Blue
        ]
        // Hash tên để chọn màu nhất quán cho mỗi người
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
    
    // Chữ viết tắt (initials) từ tên
    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar circle với initials
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [avatarColor, avatarColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size.dimension, height: size.dimension)
                
                Text(initials)
                    .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .shadow(color: avatarColor.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Online/Offline indicator dot
            ZStack {
                // Border trắng để tạo viền
                Circle()
                    .fill(Color.white)
                    .frame(
                        width: size.onlineDotSize + 2,
                        height: size.onlineDotSize + 2
                    )
                
                // Dot màu
                Circle()
                    .fill(isOnline ? FTColors.accent : FTColors.textTertiary)
                    .frame(width: size.onlineDotSize, height: size.onlineDotSize)
                    // Hiệu ứng nhấp nháy khi online
                    .overlay(
                        Circle()
                            .fill(FTColors.accent.opacity(0.3))
                            .frame(width: size.onlineDotSize)
                            .scaleEffect(isOnline ? 1.5 : 0)
                            .opacity(isOnline ? 0 : 1)
                            .animation(
                                isOnline
                                    ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                                    : .default,
                                value: isOnline
                            )
                    )
            }
            .offset(x: 2, y: 2)
        }
    }
}

// MARK: - BatteryIndicatorView
/// Hiển thị mức pin nhỏ gọn
struct BatteryIndicatorView: View {
    let level: Int // 0-100
    
    private var color: Color {
        switch level {
        case 21...100: return FTColors.accent
        case 11...20: return FTColors.warning
        default: return FTColors.danger
        }
    }
    
    private var iconName: String {
        switch level {
        case 76...100: return "battery.100"
        case 51...75:  return "battery.75"
        case 26...50:  return "battery.50"
        case 11...25:  return "battery.25"
        default:       return "battery.0"
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .foregroundColor(color)
                .font(.system(size: 12))
            Text("\(level)%")
                .font(FTFont.caption())
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            MemberAvatarView(name: "Nguyen Van A", size: .small, isOnline: true, batteryLevel: 80)
            MemberAvatarView(name: "Tran Thi B", size: .medium, isOnline: false, batteryLevel: 20)
            MemberAvatarView(name: "Le Van C", size: .large, isOnline: true, batteryLevel: 15)
            MemberAvatarView(name: "Pham Thi D", size: .xlarge, isOnline: false, batteryLevel: 5)
        }
        
        BatteryIndicatorView(level: 85)
        BatteryIndicatorView(level: 15)
        BatteryIndicatorView(level: 5)
    }
    .padding()
}
