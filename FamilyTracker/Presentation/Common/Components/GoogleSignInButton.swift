// MARK: - GoogleSignInButton.swift
// Nút "Tiếp tục với Google" đúng chuẩn Google Brand Guidelines.
// Nền trắng, logo Google SVG dạng SF-compatible shapes, chữ Inter/Rounded.

import SwiftUI

struct GoogleSignInButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.26, green: 0.52, blue: 0.96)))
                        .frame(width: 20, height: 20)
                } else {
                    GoogleLogoView()
                        .frame(width: 20, height: 20)
                }

                Text(verbatim: L10n.tr(isLoading ? "Đang xác thực..." : "Tiếp tục với Google"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.20, green: 0.20, blue: 0.20))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(FTRadius.lg)
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Google Logo (4 màu chính xác theo brand guidelines)
// Vẽ bằng SwiftUI Shapes để không cần asset file.
private struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let r  = min(w, h) / 2

            // Vẽ 4 cung tròn màu Google
            let segments: [(start: Double, end: Double, color: Color)] = [
                (  -15,  90, Color(red: 0.26, green: 0.52, blue: 0.96)), // Blue
                (   90, 180, Color(red: 0.92, green: 0.26, blue: 0.21)), // Red (bottom-left)
                (  180, 255, Color(red: 0.99, green: 0.73, blue: 0.01)), // Yellow
                (  255, 345, Color(red: 0.20, green: 0.66, blue: 0.33))  // Green
            ]
            for seg in segments {
                var path = Path()
                path.addArc(center: CGPoint(x: cx, y: cy),
                            radius: r,
                            startAngle: .degrees(seg.start),
                            endAngle: .degrees(seg.end),
                            clockwise: false)
                // Stroke rộng = bán kính/2 để giả lập pie
                context.stroke(path, with: .color(seg.color),
                               style: StrokeStyle(lineWidth: r * 0.55))
            }

            // Khoét lỗ trắng giữa
            var hole = Path()
            hole.addEllipse(in: CGRect(x: cx - r * 0.35, y: cy - r * 0.35,
                                       width: r * 0.70, height: r * 0.70))
            context.fill(hole, with: .color(.white))
        }
    }
}

// MARK: - Divider "hoặc" dùng trong form
struct OrDivider: View {
    var body: some View {
        HStack(spacing: FTSpacing.sm) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
            Text(verbatim: L10n.tr("common.separator.or"))
                .font(FTFont.caption())
                .foregroundColor(.white.opacity(0.45))
                .fixedSize()
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.15).ignoresSafeArea()
        VStack(spacing: 20) {
            GoogleSignInButton(isLoading: false) {}
            GoogleSignInButton(isLoading: true) {}
            OrDivider()
        }
        .padding(24)
    }
}
#endif
