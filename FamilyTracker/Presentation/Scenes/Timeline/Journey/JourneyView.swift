import SwiftUI

struct JourneyView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: JourneyViewModel
    @State private var panelExpanded = false

    init(viewModel: @autoclosure @escaping () -> JourneyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geometry in
                let panelHeight = panelHeight(for: geometry.size.height)
                ZStack(alignment: .bottom) {
                    LiveTrailMapView(
                        region: viewModel.trailRegion,
                        trackingUser: false,
                        showsUserLocation: false,
                        currentUserId: viewModel.userId,
                        members: [],
                        drawing: viewModel.trailDrawing,
                        bottomInset: viewModel.journeyEntries.isEmpty ? 0 : panelHeight,
                        onSelectMember: { _ in }, onUserMoved: {}
                    )
                    .accessibilityLabel(L10n.tr("journey.map.accessibility"))

                    if viewModel.usesLiveTrail,
                       viewModel.trailDrawing.lines.contains(where: { $0.style == .gps }) {
                        Text(verbatim: L10n.tr("trail.raw.label"))
                            .font(FTFont.caption())
                            .foregroundColor(FTColors.textPrimary)
                            .padding(FTSpacing.sm)
                            .background(FTColors.background)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.top, FTSpacing.md)
                            .padding(.leading, FTSpacing.md)
                            .padding(.trailing, 72)
                            .allowsHitTesting(false)
                    }

                    if let state = viewModel.loadError {
                        statusView(
                            icon: "exclamationmark.triangle",
                            message: state == .forbidden
                                ? L10n.tr("journey.map.error.forbidden")
                                : L10n.tr("journey.map.error.load"),
                            action: state == .forbidden ? dismiss.callAsFunction : retry
                        )
                    } else if viewModel.isLoading {
                        ProgressView {
                            Text(verbatim: L10n.tr("journey.loading"))
                        }
                        .padding(FTSpacing.lg)
                        .background(FTColors.background)
                    } else if viewModel.trailUnavailable {
                        statusView(icon: "wifi.exclamationmark", message: L10n.tr("trail.unavailable"),
                                   action: retry)
                    } else if viewModel.trailDrawing.fixes.isEmpty {
                        statusView(icon: "map", message: L10n.tr("journey.map.empty.day"), action: nil)
                    }

                    if !viewModel.trailDrawing.fixes.isEmpty {
                        if viewModel.trailDrawing.lines.isEmpty {
                            Text(verbatim: L10n.tr("journey.map.empty.geometry"))
                                .font(FTFont.caption())
                                .foregroundColor(FTColors.textPrimary)
                                .padding(FTSpacing.sm)
                                .background(FTColors.background)
                                .frame(maxWidth: .infinity, maxHeight: .infinity,
                                       alignment: .topLeading)
                                .padding(.top, FTSpacing.md)
                                .padding(.leading, FTSpacing.md)
                                .padding(.trailing, 72)
                        }

                        mapControls
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: .topTrailing)
                            .padding(FTSpacing.md)

                    }
                    if !viewModel.journeyEntries.isEmpty {
                        timelinePanel(height: panelHeight)
                    }
                }
                .background(FTColors.background)
            }
        }
        .background(FTColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .onDisappear { viewModel.cancelPendingWork() }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.tr("common.action.close"))

                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Text(verbatim: L10n.tr("journey.title.member", viewModel.memberName,
                                           language: AppLanguage(locale: locale)))
                        .font(FTFont.headline())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(viewModel.formattedDisplayDate(locale: locale))
                        .font(FTFont.caption())
                        .foregroundColor(FTColors.textSecondary)
                }
                Spacer(minLength: 0)
                Color.clear.frame(width: 44, height: 44)
            }
            .foregroundColor(FTColors.textPrimary)
            .padding(.horizontal, FTSpacing.sm)
            dayNavigation
        }
        .background(FTColors.background)
    }

    private var dayNavigation: some View {
        HStack {
            dayButton("journey.day.previous", icon: "chevron.left",
                      action: viewModel.goToPreviousDay)
            Spacer()
            if !viewModel.isToday {
                Button(action: viewModel.goToToday) {
                    Text(verbatim: L10n.tr("journey.day.today"))
                        .font(FTFont.caption())
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            Spacer()
            dayButton("journey.day.next", icon: "chevron.right",
                      action: viewModel.goToNextDay)
                .disabled(viewModel.isToday)
        }
        .padding(.horizontal, FTSpacing.md)
        .foregroundColor(FTColors.primary)
    }

    private func dayButton(_ key: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(L10n.tr(key), systemImage: icon)
                .font(FTFont.caption())
                .frame(minHeight: 44)
        }
    }

    private var mapControls: some View {
        Button(action: viewModel.recenter) {
            Image(systemName: "scope")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(FTColors.primary)
                .frame(width: 44, height: 44)
                .background(FTColors.background)
                .clipShape(Circle())
        }
        .accessibilityLabel(L10n.tr("journey.map.action.recenter"))
    }

    private func timelinePanel(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    panelExpanded.toggle()
                }
            } label: {
                VStack(spacing: 6) {
                    Capsule().fill(FTColors.textTertiary.opacity(0.5))
                        .frame(width: 36, height: 4)
                    HStack {
                        Text(verbatim: L10n.tr("journey.timeline.title"))
                            .font(FTFont.headline())
                        Spacer()
                        Image(systemName: panelExpanded ? "chevron.down" : "chevron.up")
                    }
                }
                .foregroundColor(FTColors.textPrimary)
                .padding(.horizontal, FTSpacing.md)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr(panelExpanded
                ? "journey.map.action.collapse" : "journey.map.action.expand"))
            .gesture(DragGesture(minimumDistance: 20).onEnded { gesture in
                if gesture.translation.height < -35 { panelExpanded = true }
                if gesture.translation.height > 35 { panelExpanded = false }
            })

            summaryStrip
            Divider()
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.journeyEntries.enumerated()), id: \.element.id) { index, entry in
                            timelineRow(entry, index: index)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal, FTSpacing.md)
                    .padding(.bottom, FTSpacing.md)
                }
                .refreshable { await viewModel.load() }
                .onChange(of: viewModel.selectedEntryID) { selected in
                    guard let selected else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        reader.scrollTo(selected, anchor: .center)
                    }
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(FTColors.background)
        .overlay(alignment: .top) { Divider() }
    }

    private var summaryStrip: some View {
        HStack(spacing: FTSpacing.sm) {
            summaryItem(value: "\(viewModel.stayPoints.count)", key: "Điểm dừng")
            Divider().frame(height: 28)
            summaryItem(value: L10n.duration(minutes: viewModel.totalStayMinutes,
                                             language: AppLanguage(locale: locale)),
                        key: "Thời gian ở")
            Divider().frame(height: 28)
            summaryItem(value: L10n.duration(minutes: viewModel.totalMovingMinutes,
                                             language: AppLanguage(locale: locale)),
                        key: "Di chuyển")
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.bottom, FTSpacing.sm)
    }

    private func summaryItem(value: String, key: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(FTFont.subheadline()).lineLimit(2).minimumScaleFactor(0.8)
            Text(verbatim: L10n.tr(key)).font(FTFont.caption()).lineLimit(2)
                .foregroundColor(FTColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func timelineRow(_ entry: JourneyEntry, index: Int) -> some View {
        let isFirst = index == 0
        let isLast = index == viewModel.journeyEntries.count - 1
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.select(entry)
        } label: {
            switch entry {
            case .stay(let stay):
                StayPointRow(stayPoint: stay, address: viewModel.address(for: stay),
                             isFirst: isFirst, isLast: isLast,
                             isSelected: viewModel.selectedStayId == stay.id)
            case .moving(let segment):
                MovingSegmentRow(segment: segment, isFirst: isFirst, isLast: isLast)
                    .background(viewModel.selectedEntryID == entry.id
                        ? FTColors.primary.opacity(0.08) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(for: entry))
        .frame(minHeight: 44)
    }

    private func accessibilityText(for entry: JourneyEntry) -> String {
        let language = AppLanguage(locale: locale)
        switch entry {
        case .stay(let stay):
            return L10n.tr("journey.map.stay.accessibility",
                           L10n.time(stay.arrivalDate, language: language),
                           L10n.time(stay.departureDate, language: language),
                           L10n.duration(minutes: stay.durationMinutes, language: language),
                           L10n.message(viewModel.address(for: stay), language: language),
                           language: language)
        case .moving(let segment):
            return L10n.tr("journey.map.segment.accessibility",
                           L10n.time(segment.startDate, language: language),
                           L10n.time(segment.endDate, language: language),
                           L10n.duration(minutes: segment.durationMinutes, language: language),
                           language: language)
        }
    }

    private func statusView(icon: String, message: String, action: (() -> Void)?) -> some View {
        VStack(spacing: FTSpacing.sm) {
            Image(systemName: icon).font(.system(size: 26))
            Text(verbatim: message).multilineTextAlignment(.center)
            if let action {
                Button(action: action) {
                    Text(verbatim: L10n.tr(viewModel.loadError == .forbidden
                                          ? "common.action.close" : "common.action.retry"))
                        .frame(minWidth: 88, minHeight: 44)
                }
            }
        }
        .foregroundColor(FTColors.textPrimary)
        .padding(FTSpacing.lg)
        .background(FTColors.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func panelHeight(for available: CGFloat) -> CGFloat {
        let ratio: CGFloat = panelExpanded ? (dynamicTypeSize.isAccessibilitySize ? 0.78 : 0.65)
                                            : (dynamicTypeSize.isAccessibilitySize ? 0.4 : 0.32)
        return min(max(160, available * ratio), max(160, available - 96))
    }

    private func selectFromMap(_ id: String) {
        panelExpanded = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        viewModel.selectEntry(id: id)
    }

    private func retry() { Task { await viewModel.load() } }
}
