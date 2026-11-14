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
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                .foregroundColor(FTColors.fieldHint)
                .textCase(.uppercase)
                .tracking(0.5) // Letter spacing
                .accessibilityHidden(true)
            
            // Input field
            HStack(spacing: FTSpacing.sm) {
                // Icon bên trái
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(text.isEmpty ? FTColors.textTertiary : FTColors.primary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: text.isEmpty)
                
                // TextField
                TextField(text: $text) {
                    Text(verbatim: L10n.tr(placeholder))
                        .foregroundColor(FTColors.fieldHint)
                }
                    .font(FTFont.body())
                    .keyboardType(keyboardType)
                    .textContentType(keyboardType == .emailAddress ? .username : nil)
                    .accessibilityLabel(Text(verbatim: L10n.tr(title, language: AppLanguage(locale: locale))))
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .clipped()
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
            }
            .frame(minHeight: FTControl.minimumTarget)
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, FTSpacing.xs)
            .background(FTColors.surface)
            .cornerRadius(FTRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md)
                    .stroke(
                        text.isEmpty ? Color.clear : FTColors.primary.opacity(0.5),
                        lineWidth: 1.5
                    )
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: text.isEmpty)
            )
        }
    }
}

// MARK: - FTSecureField (Password)
struct FTSecureField: View {
    @Environment(\.locale) private var locale
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var contentType: UITextContentType = .password
    @State private var isVisible: Bool = false // Toggle hiển thị mật khẩu
    
    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            AppLocalizedText(title)
                .font(FTFont.caption())
                .foregroundColor(FTColors.fieldHint)
                .textCase(.uppercase)
                .tracking(0.5)
                .accessibilityHidden(true)
            
            HStack(spacing: FTSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(text.isEmpty ? FTColors.textTertiary : FTColors.primary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                
                // Hiển thị SecureField hoặc TextField tùy trạng thái
                if isVisible {
                    TextField(text: $text) {
                        Text(verbatim: L10n.tr(placeholder))
                        .foregroundColor(FTColors.fieldHint)
                    }
                        .font(FTFont.body())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(contentType)
                        .accessibilityLabel(Text(verbatim: L10n.tr(title, language: AppLanguage(locale: locale))))
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .clipped()
                } else {
                    SecureField(text: $text) {
                        Text(verbatim: L10n.tr(placeholder))
                        .foregroundColor(FTColors.fieldHint)
                    }
                        .font(FTFont.body())
                        .textContentType(contentType)
                        .accessibilityLabel(Text(verbatim: L10n.tr(title, language: AppLanguage(locale: locale))))
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .clipped()
                }
                
                // Nút toggle hiển thị mật khẩu
                Button(action: { isVisible.toggle() }) {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(FTColors.fieldHint)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: FTControl.minimumTarget, height: FTControl.minimumTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: L10n.tr(isVisible
                    ? "common.accessibility.hide_password" : "common.accessibility.show_password", language: AppLanguage(locale: locale))))
                .accessibilityValue(Text(verbatim: L10n.tr(isVisible
                    ? "common.accessibility.password_visible" : "common.accessibility.password_hidden", language: AppLanguage(locale: locale))))
                .accessibilityIdentifier("password.visibility")
            }
            .frame(minHeight: FTControl.minimumTarget)
            .padding(.horizontal, FTSpacing.md)
            .padding(.vertical, FTSpacing.xs)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                        .accessibilityHidden(true)
                }
                AppLocalizedText(isLoading ? "Đang xử lý..." : title)
                    .font(FTFont.headline())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: FTControl.minimumTarget)
            .padding(.vertical, FTSpacing.sm)
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
        .scaleEffect(isLoading && !reduceMotion ? 0.98 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isLoading)
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
        case .primary, .danger: return FTColors.onPrimary
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
