// MARK: - SOSAlertBanner.swift
// Banner hiển thị khi nhận được SOS alert từ thành viên

import SwiftUI

struct SOSAlertBanner: View {
    let alert: SOSAlert
    let onDismiss: () -> Void
    let onNavigate: (() -> Void)?
    
    // Animation state
    @State private var isVisible = false
    @State private var isShaking = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: FTSpacing.md) {
                // Icon SOS với hiệu ứng pulse
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .scaleEffect(isShaking ? 1.3 : 1.0)
                        .opacity(isShaking ? 0.0 : 1.0)
                        .animation(
                            .easeOut(duration: 0.8).repeatForever(autoreverses: false),
                            value: isShaking
                        )
                    
                    Image(systemName: "sos")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("🚨 SOS Khẩn Cấp!")
                        .font(FTFont.headline())
                        .foregroundColor(.white)
                    
                    Text("\(alert.name): \(alert.message)")
                        .font(FTFont.subheadline())
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                    
                    if let groupName = alert.groupName {
                        Text("Nhóm: \(groupName)")
                            .font(FTFont.caption())
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Nút đóng
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(FTSpacing.md)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 0.5)
            
            // Nút Xem vị trí (nếu có coordinates)
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
        .background(FTColors.dangerGradient)
        .cornerRadius(FTRadius.lg)
        .shadow(color: FTColors.danger.opacity(0.4), radius: 16, x: 0, y: 8)
        .padding(.horizontal, FTSpacing.md)
        .offset(y: isVisible ? 0 : -200) // Slide down animation
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            isShaking = true
        }
    }
}
