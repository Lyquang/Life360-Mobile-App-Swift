import SwiftUI
import MapKit

struct LiveMapView: View {
    @ObservedObject var viewModel: LiveMapViewModel
    @ObservedObject var coordinator: MapCoordinator
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var showMemberList = false
    @State private var selectedMemberID: String?
    @State private var visibleSearchRegion: PlaceSearchRegion?
    @State private var panelHeight: CGFloat = 0

    private var selectedMember: MemberLocation? {
        viewModel.memberLocations.first { $0.id == selectedMemberID }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                LiveTrailMapView(
                    region: viewModel.mapRegion, trackingUser: viewModel.isTrackingUser,
                    showsUserLocation: true, currentUserId: viewModel.currentUserId,
                    members: viewModel.memberLocations, drawing: viewModel.trailDrawing,
                    selectedPlace: coordinator.selectedPlace, bottomInset: panelHeight,
                    onSelectMember: selectMember, onUserMoved: viewModel.userMovedMap,
                    onRegionChanged: updateSearchRegion
                )
                .ignoresSafeArea(edges: .top)
                VStack(spacing: FTSpacing.sm) {
                    Spacer(minLength: FTSpacing.sm)
                    controls
                    bottomPanel(availableHeight: geometry.size.height)
                        .background(FTColors.background, in: RoundedRectangle(cornerRadius: FTRadius.xl))
                        .background(GeometryReader { proxy in
                            Color.clear.preference(key: MapPanelHeight.self, value: proxy.size.height)
                        })
                }
                .padding(.horizontal, FTSpacing.sm).padding(.bottom, FTSpacing.sm)
            }
            .onPreferenceChange(MapPanelHeight.self) { height in
                if abs(panelHeight - height) > 1 { panelHeight = height }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: FTSpacing.sm) {
                LiveMapHeader(memberCount: viewModel.memberLocations.count,
                              onMembers: { showMemberList.toggle(); selectedMemberID = nil; coordinator.clearSelectedPlace() },
                              onSearch: openSearch)
                statusNotices.padding(.horizontal, FTSpacing.md)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshOnForeground()
        }
    }

    @ViewBuilder private var statusNotices: some View {
        if viewModel.connectionState == .disconnected { MapConnectionNotice() }
        if viewModel.sosFollowActive {
            Text(verbatim: viewModel.sosLocationUpdatedAt.map { L10n.tr("sos.live.updated", DisplayFormat.time($0)) }
                 ?? L10n.tr("sos.live.no_time"))
                .font(FTFont.caption()).padding(FTSpacing.sm).background(FTColors.background)
        }
        if viewModel.trailUnavailable {
            Button(action: viewModel.refreshTrail) {
                Label(L10n.tr("trail.unavailable"), systemImage: "arrow.clockwise")
                    .font(FTFont.caption()).padding(FTSpacing.sm).frame(minHeight: 44)
                    .background(FTColors.background, in: RoundedRectangle(cornerRadius: FTRadius.sm))
            }
        }
        if viewModel.trailDrawing.lines.contains(where: { $0.style == .gps }) {
            AppLocalizedText("trail.raw.label").font(FTFont.caption())
                .padding(FTSpacing.xs).background(FTColors.background)
        }
    }

    private var controls: some View {
        LiveMapControls(tracking: viewModel.isTrackingUser,
                        onRecenter: { coordinator.clearSelectedPlace(); viewModel.centerOnUser() },
                        onSOS: coordinator.requestSOS)
    }

    @ViewBuilder private func bottomPanel(availableHeight: CGFloat) -> some View {
        if let member = selectedMember {
            ScrollView {
                MemberInfoCard(member: member, onDismiss: { selectedMemberID = nil },
                               onNavigate: { viewModel.centerOnMember(member) },
                               onShowJourney: { coordinator.showJourney(of: member) })
            }
            .frame(height: min(availableHeight * 0.62, textSize.isAccessibilitySize ? 420 : 300))
        } else if let place = coordinator.selectedPlace {
            ScrollView {
                HStack(alignment: .top, spacing: FTSpacing.sm) {
                    Image(systemName: "mappin.circle.fill").foregroundColor(FTColors.primary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: FTSpacing.xs) {
                        Text(verbatim: place.name).font(FTFont.headline())
                        if !place.address.isEmpty { Text(verbatim: place.address).font(FTFont.footnote()) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: coordinator.clearSelectedPlace) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel(L10n.tr("search.action.clear_place"))
                }.padding(FTSpacing.md)
            }
            .frame(height: min(availableHeight * 0.35, textSize.isAccessibilitySize ? 260 : 160))
            .accessibilityIdentifier("search.selected_place")
        } else {
            MapMembersPanel(members: viewModel.memberLocations, expanded: showMemberList,
                            onToggle: { showMemberList.toggle() }, onSelect: selectMember)
                .frame(height: viewModel.memberLocations.isEmpty ? 116 :
                    (showMemberList || textSize.isAccessibilitySize ? availableHeight * 0.62 : 142))
        }
    }

    private func selectMember(_ member: MemberLocation) {
        coordinator.clearSelectedPlace()
        selectedMemberID = member.id
        viewModel.centerOnMember(member)
    }

    private func openSearch() {
        selectedMemberID = nil
        let region = viewModel.mapRegion
        coordinator.openSearch(in: visibleSearchRegion ?? PlaceSearchRegion(
            center: GeoPoint(latitude: region.center.latitude, longitude: region.center.longitude),
            latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta))
    }

    private func updateSearchRegion(_ region: MKCoordinateRegion) {
        let next = PlaceSearchRegion(center: GeoPoint(latitude: region.center.latitude, longitude: region.center.longitude),
                                     latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta)
        if visibleSearchRegion != next { visibleSearchRegion = next }
    }
}

private struct MapPanelHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
