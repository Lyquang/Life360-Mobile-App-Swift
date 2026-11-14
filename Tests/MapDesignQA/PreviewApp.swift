import SwiftUI
import MapKit

/// Separate test app. No authentication, location manager or production API client.
@main
struct MapDesignQAApp: App {
    @StateObject private var appearance = AppearanceSettings()
    @StateObject private var language = LanguageSettingsViewModel(preferences: UserDefaultsLanguagePreferences())
    var body: some Scene {
        WindowGroup {
            QAContent()
                .environmentObject(appearance).environmentObject(language)
                .environment(\.locale, language.language.locale)
                .preferredColorScheme(appearance.selection.colorScheme)
        }
    }
}

private struct QAContent: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selected: MemberLocation?
    @State private var expanded = false
    @State private var searching = false
    @StateObject private var search = PlaceSearchViewModel(
        search: PlaceSearchUseCases(repository: FixtureSearch()),
        history: SearchHistoryUseCases(repository: FixtureHistory(), accountID: "synthetic-qa"))
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 10.78, longitude: 106.69),
                                                  span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015))
    private let members = [
        MemberLocation(id: "qa-linh", name: "Linh Nguyễn", latitude: 10.78, longitude: 106.69,
                       batteryLevel: 72, timestamp: "2026-11-14T07:30:00Z", durationAtLocation: nil,
                       durationSince: nil, durationFormatted: nil),
        MemberLocation(id: "qa-minh", name: "Minh Trần", latitude: 10.783, longitude: 106.688,
                       batteryLevel: nil, timestamp: "invalid", durationAtLocation: nil,
                       durationSince: nil, durationFormatted: nil)
    ]
    private var mode: String { UserDefaults.standard.string(forKey: "qa.screen") ?? "map" }

    var body: some View {
        NavigationStack {
            if mode == "appearance" {
                AppearanceSettingsView()
            } else {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        Map(coordinateRegion: $region, annotationItems: members) { member in
                            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: member.latitude, longitude: member.longitude)) {
                                Button { selected = member } label: {
                                    MapMemberPin(memberLocation: member, isCurrentUser: false)
                                }
                                .accessibilityLabel(member.name)
                            }
                        }.ignoresSafeArea(edges: .top)
                        VStack(spacing: FTSpacing.sm) {
                            Spacer()
                            LiveMapControls(tracking: false, onRecenter: {}, onSOS: {})
                            Group {
                                if let selected {
                                    ScrollView {
                                        MemberInfoCard(member: selected, onDismiss: { self.selected = nil },
                                                       onNavigate: {}, onShowJourney: {})
                                    }.frame(height: geometry.size.height * 0.62)
                                } else {
                                    MapMembersPanel(members: members, expanded: expanded,
                                                    onToggle: { expanded.toggle() }, onSelect: { selected = $0 })
                                        .frame(height: expanded || textSize.isAccessibilitySize ? geometry.size.height * 0.62 : 142)
                                }
                            }.background(FTColors.background, in: RoundedRectangle(cornerRadius: FTRadius.xl))
                        }.padding(FTSpacing.sm)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: FTSpacing.sm) {
                        LiveMapHeader(memberCount: members.count, onMembers: { expanded.toggle() }, onSearch: {
                            search.open(in: PlaceSearchRegion(center: GeoPoint(latitude: 10.78, longitude: 106.69),
                                                             latitudeDelta: 0.015, longitudeDelta: 0.015))
                            searching = true
                        })
                        if mode == "offline" { MapConnectionNotice().padding(.horizontal, FTSpacing.md) }
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .onAppear { if mode == "member" { selected = members[0] } }
                .sheet(isPresented: $searching, onDismiss: search.stop) {
                    NavigationStack {
                        PlaceSearchView(viewModel: search, onClose: { searching = false }, onSelect: { _ in searching = false })
                    }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
                }
            }
        }
    }
}

@MainActor private final class FixtureSearch: PlaceSearchRepository {
    private let result = PlaceSearchResult(id: "qa-park", name: "Công viên QA", address: "Địa điểm giả lập",
                                          point: GeoPoint(latitude: 10.78, longitude: 106.69))
    func suggestions(for query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchSuggestion] {
        [PlaceSearchSuggestion(id: "qa-park", title: result.name, subtitle: result.address)]
    }
    func search(query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] { [result] }
    func resolve(_ suggestion: PlaceSearchSuggestion, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] { [result] }
    func cancel() {}
}
@MainActor private final class FixtureHistory: SearchHistoryRepository {
    func recentSearches(for accountID: String) throws -> [RecentPlaceSearch] { [] }
    func record(query: String, for accountID: String) throws {}
    func remove(id: String, for accountID: String) throws {}
    func clear(for accountID: String) throws {}
}
