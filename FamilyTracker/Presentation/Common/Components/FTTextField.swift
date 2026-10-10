// MARK: - FTTextField.swift
// Custom TextField component tái sử dụng cho toàn app
//
// KIẾN THỨC:
// - @Binding: Kết nối 2 chiều giữa child view và parent view
//   Parent giữ @State, truyền $state vào child qua @Binding
//   Child thay đổi → Parent tự động thấy sự thay đổi
// - ViewBuilder: Cho phép SwiftUI build view phức tạp từ nhiều expression

import SwiftUI

// MARK: - FTTextField (Single-line)
struct FTTextField: View {
    let title: String          // Label phía trên
    let placeholder: String    // Placeholder text
    let icon: String           // SF Symbol name
    @Binding var text: String  // 2-way binding với parent
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    
    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            // Label
            AppLocalizedText(title)
                .font(FTFont.caption())
                .foregroundColor(FTColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5) // Letter spacing
            
            // Input field
            HStack(spacing: FTSpacing.sm) {
                // Icon bên trái
                Image(systemName: icon)
                    .foregroundColor(text.isEmpty ? FTColors.textTertiary : FTColors.primary)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                
                // TextField
                TextField(LocalizedStringKey(placeholder), text: $text)
                    .font(FTFont.body())
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
            }
            .padding(FTSpacing.md)
            .background(FTColors.surface)
            .cornerRadius(FTRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md)
                    .stroke(
                        text.isEmpty ? Color.clear : FTColors.primary.opacity(0.5),
                        lineWidth: 1.5
                    )
                    .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
            )
        }
    }
}

// MARK: - FTSecureField (Password)
struct FTSecureField: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    @State private var isVisible: Bool = false // Toggle hiển thị mật khẩu
    
    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            AppLocalizedText(title)
                .font(FTFont.caption())
                .foregroundColor(FTColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(text.isEmpty ? FTColors.textTertiary : FTColors.primary)
                    .frame(width: 20)
                
                // Hiển thị SecureField hoặc TextField tùy trạng thái
                if isVisible {
                    TextField(LocalizedStringKey(placeholder), text: $text)
                        .font(FTFont.body())
                        .autocorrectionDisabled()
                } else {
                    SecureField(LocalizedStringKey(placeholder), text: $text)
                        .font(FTFont.body())
                }
                
                // Nút toggle hiển thị mật khẩu
                Button(action: { isVisible.toggle() }) {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(FTColors.textTertiary)
                        .font(.system(size: 14))
                }
            }
            .padding(FTSpacing.md)
            .background(FTColors.surface)
            .cornerRadius(FTRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md)
                    .stroke(
                        text.isEmpty ? Color.clear : FTColors.primary.opacity(0.5),
                        lineWidth: 1.5
                    )
            )
        }
    }
}

// MARK: - FTButton (Primary Action Button)
struct FTButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    var style: ButtonStyle = .primary
    
    enum ButtonStyle {
        case primary  // Filled indigo
        case danger   // Filled red
        case outline  // Bordered
        case ghost    // Text only
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: FTSpacing.sm) {
                if isLoading {
                    // Loading spinner
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                AppLocalizedText(isLoading ? "Đang xử lý..." : title)
                    .font(FTFont.headline())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundView)
            .foregroundColor(foregroundColor)
            .cornerRadius(FTRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg)
                    .stroke(
                        style == .outline ? FTColors.primary : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: (style == .primary || style == .danger) ? shadowColor.opacity(0.35) : Color.clear,
                radius: 8, x: 0, y: 4
            )
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLoading)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary: FTColors.primary
        case .danger: FTColors.danger
        case .outline: Color.clear
        case .ghost: Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .danger: return .white
        case .outline, .ghost: return FTColors.primary
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary: return FTColors.primary
        case .danger: return FTColors.danger
        default: return .clear
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FTTextField(
            title: "Email",
            placeholder: "Nhập email của bạn",
            icon: "envelope.fill",
            text: .constant("test@example.com"),
            keyboardType: .emailAddress
        )
        FTSecureField(
            title: "Mật khẩu",
            placeholder: "Nhập mật khẩu",
            icon: "lock.fill",
            text: .constant("")
        )
        FTButton(title: "Đăng nhập", isLoading: false, action: {})
        FTButton(title: "Đang xử lý...", isLoading: true, action: {})
        FTButton(title: "SOS Khẩn Cấp", isLoading: false, action: {}, style: .danger)
    }
    .padding()
}
