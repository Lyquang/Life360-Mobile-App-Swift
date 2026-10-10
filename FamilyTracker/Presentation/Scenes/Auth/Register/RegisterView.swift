// MARK: - RegisterView.swift
// Màn hình Đăng ký tài khoản mới

import SwiftUI

struct RegisterView: View {
    
    @ObservedObject var viewModel: RegisterViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.10, green: 0.05, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: Header
                        VStack(spacing: FTSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(FTColors.primaryGradient)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: FTColors.primary.opacity(0.5), radius: 15)
                                
                                Image(systemName: "person.fill.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 30)
                            
                            Text("Tạo tài khoản")
                                .font(FTFont.title())
                                .foregroundColor(.white)
                            
                            Text("Bắt đầu hành trình cùng gia đình")
                                .font(FTFont.subheadline())
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.bottom, FTSpacing.xl)
                        
                        // MARK: Form Card
                        VStack(spacing: FTSpacing.md) {
                            // Full Name
                            FTTextField(
                                title: "Họ và tên",
                                placeholder: "Nguyễn Văn A",
                                icon: "person.fill",
                                text: $viewModel.name
                            )
                            .onChange(of: viewModel.name) { _ in viewModel.clearError() }
                            
                            // Email
                            FTTextField(
                                title: "Email",
                                placeholder: "example@email.com",
                                icon: "envelope.fill",
                                text: $viewModel.email,
                                keyboardType: .emailAddress,
                                autocapitalization: .never
                            )
                            .onChange(of: viewModel.email) { _ in viewModel.clearError() }
                            
                            // Password
                            FTSecureField(
                                title: "Mật khẩu",
                                placeholder: "Tối thiểu 6 ký tự",
                                icon: "lock.fill",
                                text: $viewModel.password
                            )
                            .onChange(of: viewModel.password) { _ in viewModel.clearError() }
                            
                            // Confirm Password
                            FTSecureField(
                                title: "Xác nhận mật khẩu",
                                placeholder: "Nhập lại mật khẩu",
                                icon: "lock.rotation",
                                text: $viewModel.confirmPassword
                            )
                            .onChange(of: viewModel.confirmPassword) { _ in viewModel.clearError() }
                            
                            if let error = viewModel.errorMessage {
                                HStack(spacing: FTSpacing.xs) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    AppLocalizedText(error)
                                        .font(FTFont.caption())
                                }
                                .foregroundColor(FTColors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            // Password strength indicator
                            if !viewModel.password.isEmpty {
                                PasswordStrengthView(password: viewModel.password)
                            }
                            
                            // Register button
                            FTButton(
                                title: "Tạo tài khoản",
                                isLoading: viewModel.isLoading
                            ) {
                                Task { await viewModel.submit() }
                            }
                            .padding(.top, FTSpacing.sm)
                            
                            // Terms text
                            Text("Bằng cách đăng ký, bạn đồng ý với Điều khoản sử dụng và Chính sách bảo mật của chúng tôi.")
                                .font(FTFont.caption())
                                .foregroundColor(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .padding(FTSpacing.lg)
                        .background(.ultraThinMaterial)
                        .cornerRadius(FTRadius.xl)
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, FTSpacing.md)
                        
                        // Back to login
                        Button("Đã có tài khoản? Đăng nhập") {
                            dismiss()
                        }
                        .font(FTFont.subheadline())
                        .foregroundColor(FTColors.accent)
                        .padding(.top, FTSpacing.lg)
                        .padding(.bottom, FTSpacing.xxl)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .hideKeyboardOnTap()
    }
}

// MARK: - Password Strength Indicator
/// Hiển thị độ mạnh của mật khẩu
struct PasswordStrengthView: View {
    let password: String
    
    // Tính điểm độ mạnh mật khẩu
    private var strength: Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { score += 1 }
        return score // 0-4
    }
    
    private var strengthText: String {
        switch strength {
        case 0...1: return "Yếu"
        case 2: return "Trung bình"
        case 3: return "Mạnh"
        default: return "Rất mạnh"
        }
    }
    
    private var strengthColor: Color {
        switch strength {
        case 0...1: return FTColors.danger
        case 2: return FTColors.warning
        case 3: return FTColors.accent.opacity(0.8)
        default: return FTColors.accent
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.xs) {
            HStack {
                Text("Độ mạnh:")
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)
                AppLocalizedText(strengthText)
                    .font(FTFont.caption())
                    .foregroundColor(strengthColor)
                    .fontWeight(.semibold)
            }
            
            // Progress bar
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < strength ? strengthColor : FTColors.surface)
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.2), value: strength)
                }
            }
        }
    }
}
