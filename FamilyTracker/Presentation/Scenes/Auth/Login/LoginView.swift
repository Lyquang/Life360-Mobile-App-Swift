// MARK: - LoginView.swift
// Màn hình Đăng nhập. Điều hướng sang Đăng ký do AuthCoordinator xử lý.

import SwiftUI

struct LoginView: View {
    
    @ObservedObject var viewModel: LoginViewModel
    let onRegister: () -> Void
    
    var body: some View {
        // NavigationStack: Container cho navigation (iOS 16+)
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.10, green: 0.05, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Decorative circles (glassmorphism effect)
                GeometryReader { geo in
                    Circle()
                        .fill(FTColors.primary.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: -50, y: -100)
                    
                    Circle()
                        .fill(FTColors.accent.opacity(0.10))
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: geo.size.width - 150, y: geo.size.height - 200)
                }
                
                // Main content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: Header
                        VStack(spacing: FTSpacing.sm) {
                            // App logo
                            ZStack {
                                Circle()
                                    .fill(FTColors.primaryGradient)
                                    .frame(width: 90, height: 90)
                                    .shadow(color: FTColors.primary.opacity(0.5), radius: 20)
                                
                                Image(systemName: "location.fill.viewfinder")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 60)
                            .padding(.bottom, FTSpacing.sm)
                            
                            Text("FamilyTracker")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Kết nối gia đình, mọi lúc mọi nơi")
                                .font(FTFont.subheadline())
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.bottom, FTSpacing.xl)
                        
                        // MARK: Form Card
                        VStack(spacing: FTSpacing.md) {
                            // Form title
                            HStack {
                                Text("Đăng nhập")
                                    .font(FTFont.title2())
                                    .foregroundColor(FTColors.textPrimary)
                                Spacer()
                            }
                            .padding(.bottom, FTSpacing.xs)
                            
                            // Email field
                            FTTextField(
                                title: "Email",
                                placeholder: "example@email.com",
                                icon: "envelope.fill",
                                text: $viewModel.email,
                                keyboardType: .emailAddress,
                                autocapitalization: .never
                            )
                            .onChange(of: viewModel.email) { _ in viewModel.clearError() }
                            
                            // Password field
                            FTSecureField(
                                title: "Mật khẩu",
                                placeholder: "Nhập mật khẩu",
                                icon: "lock.fill",
                                text: $viewModel.password
                            )
                            .onChange(of: viewModel.password) { _ in viewModel.clearError() }
                            
                            // Error message
                            if let error = viewModel.errorMessage {
                                HStack(spacing: FTSpacing.xs) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(error)
                                        .font(FTFont.caption())
                                }
                                .foregroundColor(FTColors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.easeInOut, value: viewModel.errorMessage)
                            }
                            
                            // Login button
                            FTButton(
                                title: "Đăng nhập",
                                isLoading: viewModel.isLoading
                            ) {
                                Task { await viewModel.submit() }
                            }
                            .padding(.top, FTSpacing.xs)
                        }
                        .padding(FTSpacing.lg)
                        .background(.ultraThinMaterial) // Glassmorphism blur background
                        .cornerRadius(FTRadius.xl)
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, FTSpacing.md)
                        
                        // MARK: Register Link
                        HStack(spacing: FTSpacing.xs) {
                            Text("Chưa có tài khoản?")
                                .font(FTFont.subheadline())
                                .foregroundColor(.white.opacity(0.6))
                            
                            Button("Đăng ký ngay", action: onRegister)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(FTColors.accent)
                        }
                        .padding(.top, FTSpacing.lg)
                        .padding(.bottom, FTSpacing.xxl)
                    }
                }
            }
        }
        .hideKeyboardOnTap()
    }
}
