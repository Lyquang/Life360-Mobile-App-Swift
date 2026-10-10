import SwiftUI

// MARK: - FTErrorView
struct FTErrorView: View {
    let message: String
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(FTColors.warning)

            AppLocalizedText(message)
                .font(FTFont.body())
                .foregroundColor(FTColors.textSecondary)
                .multilineTextAlignment(.center)

            if let retry = onRetry {
                Button("Thử lại", action: retry)
                    .font(FTFont.subheadline())
                    .foregroundColor(FTColors.primary)
            }
        }
        .padding(FTSpacing.xl)
    }
}

// MARK: - FTEmptyView
struct FTEmptyView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: FTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(FTColors.textTertiary)
                .padding(.bottom, FTSpacing.sm)

            AppLocalizedText(title)
                .font(FTFont.title3())
                .foregroundColor(FTColors.textPrimary)

            AppLocalizedText(subtitle)
                .font(FTFont.body())
                .foregroundColor(FTColors.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    AppLocalizedText(actionTitle)
                        .font(FTFont.headline())
                        .foregroundColor(.white)
                        .padding(.horizontal, FTSpacing.xl)
                        .padding(.vertical, FTSpacing.sm)
                        .background(FTColors.primary)
                        .cornerRadius(FTRadius.full)
                }
                .padding(.top, FTSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FTSpacing.xxl)
    }
}

// MARK: - FTLoadingOverlay
struct FTLoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: FTSpacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: FTColors.primary))
                    .scaleEffect(1.5)

                AppLocalizedText(message)
                    .font(FTFont.subheadline())
                    .foregroundColor(FTColors.textPrimary)
            }
            .padding(FTSpacing.xl)
            .background(FTColors.card)
            .cornerRadius(FTRadius.lg)
            .shadow(radius: 20)
        }
    }
}

// MARK: - FTToast
struct FTToast: View {
    let message: String
    let type: ToastType

    enum ToastType {
        case success, error, info

        var color: Color {
            switch self {
            case .success: return FTColors.accent
            case .error:   return FTColors.danger
            case .info:    return FTColors.primary
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error:   return "xmark.circle.fill"
            case .info:    return "info.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            AppLocalizedText(message)
                .font(FTFont.subheadline())
                .foregroundColor(FTColors.textPrimary)
                .lineLimit(2)
        }
        .padding(FTSpacing.md)
        .background(FTColors.card)
        .cornerRadius(FTRadius.full)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, FTSpacing.md)
    }
}

extension View {
    /// Bottom success toast that hides itself after 3 seconds.
    func ftSuccessToast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .bottom) {
            if let text = message.wrappedValue {
                FTToast(message: text, type: .success)
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation { message.wrappedValue = nil }
                    }
            }
        }
    }

    /// Error alert bound to an optional message.
    func ftErrorAlert(_ message: Binding<String?>) -> some View {
        alert("Lỗi", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK") { message.wrappedValue = nil }
        } message: {
            AppLocalizedText(message.wrappedValue ?? "")
        }
    }
}
