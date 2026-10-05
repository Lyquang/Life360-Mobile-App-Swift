import SwiftUI

/// Map marker for a stay point.
struct StayPointMapMarker: View {
    let stayPoint: StayPoint
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isSelected ? FTColors.primaryGradient : LinearGradient(
                        colors: [FTColors.accent, FTColors.accent.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                    .shadow(color: FTColors.primary.opacity(0.4), radius: isSelected ? 8 : 4)
                Image(systemName: "mappin.fill")
                    .font(.system(size: isSelected ? 16 : 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .animation(.spring(), value: isSelected)

            Text(stayPoint.durationFormatted)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(FTColors.primary.opacity(0.85)))

            Triangle()
                .fill(FTColors.accent)
                .frame(width: 10, height: 6)
        }
    }
}

/// Timeline row for a stay point.
struct StayPointRow: View {
    let stayPoint: StayPoint
    let address: String
    let isFirst: Bool
    let isLast: Bool
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : FTColors.accent.opacity(0.3))
                    .frame(width: 2, height: 16)

                ZStack {
                    Circle()
                        .fill(isSelected ? FTColors.primaryGradient : LinearGradient(
                            colors: [FTColors.accent, FTColors.accent.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: isSelected ? 18 : 14, height: isSelected ? 18 : 14)
                        .shadow(color: FTColors.accent.opacity(0.4), radius: 4)
                    Image(systemName: "mappin.fill")
                        .font(.system(size: isSelected ? 8 : 6))
                        .foregroundColor(.white)
                }
                .animation(.spring(), value: isSelected)

                Rectangle()
                    .fill(isLast ? Color.clear : FTColors.primary.opacity(0.15))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(stayPoint.arrivalTime) – \(stayPoint.departureTime)")
                        .font(FTFont.subheadline())
                        .foregroundColor(isSelected ? FTColors.primary : FTColors.textPrimary)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Spacer()
                    Text(stayPoint.durationFormatted)
                        .font(FTFont.caption())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FTColors.accent)
                        .cornerRadius(FTRadius.full)
                }

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(FTColors.textTertiary)
                    Text(address)
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textSecondary)
                        .lineLimit(2)
                }

                if isSelected {
                    HStack(spacing: FTSpacing.lg) {
                        detail("Đến", stayPoint.arrivalTime, color: FTColors.textPrimary)
                        detail("Rời", stayPoint.departureTime, color: FTColors.textPrimary)
                        detail("Ở lại", stayPoint.durationFormatted, color: FTColors.accent)
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.vertical, FTSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: FTRadius.sm)
                .fill(isSelected ? FTColors.primary.opacity(0.06) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private func detail(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(FTColors.textTertiary)
            Text(value)
                .font(FTFont.caption())
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
}

/// Timeline row for movement between stay points.
struct MovingSegmentRow: View {
    let segment: MovingSegment
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .center, spacing: FTSpacing.md) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : FTColors.primary.opacity(0.15))
                    .frame(width: 2, height: 10)
                ZStack {
                    Circle()
                        .stroke(FTColors.primary.opacity(0.4), lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(FTColors.primary.opacity(0.6))
                }
                Rectangle()
                    .fill(isLast ? Color.clear : FTColors.primary.opacity(0.15))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 13))
                    Text("Di chuyển · \(segment.durationFormatted)")
                        .font(FTFont.caption())
                }
                .foregroundColor(FTColors.textTertiary)

                Spacer()

                Text(segment.startTimeFormatted)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(FTColors.textTertiary.opacity(0.7))
            }
            .padding(.vertical, FTSpacing.sm)
        }
        .padding(.vertical, 2)
    }
}
