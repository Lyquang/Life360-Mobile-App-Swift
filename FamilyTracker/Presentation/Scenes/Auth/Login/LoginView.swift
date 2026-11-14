// MARK: - LoginView.swift
// Màn hình Đăng nhập. Điều hướng sang Đăng ký do AuthCoordinator xử lý.

import SwiftUI

struct LoginView: View {
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: LoginViewModel
    let onRegister: () -> Void
    
    var body: some View {
        // NavigationStack: Container cho navigation (iOS 16+)
        NavigationStack {
            ZStack {
                // Background gradient
                FTColors.authBackground
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
                            
                            LanguagePicker()
                                .tint(.white)
                                .padding(.vertical, FTSpacing.xs)

                            AppLocalizedText("Kết nối gia đình, mọi lúc mọi nơi")
                                .font(FTFont.subheadline())
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.bottom, FTSpacing.xl)
                        
                        // MARK: Form Card
                        VStack(spacing: FTSpacing.md) {
                            // Form title
                            HStack {
                                AppLocalizedText("Đăng nhập")
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
                                        .font(.system(size: 18))
                                        .accessibilityHidden(true)
                                    Text(verbatim: error)
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
                            .accessibilityIdentifier("auth.login.submit")

                            // MARK: Google Sign-In
                            OrDivider()
                                .padding(.vertical, FTSpacing.xs)

                            GoogleSignInButton(isLoading: viewModel.isLoading) {
                                Task { await viewModel.signInWithGoogle() }
                            }
                        }
                        .padding(FTSpacing.lg)
                        .ftCard(cornerRadius: FTRadius.xl)
                        .padding(.horizontal, FTSpacing.md)
                        
                        // MARK: Register Link
                        accountLayout {
                            AppLocalizedText("Chưa có tài khoản?")
                                .font(FTFont.subheadline())
                                .foregroundColor(.white.opacity(0.6))
                            
                            Button(action: onRegister) {
                                AppLocalizedText("Đăng ký ngay")
                                    .font(FTFont.subheadline().weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(FTColors.accent)
                                    .frame(minHeight: FTControl.minimumTarget)
                            }
                            .accessibilityIdentifier("auth.register.open")
                        }
                        .padding(.top, FTSpacing.lg)
                        .padding(.bottom, FTSpacing.xxl)
                    }
                }
            }
        }
        .hideKeyboardOnTap()
    }
    private var accountLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: FTSpacing.sm))
            : AnyLayout(HStackLayout(spacing: FTSpacing.xs))
    }

}
