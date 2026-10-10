import SwiftUI
import Combine

/// Tab container after login. Owns feature coordinators and cross-feature routing
/// (SOS → Map, Circle → Chat, notification deeplinks).
@MainActor
final class MainTabCoordinator: ObservableObject {
    enum Tab: Hashable {
        case map, circles, chat, duration, journey, places, profile
    }

    @Published var selectedTab: Tab = .map
    @Published var showsNotificationSettings = false
    @Published var notificationRouteError: String?
    private var routeTask: Task<Void, Never>?

    let currentUser: User
    let map: MapCoordinator
    let circles: CirclesCoordinator
    let chat: ChatCoordinator
    let timeline: TimelineCoordinator
    let places: PlacesCoordinator
    let emergency: EmergencyCoordinator

    private let container: AppContainer
    private let onLogout: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(container: AppContainer, currentUser: User, onLogout: @escaping () -> Void) {
        self.container = container
        self.currentUser = currentUser
        self.onLogout = onLogout

        map = MapCoordinator(container: container, currentUser: currentUser)
        circles = CirclesCoordinator(container: container)
        chat = ChatCoordinator(container: container, currentUser: currentUser)
        timeline = TimelineCoordinator(container: container, currentUser: currentUser)
        places = PlacesCoordinator(container: container)
        emergency = EmergencyCoordinator(observeSOS: container.observeSOSAlerts, sendSOS: container.sendSOS)

        map.onRequestSOS = { [weak self] in self?.emergency.requestSOS() }
        emergency.onShowLocation = { [weak self] alert in self?.showOnMap(alert.point) }
        circles.onOpenConversation = { [weak self] id, title in self?.openConversation(id: id, title: title) }
    }

    func start() {
        container.pushService.activate(userId: currentUser.id)
        container.shareLocation.start()
        container.notificationBridge.start()
        emergency.start()

        container.pushService.$pendingDeeplink
            .compactMap { $0 }
            .sink { [weak self] deeplink in
                self?.handle(deeplink)
                self?.container.pushService.pendingDeeplink = nil
            }
            .store(in: &cancellables)

        Task { await container.pushService.refreshPermission() }
    }

    func stop() {
        routeTask?.cancel()
        emergency.stop()
        container.notificationBridge.stop()
        cancellables.removeAll()
    }

    func logout() {
        onLogout()
    }

    func showOnMap(_ point: GeoPoint?) {
        selectedTab = .map
        map.popToRoot()
        if let point { map.focus(on: point) }
    }

    func openConversation(id: String, title: String) {
        selectedTab = .chat
        chat.openConversation(id: id, title: title)
    }

    func handle(_ deeplink: NotificationDeeplink) {
        routeTask?.cancel()
        routeTask = Task { [weak self] in
            guard let self else { return }
            do {
                switch deeplink {
                case .conversation(let id):
                    let conversations = try await container.fetchConversations()
                    try Task.checkCancellation()
                    guard let conversation = conversations.first(where: { $0.id == id }) else {
                        throw DomainError.validation("Không còn quyền truy cập nội dung thông báo.")
                    }
                    showsNotificationSettings = false
                    openConversation(id: id, title: conversation.displayName)
                case .sos(let userId), .member(let userId):
                    let circles = try await container.fetchMyCircles()
                    var allowed = false
                    for circle in circles {
                        let members = try await container.fetchCircleMembers(circleId: circle.id)
                        if members.contains(where: { $0.id == userId }) { allowed = true; break }
                    }
                    try Task.checkCancellation()
                    guard allowed else { throw DomainError.validation("Không còn quyền truy cập nội dung thông báo.") }
                    showsNotificationSettings = false
                    selectedTab = .map
                    map.focus(onMember: userId)
                }
            } catch is CancellationError { return }
            catch { notificationRouteError = error.localizedDescription }
        }
    }

    func makeNotificationSettingsViewModel() -> NotificationSettingsViewModel {
        NotificationSettingsViewModel(repository: container.pushService)
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Factories for tabs without their own navigation

    func makeDurationViewModel() -> DurationViewModel {
        DurationViewModel(observeMemberLocations: container.observeMemberLocations, observeStayAlerts: container.observeStayAlerts)
    }

    func makeProfileViewModel() -> ProfileViewModel {
        let url = container.environment.apiBaseURL
        let host = url.host.map { host in url.port.map { "\(host):\($0)" } ?? host } ?? url.absoluteString
        return ProfileViewModel(
            user: currentUser,
            backendHost: host,
            observeConnection: container.observeConnectionState,
            onLogout: { [weak self] in self?.logout() }
        )
    }
}

struct MainTabView: View {
    @ObservedObject var coordinator: MainTabCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            MapCoordinatorView(coordinator: coordinator.map)
                .tabItem { tabLabel("Bản đồ", icon: "map", tab: .map) }
                .tag(MainTabCoordinator.Tab.map)

            CirclesCoordinatorView(coordinator: coordinator.circles)
                .tabItem { tabLabel("Nhóm", icon: "person.3", tab: .circles) }
                .tag(MainTabCoordinator.Tab.circles)

            ChatCoordinatorView(coordinator: coordinator.chat)
                .tabItem { tabLabel("Tin nhắn", icon: "bubble.left.and.bubble.right", tab: .chat) }
                .tag(MainTabCoordinator.Tab.chat)

            DurationView(viewModel: coordinator.makeDurationViewModel())
                .tabItem {
                    Label("Ở đây", systemImage: coordinator.selectedTab == .duration
                          ? "clock.badge.checkmark.fill" : "clock.badge.checkmark")
                }
                .tag(MainTabCoordinator.Tab.duration)

            TimelineCoordinatorView(coordinator: coordinator.timeline)
                .tabItem {
                    Label("Lộ trình", systemImage: coordinator.selectedTab == .journey ? "figure.walk.motion" : "figure.walk")
                }
                .tag(MainTabCoordinator.Tab.journey)

            PlacesCoordinatorView(coordinator: coordinator.places)
                .tabItem { tabLabel("Địa điểm", icon: "star", tab: .places) }
                .tag(MainTabCoordinator.Tab.places)

            ProfileView(viewModel: coordinator.makeProfileViewModel(),
                        onNotifications: { coordinator.showsNotificationSettings = true })
                .tabItem { Label("Cá nhân", systemImage: "person.fill") }
                .tag(MainTabCoordinator.Tab.profile)
        }
        .tint(FTColors.primary)
        .sheet(isPresented: $coordinator.showsNotificationSettings) {
            NotificationSettingsView(viewModel: coordinator.makeNotificationSettingsViewModel(),
                                     onOpenSettings: coordinator.openSystemNotificationSettings,
                                     onClose: { coordinator.showsNotificationSettings = false })
        }
        .ftErrorAlert($coordinator.notificationRouteError)
        .modifier(EmergencyPresentation(coordinator: coordinator.emergency))
        .onAppear(perform: configureTabBarAppearance)
    }

    private func tabLabel(_ title: String, icon: String, tab: MainTabCoordinator.Tab) -> some View {
        Label(LocalizedStringKey(title), systemImage: coordinator.selectedTab == tab ? "\(icon).fill" : icon)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowImage = UIImage()
        appearance.shadowColor = UIColor.clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
