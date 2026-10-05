// MARK: - JourneyView.swift
// Day journey timeline (Feature 2): summary, map with stay points, stay/moving timeline, day navigation.

import SwiftUI
import MapKit

struct JourneyView: View {
    @StateObject private var viewModel: JourneyViewModel
    @State private var showMap = true
    @Environment(\.dismiss) private var dismiss

    init(viewModel: @autoclosure @escaping () -> JourneyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            FTColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Đang phân tích lộ trình...")
                        .progressViewStyle(CircularProgressViewStyle(tint: FTColors.primary))
                    Spacer()
                } else if viewModel.journeyEntries.isEmpty {
                    Spacer()
                    FTEmptyView(
                        icon: "figure.walk.motion",
                        title: "Chưa có dữ liệu",
                        subtitle: viewModel.errorMessage
                            ?? "Lộ trình của \(viewModel.memberName) trong ngày này sẽ xuất hiện ở đây khi có GPS data.",
                        actionTitle: nil,
                        action: nil
                    )
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            summaryCard
                            if showMap {
                                journeyMap.transition(.opacity.combined(with: .scale))
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
        VStack(spacing: 0) {
            HStack {
                circleIconButton("chevron.left") { dismiss() }

                Spacer()

                VStack(spacing: 2) {
                    Text("Lộ trình của \(viewModel.memberName)")
                        .font(FTFont.headline())
                        .foregroundColor(FTColors.textPrimary)
                    Text(viewModel.formattedDisplayDate)
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textSecondary)
                }

                Spacer()

                circleIconButton(showMap ? "map.fill" : "map") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showMap.toggle() }
                }
            }
            .padding(.horizontal, FTSpacing.md)
            .padding(.top, FTSpacing.md)
            .padding(.bottom, FTSpacing.sm)

            dayNavigation
        }
    }

    private func circleIconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FTColors.primary)
                .frame(width: 36, height: 36)
                .background(FTColors.primary.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private var dayNavigation: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation { viewModel.goToPreviousDay() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Trước")
                }
                .font(FTFont.caption())
                .foregroundColor(FTColors.primary)
                .padding(.horizontal, FTSpacing.md)
                .padding(.vertical, 8)
            }

            Spacer()

            if !viewModel.isToday {
                Button(action: viewModel.goToToday) {
                    Text("Hôm nay")
                        .font(FTFont.caption())
                        .foregroundColor(.white)
                        .padding(.horizontal, FTSpacing.md)
                        .padding(.vertical, 5)
                        .background(FTColors.primaryGradient)
                        .cornerRadius(FTRadius.full)
                }
            }

            Spacer()

            Button {
                withAnimation { viewModel.goToNextDay() }
            } label: {
                HStack(spacing: 4) {
                    Text("Sau")
                    Image(systemName: "chevron.right")
                }
                .font(FTFont.caption())
                .foregroundColor(viewModel.isToday ? FTColors.textTertiary : FTColors.primary)
                .padding(.horizontal, FTSpacing.md)
                .padding(.vertical, 8)
            }
            .disabled(viewModel.isToday)
        }
        .background(FTColors.card.opacity(0.6))
        .overlay(
            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.3))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: FTSpacing.sm) {
            HStack(spacing: 0) {
                summaryItem(value: "\(viewModel.stayPoints.count)", label: "Điểm dừng", icon: "mappin.circle.fill", color: FTColors.primary)
                Divider().frame(height: 44)
                summaryItem(value: viewModel.summary?.totalStayFormatted ?? "--", label: "Thời gian ở", icon: "clock.fill", color: FTColors.accent)
                Divider().frame(height: 44)
                summaryItem(value: viewModel.summary?.totalMovingFormatted ?? "--", label: "Di chuyển", icon: "figure.walk", color: FTColors.warning)
            }
            .padding(FTSpacing.md)
            .ftCard()
            .padding(.horizontal, FTSpacing.md)

            if let first = viewModel.summary?.firstSeenAt, let last = viewModel.summary?.lastSeenAt {
                HStack {
                    Label(DisplayFormat.time(iso: first), systemImage: "sunrise.fill")
                    Spacer()
                    Label(DisplayFormat.time(iso: last), systemImage: "sunset.fill")
                }
                .font(FTFont.caption())
                .foregroundColor(FTColors.textSecondary)
                .padding(.horizontal, FTSpacing.xl)
            }
        }
        .padding(.vertical, FTSpacing.md)
    }

    private func summaryItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(value)
                .font(FTFont.headline())
                .foregroundColor(FTColors.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(FTFont.caption())
                .foregroundColor(FTColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map

    private var journeyMap: some View {
        Map(coordinateRegion: $viewModel.journeyMapRegion, annotationItems: viewModel.stayPoints) { stayPoint in
            MapAnnotation(coordinate: stayPoint.coordinate) {
                StayPointMapMarker(
                    stayPoint: stayPoint,
                    isSelected: viewModel.selectedStayId == stayPoint.id
                )
                .onTapGesture {
                    withAnimation { viewModel.select(.stay(stayPoint)) }
                }
            }
        }
        .frame(height: 240)
        .cornerRadius(FTRadius.lg)
        .padding(.horizontal, FTSpacing.md)
        .padding(.bottom, FTSpacing.sm)
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
                ForEach(Array(viewModel.journeyEntries.enumerated()), id: \.element.id) { index, entry in
                    let isFirst = index == 0
                    let isLast = index == viewModel.journeyEntries.count - 1
                    switch entry {
                    case .stay(let stayPoint):
                        StayPointRow(
                            stayPoint: stayPoint,
                            address: viewModel.address(for: stayPoint),
                            isFirst: isFirst,
                            isLast: isLast,
                            isSelected: viewModel.selectedStayId == stayPoint.id
                        )
                        .onTapGesture {
                            withAnimation {
                                viewModel.select(entry)
                                if !showMap { showMap = true }
                            }
                        }
                    case .moving(let segment):
                        MovingSegmentRow(segment: segment, isFirst: isFirst, isLast: isLast)
                    }
                }
            }
            .padding(.horizontal, FTSpacing.md)
            .padding(.bottom, FTSpacing.xl)
        }
    }
}
