// MARK: - StayAlertBanner.swift
// Banner thông báo khi một thành viên trong nhóm đứng yên quá lâu (Feature 1)
// Tương tự SOSAlertBanner nhưng với màu sắc và nội dung khác
//
// Hiển thị: "Nguyễn Văn A đang ở một nơi được 1 giờ rồi!"
// Tự động biến mất sau 20 giây, có nút xem vị trí

import SwiftUI

struct StayAlertBanner: View {
    let alert: LocationStayAlert
    let onDismiss: () -> Void
    let onNavigate: (() -> Void)?

    @State private var isVisible: Bool = false
    @State private var iconRotation: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Main Content
            HStack(spacing: FTSpacing.md) {
                // Icon với animation
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 46, height: 46)

                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(iconRotation))
                        .animation(
                            .easeInOut(duration: 2).repeatForever(autoreverses: true),
                            value: iconRotation
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(alertTitle)
                        .font(FTFont.headline())
                        .foregroundColor(.white)

                    Text(alert.message)
                        .font(FTFont.subheadline())
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)

                    if let groupName = alert.groupName {
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 10))
                            Text(groupName)
                                .font(FTFont.caption())
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Nút đóng
                Button(action: {
                    withAnimation(.easeIn(duration: 0.3)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(FTSpacing.md)

            // MARK: - Duration Highlight Bar
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                Text("Đã ở đây: \(alert.durationFormatted)")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.12))

            // MARK: - Navigate Button
            if alert.latitude != nil && alert.longitude != nil {
                Button(action: { onNavigate?() }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Xem vị trí trên bản đồ")
                            .font(FTFont.subheadline())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(bannerGradient)
        .cornerRadius(FTRadius.lg)
        .shadow(color: shadowColor.opacity(0.4), radius: 16, x: 0, y: 8)
        .padding(.horizontal, FTSpacing.md)
        .offset(y: isVisible ? 0 : -200)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isVisible = true
            }
            iconRotation = 15
        }
    }

    // MARK: - Dynamic Properties based on duration

    /// Tên icon thay đổi theo thời gian đứng
    private var iconName: String {
        switch alert.durationMinutes {
        case 0..<60:   return "mappin.circle.fill"
        case 60..<240: return "clock.badge.exclamationmark"
        default:       return "exclamationmark.triangle.fill"
        }
    }

    /// Tiêu đề banner
    private var alertTitle: String {
        switch alert.durationMinutes {
        case 0..<60:   return "⏱ Đang đứng yên lâu"
        case 60..<240: return "⚠️ Ở một chỗ khá lâu"
        default:       return "🔴 Ở một chỗ rất lâu!"
        }
    }

    /// Gradient màu theo mức độ
    private var bannerGradient: LinearGradient {
        switch alert.durationMinutes {
        case 0..<60:
            return LinearGradient(
                colors: [Color(hue: 0.35, saturation: 0.7, brightness: 0.55),
                         Color(hue: 0.40, saturation: 0.65, brightness: 0.48)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case 60..<240:
            return LinearGradient(
                colors: [Color(hue: 0.08, saturation: 0.85, brightness: 0.75),
                         Color(hue: 0.05, saturation: 0.80, brightness: 0.60)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(hue: 0.02, saturation: 0.85, brightness: 0.72),
                         Color(hue: 0.98, saturation: 0.80, brightness: 0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        switch alert.durationMinutes {
        case 0..<60:   return FTColors.accent
        case 60..<240: return FTColors.warning
        default:       return FTColors.danger
        }
    }
}

// MARK: - StayAlertStack
/// Stack nhiều StayAlertBanner, mỗi banner bị offset nhẹ để tạo hiệu ứng chồng
struct StayAlertStack: View {
    @Binding var alerts: [LocationStayAlert]
    let onNavigate: ((LocationStayAlert) -> Void)?
    let onDismiss: (LocationStayAlert) -> Void

    var body: some View {
        VStack(spacing: FTSpacing.sm) {
            ForEach(alerts) { alert in
                StayAlertBanner(
                    alert: alert,
                    onDismiss: { onDismiss(alert) },
                    onNavigate: onNavigate.map { nav in { nav(alert) } }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: alerts.count)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        FTColors.background.ignoresSafeArea()
        VStack {
            StayAlertBanner(
                alert: LocationStayAlert(
                    userId: "u1",
                    name: "Nguyễn Văn A",
                    latitude: 10.776,
                    longitude: 106.700,
                    durationMinutes: 30,
                    durationFormatted: "30 phút",
                    durationSince: nil,
                    groupId: "g1",
                    groupName: "Gia đình Nguyễn",
                    message: "Nguyễn Văn A đang ở một nơi được 30 phút rồi!",
                    timestamp: ""
                ),
                onDismiss: {},
                onNavigate: nil
            )

            StayAlertBanner(
                alert: LocationStayAlert(
                    userId: "u2",
                    name: "Trần Thị B",
                    latitude: 10.776,
                    longitude: 106.700,
                    durationMinutes: 120,
                    durationFormatted: "2 giờ",
                    durationSince: nil,
                    groupId: "g1",
                    groupName: "Gia đình Nguyễn",
                    message: "Trần Thị B đang ở một nơi được 2 giờ rồi!",
                    timestamp: ""
                ),
                onDismiss: {},
                onNavigate: {}
            )
        }
    }
}
