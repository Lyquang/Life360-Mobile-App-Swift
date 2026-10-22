import SwiftUI
import Combine

/// Tab container after login. Owns feature coordinators and cross-feature routing
/// (SOS -> Map, Circle -> Chat, notification deeplinks).
@MainActor
final class MainTabCoordinator: ObservableObject {
    enum Tab: Hashable {
        case map, chatHub, duration, journey, places, profile
    }

    @Published var selectedTab: Tab = .map
    @Published private(set) var chatUnreadBadge = 0

    let currentUser: User
    let map: MapCoordinator
    let chatHub: ChatHubCoordinator
    let timeline: TimelineCoordinator
    let places: PlacesCoordinator
    let emergency: EmergencyCoordinator

    private let container: AppContainer
    private let onLogout: () -> Void
    private let onLogoutAll: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var badgeCancellable: AnyCancellable?
    private var sharingStartupTask: Task<Void, Never>?
    private var privacyRetryTask: Task<Void, Never>?

    init(container: AppContainer, currentUser: User, onLogout: @escaping () -> Void,
         onLogoutAll: @escaping () -> Void) {
        self.container = container
        self.currentUser = currentUser
        self.onLogout = onLogout
        self.onLogoutAll = onLogoutAll

        map = MapCoordinator(container: container, currentUser: currentUser)
        chatHub = ChatHubCoordinator(container: container, currentUser: currentUser)
        timeline = TimelineCoordinator(container: container, currentUser: currentUser)
        places = PlacesCoordinator(container: container)
        emergency = EmergencyCoordinator(observeSOS: container.observeSOSAlerts, sendSOS: container.sendSOS)

        map.onRequestSOS = { [weak self] in self?.emergency.requestSOS() }
        emergency.onShowLocation = { [weak self] alert in self?.showOnMap(alert.point) }
        badgeCancellable = chatHub.viewModel.$totalUnread
            .removeDuplicates()
            .sink { [weak self] count in self?.chatUnreadBadge = count }
    }

    func start() {
        chatHub.viewModel.start()
        chatHub.viewModel.refreshInBackground()
        sharingStartupTask = Task { [weak self] in
            await self?.container.startLocationSharingIfAllowed()
        }
        let connectionChanges = container.observeConnectionState()
        privacyRetryTask = Task { [weak self] in
            for await state in connectionChanges {
                guard !Task.isCancelled, let self else { return }
                if state == .connected, self.container.locationSharingStatus == .pendingPause {
                    await self.container.startLocationSharingIfAllowed()
                }
            }
        }
        container.notificationBridge.start()
        emergency.start()

        container.pushService.$pendingDeeplink
            .compactMap { $0 }
            .sink { [weak self] deeplink in
                self?.handle(deeplink)
                self?.container.pushService.pendingDeeplink = nil
            }
            .store(in: &cancellables)

        Task { await container.pushService.requestAuthorization() }
    }

    func stop() {
        sharingStartupTask?.cancel()
        sharingStartupTask = nil
        privacyRetryTask?.cancel()
        privacyRetryTask = nil
        container.shareLocation.stop()
        chatHub.stop()
        emergency.stop()
        container.notificationBridge.stop()
        cancellables.removeAll()
    }

    func logout() {
        onLogout()
    }

    func logoutAll() { onLogoutAll() }

    func showOnMap(_ point: GeoPoint?) {
        selectedTab = .map
        map.popToRoot()
        if let point { map.focus(on: point) }
    }

    func openConversation(id: String, title: String) {
        selectedTab = .chatHub
        chatHub.openConversation(id: id, title: title)
    }

    func openDirectConversation(_ conversation: Conversation, fallbackTitle: String) {
        selectedTab = .chatHub
        chatHub.openDirectConversation(conversation, fallbackTitle: fallbackTitle)
    }

    func handle(_ deeplink: NotificationDeeplink) {
        switch deeplink {
        case .sos(let userId), .member(let userId):
            selectedTab = .map
            map.focus(onMember: userId)
        case .conversation(let id):
            openConversation(id: id, title: "")
        }
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
            onLogout: { [weak self] in self?.logout() },
            onLogoutAll: { [weak self] in self?.logoutAll() },
            currentLocationSharingStatus: { [weak container] in
                container?.locationSharingStatus ?? .unavailable
            },
            refreshLocationSharing: { [weak container] in
                await container?.refreshLocationSharingStatus() ?? .unavailable
            },
            pauseLocationSharing: { [weak container] in
                guard let container else { throw DomainError.unauthorized }
                try await container.pauseLocationSharing()
            },
            resumeLocationSharing: { [weak container] in
                guard let container else { throw DomainError.unauthorized }
                try await container.resumeLocationSharing()
            }
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

            ChatHubCoordinatorView(coordinator: coordinator.chatHub)
                .tabItem { tabLabel("chat.hub.title", icon: "bubble.left.and.bubble.right", tab: .chatHub) }
                .badge(coordinator.chatUnreadBadge)
                .tag(MainTabCoordinator.Tab.chatHub)

            DurationView(viewModel: coordinator.makeDurationViewModel())
                .tabItem {
                    Label {
                        Text(verbatim: L10n.tr("Ở đây"))
                    } icon: {
                        Image(systemName: coordinator.selectedTab == .duration
                              ? "clock.badge.checkmark.fill" : "clock.badge.checkmark")
                    }
                }
                .tag(MainTabCoordinator.Tab.duration)

            TimelineCoordinatorView(coordinator: coordinator.timeline)
                .tabItem {
                    Label {
                        Text(verbatim: L10n.tr("Lộ trình"))
                    } icon: {
                        Image(systemName: coordinator.selectedTab == .journey ? "figure.walk.motion" : "figure.walk")
                    }
                }
                .tag(MainTabCoordinator.Tab.journey)

            PlacesCoordinatorView(coordinator: coordinator.places)
                .tabItem { tabLabel("Địa điểm", icon: "star", tab: .places) }
                .tag(MainTabCoordinator.Tab.places)

            ProfileView(viewModel: coordinator.makeProfileViewModel())
                .tabItem {
                    Label { Text(verbatim: L10n.tr("Cá nhân")) } icon: { Image(systemName: "person.fill") }
                }
                .tag(MainTabCoordinator.Tab.profile)
        }
        .tint(FTColors.primary)
        .modifier(EmergencyPresentation(coordinator: coordinator.emergency))
        .onAppear(perform: configureTabBarAppearance)
    }

    private func tabLabel(_ title: String, icon: String, tab: MainTabCoordinator.Tab) -> some View {
        Label {
            Text(verbatim: L10n.tr(title))
        } icon: {
            Image(systemName: coordinator.selectedTab == tab ? "\(icon).fill" : icon)
        }
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
