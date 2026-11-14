// MARK: - FTDesignSystem.swift
// Hệ thống thiết kế (Design System) của FamilyTracker
// Tập trung tất cả màu sắc, font, spacing để dễ thay đổi toàn app
//
// KIẾN THỨC - Design Token:
// Thay vì hardcode màu khắp nơi (.foregroundColor(.blue)),
// ta dùng Design System (.foregroundColor(FTColors.primary))
// → Khi cần thay màu, chỉ đổi ở 1 chỗ duy nhất

import SwiftUI

// MARK: - Colors
struct FTColors {
    // One adaptive palette shared by app controls, sheets and map overlays.
    static let primary = adaptive(light: 0x5843D6, dark: 0xB8ABFF)
    static let onPrimary = adaptive(light: 0xFFFFFF, dark: 0x19132E)
    static let accent = adaptive(light: 0x087A58, dark: 0x55DBAF)
    static let danger = adaptive(light: 0xB52835, dark: 0xFF9AA4)
    static let warning = adaptive(light: 0x895200, dark: 0xF6BE65)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }

    // Màu nền
    static let background  = Color(UIColor.systemBackground)
    static let card        = Color(UIColor.secondarySystemBackground)
    static let surface     = Color(UIColor.tertiarySystemBackground)
    
    // Màu chữ
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary  = Color(UIColor.tertiaryLabel)
    static let fieldHint = textPrimary.opacity(0.7)
    
    static let separator = Color(UIColor.separator)

    // Shared authentication backdrop; preserves the existing palette.
    static let authBackground = LinearGradient(
        colors: [adaptive(light: 0xF2F2F7, dark: 0x101115), adaptive(light: 0xFFFFFF, dark: 0x171722)],
        startPoint: .top,
        endPoint: .bottom
    )

    // Gradient chính (dùng cho header, button)
    static let primaryGradient = LinearGradient(
        colors: [primary, primary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Gradient nguy hiểm
    static let dangerGradient = LinearGradient(
        colors: [danger, danger],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography
struct FTFont {
    // Sử dụng Dynamic Type của Apple (tự điều chỉnh kích thước theo accessibility)
    static func largeTitle()  -> Font { .system(.largeTitle, design: .rounded).weight(.bold) }
    static func title()       -> Font { .system(.title, design: .rounded).weight(.bold) }
    static func title2()      -> Font { .system(.title2, design: .rounded).weight(.semibold) }
    static func title3()      -> Font { .system(.title3, design: .rounded).weight(.semibold) }
    static func headline()    -> Font { .system(.headline, design: .rounded).weight(.semibold) }
    static func body()        -> Font { .system(.body, design: .rounded).weight(.regular) }
    static func callout()     -> Font { .system(.callout, design: .rounded).weight(.regular) }
    static func subheadline() -> Font { .system(.subheadline, design: .rounded).weight(.medium) }
    static func footnote()    -> Font { .system(.footnote, design: .rounded).weight(.regular) }
    static func caption()     -> Font { .system(.caption, design: .rounded).weight(.regular) }
}

// MARK: - Controls
struct FTControl {
    static let minimumTarget: CGFloat = 44
}

// MARK: - Spacing
struct FTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
struct FTRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999 // Circle/Pill shape
}

// MARK: - Shadow
struct FTShadow {
    static func soft() -> some View {
        // Không thể return trực tiếp trong struct như này, dùng ViewModifier
        EmptyView()
    }
}

// MARK: - Custom ViewModifiers
// ViewModifier: tái sử dụng style phức tạp dưới dạng .modifier(...)
struct CardModifier: ViewModifier {
    var cornerRadius: CGFloat = FTRadius.lg
    func body(content: Content) -> some View {
        content
            .background(FTColors.card)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

struct PrimaryButtonModifier: ViewModifier {
    var isLoading: Bool = false
    
    func body(content: Content) -> some View {
        content
            .font(FTFont.headline())
            .foregroundColor(FTColors.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isLoading ? FTColors.primary.opacity(0.6) : FTColors.primary)
            .cornerRadius(FTRadius.lg)
            .shadow(color: FTColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

// MARK: - View Extensions
// Extension giúp gọi modifier gọn hơn: .ftCard() thay vì .modifier(CardModifier())
extension View {
    func ftCard(cornerRadius: CGFloat = FTRadius.lg) -> some View {
        self.modifier(CardModifier(cornerRadius: cornerRadius))
    }
    
    func ftPrimaryButton(isLoading: Bool = false) -> some View {
        self.modifier(PrimaryButtonModifier(isLoading: isLoading))
    }
    
    /// Ẩn bàn phím khi tap ra ngoài TextField
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}
