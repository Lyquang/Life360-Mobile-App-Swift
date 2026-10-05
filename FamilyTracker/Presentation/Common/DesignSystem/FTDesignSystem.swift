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
    // Màu chính: Indigo đậm (sang trọng, hiện đại)
    static let primary     = Color(red: 0.38, green: 0.30, blue: 0.95)  // #6145F2
    
    // Màu phụ: Xanh lá (online, thành công)
    static let accent      = Color(red: 0.06, green: 0.78, blue: 0.55)  // #10C78C
    
    // Màu nguy hiểm: Đỏ san hô (SOS, lỗi)
    static let danger      = Color(red: 0.96, green: 0.30, blue: 0.30)  // #F54D4D
    
    // Màu cảnh báo: Cam vàng (pin thấp, warning)
    static let warning     = Color(red: 0.98, green: 0.65, blue: 0.14)  // #FAA623
    
    // Màu nền
    static let background  = Color(UIColor.systemBackground)
    static let card        = Color(UIColor.secondarySystemBackground)
    static let surface     = Color(UIColor.tertiarySystemBackground)
    
    // Màu chữ
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary  = Color(UIColor.tertiaryLabel)
    
    // Gradient chính (dùng cho header, button)
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 0.38, green: 0.30, blue: 0.95), Color(red: 0.55, green: 0.20, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Gradient nguy hiểm
    static let dangerGradient = LinearGradient(
        colors: [Color(red: 0.96, green: 0.30, blue: 0.30), Color(red: 0.98, green: 0.15, blue: 0.50)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography
struct FTFont {
    // Sử dụng Dynamic Type của Apple (tự điều chỉnh kích thước theo accessibility)
    static func largeTitle()  -> Font { .system(size: 34, weight: .bold, design: .rounded) }
    static func title()       -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func title2()      -> Font { .system(size: 22, weight: .semibold, design: .rounded) }
    static func title3()      -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
    static func headline()    -> Font { .system(size: 17, weight: .semibold, design: .rounded) }
    static func body()        -> Font { .system(size: 17, weight: .regular, design: .rounded) }
    static func callout()     -> Font { .system(size: 16, weight: .regular, design: .rounded) }
    static func subheadline() -> Font { .system(size: 15, weight: .medium, design: .rounded) }
    static func footnote()    -> Font { .system(size: 13, weight: .regular, design: .rounded) }
    static func caption()     -> Font { .system(size: 12, weight: .regular, design: .rounded) }
}

// MARK: - Spacing
struct FTSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
struct FTRadius {
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
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
    func body(content: Content) -> some View {
        content
            .background(FTColors.card)
            .cornerRadius(FTRadius.lg)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

struct PrimaryButtonModifier: ViewModifier {
    var isLoading: Bool = false
    
    func body(content: Content) -> some View {
        content
            .font(FTFont.headline())
            .foregroundColor(.white)
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
    func ftCard() -> some View {
        self.modifier(CardModifier())
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
