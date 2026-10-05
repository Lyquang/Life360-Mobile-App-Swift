// MARK: - HistoryView.swift
// Today's location points: summary, mini map, timeline.

import SwiftUI
import MapKit

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    private let onShowJourney: () -> Void

    @State private var showMap = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: @autoclosure @escaping () -> HistoryViewModel, onShowJourney: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onShowJourney = onShowJourney
    }

    var body: some View {
        ZStack {
            FTColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Đang tải lịch sử...")
                        .progressViewStyle(CircularProgressViewStyle(tint: FTColors.primary))
                    Spacer()
                } else if viewModel.historyEntries.isEmpty {
                    Spacer()
                    FTEmptyView(
                        icon: "mappin.slash",
                        title: "Chưa có lịch sử",
                        subtitle: viewModel.errorMessage ?? "Lịch sử vị trí hôm nay sẽ xuất hiện ở đây khi bạn di chuyển",
                        actionTitle: nil,
                        action: nil
                    )
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            summaryCard
                            if showMap {
                                miniMap.transition(.opacity.combined(with: .scale))
                            }
                            timeline
                        }
                    }
                    .refreshable { await viewModel.load() }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(FTColors.primary)
                    .frame(width: 36, height: 36)
                    .background(FTColors.primary.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Lịch sử vị trí")
                    .font(FTFont.title2())
                    .foregroundColor(FTColors.textPrimary)
                Text(viewModel.formattedDisplayDate)
                    .font(FTFont.caption())
                    .foregroundColor(FTColors.textSecondary)
            }

            Spacer()

            HStack(spacing: FTSpacing.sm) {
                pillButton(icon: "figure.walk.motion", title: "Lộ trình", color: FTColors.accent, action: onShowJourney)
                pillButton(icon: showMap ? "map.fill" : "map", title: showMap ? "Ẩn bản đồ" : "Xem bản đồ", color: FTColors.primary) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showMap.toggle() }
                }
            }
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.top, FTSpacing.md)
        .padding(.bottom, FTSpacing.sm)
    }

    private func pillButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title).font(FTFont.caption())
            }
            .foregroundColor(color)
            .padding(.horizontal, FTSpacing.sm)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .cornerRadius(FTRadius.full)
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(value: "\(viewModel.totalStops)", label: "Điểm dừng", icon: "mappin.circle.fill", color: FTColors.primary)
            Divider().frame(height: 40)
            summaryItem(value: viewModel.timeRange, label: "Khoảng thời gian", icon: "clock.fill", color: FTColors.accent)
            Divider().frame(height: 40)
            summaryItem(value: "Hôm nay", label: viewModel.displayDate, icon: "calendar", color: FTColors.warning)
        }
        .padding(FTSpacing.md)
        .ftCard()
        .padding(.horizontal, FTSpacing.md)
        .padding(.bottom, FTSpacing.md)
    }

    private func summaryItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(value)
                .font(FTFont.headline())
                .foregroundColor(FTColors.textPrimary)
            Text(label)
                .font(FTFont.caption())
                .foregroundColor(FTColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map

    private var miniMap: some View {
        Map(coordinateRegion: $viewModel.historyMapRegion, annotationItems: viewModel.historyEntries) { entry in
            MapAnnotation(coordinate: entry.coordinate) {
                ZStack {
                    Circle()
                        .fill(FTColors.primary.opacity(0.2))
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(FTColors.primary)
                        .frame(width: 8, height: 8)
                }
                .onTapGesture { viewModel.selectedEntry = entry }
            }
        }
        .frame(height: 220)
        .cornerRadius(FTRadius.lg)
        .padding(.horizontal, FTSpacing.md)
        .padding(.bottom, FTSpacing.md)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hành trình trong ngày")
                .font(FTFont.headline())
                .foregroundColor(FTColors.textPrimary)
                .padding(.horizontal, FTSpacing.md)
                .padding(.bottom, FTSpacing.sm)

            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.historyEntries.enumerated()), id: \.element.id) { index, entry in
                    HistoryTimelineRow(
                        entry: entry,
                        isFirst: index == 0,
                        isLast: index == viewModel.historyEntries.count - 1,
                        isSelected: viewModel.selectedEntry?.id == entry.id
                    )
                    .onTapGesture {
                        withAnimation {
                            viewModel.select(entry)
                            if !showMap { showMap = true }
                        }
                    }
                }
            }
            .padding(.horizontal, FTSpacing.md)
        }
    }
}

struct HistoryTimelineRow: View {
    let entry: LocationHistoryEntry
    let isFirst: Bool
    let isLast: Bool
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: FTSpacing.md) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : FTColors.primary.opacity(0.3))
                    .frame(width: 2, height: 16)

                ZStack {
                    Circle()
                        .fill(isSelected ? FTColors.primary : FTColors.primary.opacity(0.2))
                        .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                    if isFirst || isLast {
                        Circle()
                            .fill(FTColors.primary)
                            .frame(width: 8, height: 8)
                    }
                }
                .animation(.spring(), value: isSelected)

                Rectangle()
                    .fill(isLast ? Color.clear : FTColors.primary.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: FTSpacing.xs) {
                HStack {
                    Text(entry.formattedTime)
                        .font(FTFont.subheadline())
                        .foregroundColor(isSelected ? FTColors.primary : FTColors.textPrimary)
                        .fontWeight(isSelected ? .semibold : .regular)
                    if isFirst { tag("Bắt đầu", color: FTColors.accent) }
                    if isLast && !isFirst { tag("Mới nhất", color: FTColors.primary) }
                }

                Text("Lat: \(String(format: "%.5f", entry.latitude)), Lon: \(String(format: "%.5f", entry.longitude))")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(FTColors.textSecondary)

                if isSelected {
                    Label("Xem trên bản đồ", systemImage: "map.fill")
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.primary)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, FTSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: FTRadius.sm)
                .fill(isSelected ? FTColors.primary.opacity(0.05) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(FTFont.caption())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(FTRadius.full)
    }
}
