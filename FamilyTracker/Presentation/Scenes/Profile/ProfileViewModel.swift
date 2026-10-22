import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var connectionState: RealtimeConnectionState
    @Published private(set) var locationSharingStatus: LocationSharingAccessState
    @Published private(set) var isChangingLocationSharing = false
    @Published private(set) var locationSharingError: String?

    let user: User
    let backendHost: String

    private let observeConnection: ObserveConnectionStateUseCase
    private let onLogout: () -> Void
    private let onLogoutAll: () -> Void
    private let currentLocationSharingStatus: @MainActor () -> LocationSharingAccessState
    private let refreshLocationSharing: @MainActor () async -> LocationSharingAccessState
    private let pauseLocationSharing: @MainActor () async throws -> Void
    private let resumeLocationSharing: @MainActor () async throws -> Void
    private var task: Task<Void, Never>?
    private var privacyTask: Task<Void, Never>?
    private var privacyRevision = 0

    init(user: User, backendHost: String, observeConnection: ObserveConnectionStateUseCase,
         onLogout: @escaping () -> Void, onLogoutAll: @escaping () -> Void,
         currentLocationSharingStatus: @escaping @MainActor () -> LocationSharingAccessState = { .checking },
         refreshLocationSharing: @escaping @MainActor () async -> LocationSharingAccessState = { .unavailable },
         pauseLocationSharing: @escaping @MainActor () async throws -> Void = {},
         resumeLocationSharing: @escaping @MainActor () async throws -> Void = {}) {
        self.user = user
        self.backendHost = backendHost
        self.observeConnection = observeConnection
        self.onLogout = onLogout
        self.onLogoutAll = onLogoutAll
        self.currentLocationSharingStatus = currentLocationSharingStatus
        self.refreshLocationSharing = refreshLocationSharing
        self.pauseLocationSharing = pauseLocationSharing
        self.resumeLocationSharing = resumeLocationSharing
        self.connectionState = observeConnection.current
        self.locationSharingStatus = currentLocationSharingStatus()
    }

    deinit {
        task?.cancel()
        privacyTask?.cancel()
    }

    var connectionLabel: String {
        switch connectionState {
        case .connected: return "Đã kết nối ✅"
        case .connecting: return "Đang kết nối…"
        case .disconnected: return "Chưa kết nối ❌"
        }
    }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var locationSharingStatusKey: String {
        switch locationSharingStatus {
        case .checking: return "privacy.sharing.status.checking"
        case .sharing: return "privacy.sharing.status.sharing"
        case .paused: return "privacy.sharing.status.paused"
        case .pendingPause: return "privacy.sharing.status.pending"
        case .unavailable: return "privacy.sharing.status.unavailable"
        }
    }

    func start() {
        if task == nil {
            let stream = observeConnection()
            connectionState = observeConnection.current
            task = Task { [weak self] in
                for await state in stream { self?.connectionState = state }
            }
        }
        refreshPrivacy()
    }

    func refreshPrivacy() {
        guard !isChangingLocationSharing else { return }
        privacyRevision += 1
        let revision = privacyRevision
        privacyTask?.cancel()
        locationSharingError = nil
        locationSharingStatus = currentLocationSharingStatus() == .pendingPause ? .pendingPause : .checking
        privacyTask = Task { [weak self] in
            guard let self else { return }
            let status = await self.refreshLocationSharing()
            guard !Task.isCancelled, self.privacyRevision == revision else { return }
            self.locationSharingStatus = status
        }
    }

    func setLocationSharingEnabled(_ enabled: Bool) {
        guard !isChangingLocationSharing else { return }
        privacyRevision += 1
        let revision = privacyRevision
        privacyTask?.cancel()
        isChangingLocationSharing = true
        locationSharingError = nil
        locationSharingStatus = enabled ? .checking : .pendingPause
        privacyTask = Task { [weak self] in
            guard let self else { return }
            do {
                if enabled { try await self.resumeLocationSharing() }
                else { try await self.pauseLocationSharing() }
            } catch {
                self.locationSharingError = L10n.tr("privacy.sharing.error")
            }
            guard self.privacyRevision == revision else { return }
            self.locationSharingStatus = self.currentLocationSharingStatus()
            self.isChangingLocationSharing = false
        }
    }

    func logout() {
        onLogout()
    }

    func logoutAll() { onLogoutAll() }
}
