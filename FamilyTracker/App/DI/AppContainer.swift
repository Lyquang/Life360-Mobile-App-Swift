import Foundation
import Combine
import CoreLocation
import GoogleSignIn
import UIKit

@MainActor
final class SessionExpiryEvents {
    let publisher = PassthroughSubject<Void, Never>()
    var onExpire: (() -> Void)?
    private var didExpire = false

    func reset() { didExpire = false }
    func expire() {
        guard !didExpire else { return }
        didExpire = true
        onExpire?()
        publisher.send(())
    }
}

/// Composition root: builds Core services and Data repositories once, hands out use cases.
/// Nothing outside App/ should reach into this container directly except coordinators.
@MainActor
final class AppContainer {
    let environment: AppEnvironment
    let languageSettings: LanguageSettingsViewModel
    let sessionEvents = SessionExpiryEvents()

    // MARK: Core
    let logger: NetworkLogger
    let batteryMonitor: BatteryMonitor
    let mobileMetrics: MobileMetricsCollector
    private let networkPathObserver: NetworkPathObserver?
    private let locationDiagnostics: LocationDiagnostics
    let pushService: PushNotificationService
    private let socketClient: SocketIOClientAdapter
    private let locationService: CLLocationService

    // MARK: Data
    let session: KeychainSessionRepository
    let tokenRefreshCoordinator: TokenRefreshCoordinator
    let api: APIClient
    let authRepository: AuthRepository
    let circleRepository: CircleRepository
    let placeRepository: PlaceRepository
    let historyRepository: HistoryRepository
    let liveTrailRepository: LiveTrailRepository
    let locationSharingRepository: LocationSharingRepository
    private let locationSharingGate: LocationSharingGate
    let realtime: SocketRealtimeRepository
    let chatRepository: ChatRepository
    let mediaRepository: MediaRepository
    let mediaImageLoader: MediaImageLoader
    let deviceLocation: DeviceLocationRepository
    let deviceStatus: DeviceStatusRepository
    let geocoding: GeocodingRepository
    let googleSignInService: GoogleSignInService

    // MARK: Long-lived use cases / services
    let shareLocation: ShareLocationUseCase
    private let locationDelivery: LocationDeliveryService
    private(set) lazy var notificationBridge = RealtimeNotificationBridge(
        observeSOS: ObserveSOSAlertsUseCase(repository: realtime),
        observeStayAlerts: ObserveStayAlertsUseCase(repository: realtime),
        push: pushService
    )

    init(environment: AppEnvironment = .current) {
        self.environment = environment
        languageSettings = LanguageSettingsViewModel(preferences: UserDefaultsLanguagePreferences())

        #if DEBUG
        logger = PulseDiagnostics.shared
        #else
        logger = NoopNetworkLogger()
        #endif
        batteryMonitor = BatteryMonitor()
        mobileMetrics = MobileMetricsCollector()
        let metrics = mobileMetrics
        #if DEBUG
        let pathObserver: NetworkPathObserver? = NetworkPathObserver(recorder: metrics)
        let socketMetrics: MobileMetricsRecording? = metrics
        batteryMonitor.onMetricsEvents = { [weak metrics] events in
            // One task preserves the order of values sampled from the same device-state change.
            Task { for event in events { await metrics?.record(event) } }
        }
        #else
        let pathObserver: NetworkPathObserver? = nil
        let socketMetrics: MobileMetricsRecording? = nil
        #endif
        networkPathObserver = pathObserver
        locationDiagnostics = LocationDiagnostics(logger: logger, battery: batteryMonitor.snapshot,
                                                  recorder: mobileMetrics)
        pushService = PushNotificationService()
        session = KeychainSessionRepository()
        socketClient = SocketIOClientAdapter(
            url: environment.socketURL, logger: logger, tokenProvider: session,
            metrics: socketMetrics, networkKind: { [weak pathObserver] in pathObserver?.networkKind ?? .unknown }
        )
        locationService = CLLocationService(battery: batteryMonitor.snapshot, diagnostics: locationDiagnostics)
        #if DEBUG
        let restMetrics: MobileMetricsRecording? = mobileMetrics
        #else
        let restMetrics: MobileMetricsRecording? = nil
        #endif
        let refreshTransport = URLSessionRefreshTransport(baseURL: environment.apiBaseURL,
                                                          logger: logger, metrics: restMetrics)
        let events = sessionEvents
        let socket = socketClient
        let sessionStore = session
        let offlineQueue = OfflineQueue()
        tokenRefreshCoordinator = TokenRefreshCoordinator(
            store: session, transport: refreshTransport,
            onRotated: { token in await MainActor.run { socket.connect(token: token) } },
            onExpired: { generation in
                let expired = await MainActor.run {
                    guard sessionStore.clear(ifGeneration: generation) else { return false }
                    socket.disconnect()
                    pathObserver?.stop()
                    offlineQueue.clear()
                    events.expire()
                    return true
                }
                if expired { await metrics.setEnabled(false) }
            }
        )
        let coordinator = tokenRefreshCoordinator
        let diagnostics = logger
        socketClient.onAuthenticationFailure = { sentToken in
            Task {
                do {
                    _ = try await coordinator.validAccessToken(afterUnauthorized: sentToken)
                } catch let failure as RefreshFailure {
                    let category: String
                    switch failure {
                    case .invalidSession: category = "invalid_session"
                    case .rateLimited: category = "rate_limited"
                    case .network: category = "network"
                    case .ambiguousNetwork: category = "ambiguous_network"
                    case .server: category = "server"
                    case .storage: category = "storage"
                    case .cancelled: category = "cancelled"
                    }
                    diagnostics.logSocket(event: "auth_refresh_failed", payload: ["category": category])
                } catch {
                    diagnostics.logSocket(event: "auth_refresh_failed", payload: ["category": "unknown"])
                }
            }
        }
        api = URLSessionAPIClient(baseURL: environment.apiBaseURL, tokenProvider: session,
                                  logger: logger, refreshCoordinator: tokenRefreshCoordinator,
                                  metrics: restMetrics)
        authRepository = AuthRepositoryImpl(api: api)
        circleRepository = CircleRepositoryImpl(api: api)
        placeRepository = PlaceRepositoryImpl(api: api)
        historyRepository = HistoryRepositoryImpl(api: api)
        liveTrailRepository = LiveTrailRepositoryImpl(api: api)
        locationSharingRepository = LocationSharingRepositoryImpl(api: api)
        locationSharingGate = LocationSharingGate()
        realtime = SocketRealtimeRepository(socket: socketClient, offlineQueue: offlineQueue,
                                            diagnostics: locationDiagnostics)
        chatRepository = ChatRepositoryImpl(api: api, socket: socketClient)
        mediaRepository = MediaRepositoryImpl(
            uploader: MediaUploadService(api: api, logger: logger, metrics: restMetrics)
        )
        mediaImageLoader = MediaImageLoader(metrics: restMetrics)
        deviceLocation = DeviceLocationRepositoryImpl(service: locationService)
        deviceStatus = DeviceStatusRepositoryImpl(battery: batteryMonitor)
        geocoding = GeocodingRepositoryImpl(geocoder: ReverseGeocoder(), cache: GeocodeCache())
        googleSignInService = GoogleSignInService()

        var locationBuffer: LocationBuffer?
        var locationSync: LocationSyncCoordinator?
        do {
            let buffer = try LocationBuffer()
            locationBuffer = buffer
            locationSync = try LocationSyncCoordinator(buffer: buffer,
                                                       repository: LocationBatchRepositoryImpl(api: api))
        } catch {
            logger.logSocket(event: "location_delivery", payload: ["category": "storage_initialization_failed"])
        }
        let realtimeRepository = realtime
        locationDelivery = LocationDeliveryService(
            buffer: locationBuffer, synchronizer: locationSync,
            session: { sessionStore.locationSessionIdentity },
            readySessionID: { [weak realtimeRepository] in realtimeRepository?.readySessionID },
            emit: { [weak realtimeRepository] fix, battery in
                realtimeRepository?.emitLocationIfReady(fix, batteryLevel: battery) ?? false
            }, diagnostics: locationDiagnostics, logger: logger, recorder: mobileMetrics
        )
        let delivery = locationDelivery
        session.onSessionSaved = { [weak delivery, weak metrics, weak sessionStore] in
            Task { @MainActor in
                guard sessionStore?.locationSessionIdentity != nil else { return }
                delivery?.prepareSession()
                await metrics?.setEnabled(true)
                pathObserver?.start()
            }
        }
        delivery.prepareSession()
        pathObserver?.start()
        realtime.deliverLocation = { [weak delivery] fix, battery in delivery?.accept(fix, batteryLevel: battery) }
        realtime.onExplicitDisconnect = { [weak delivery] in delivery?.endSession(clearBuffer: true) }

        let sharingGate = locationSharingGate
        shareLocation = ShareLocationUseCase(
            deviceLocation: deviceLocation,
            liveLocation: realtime,
            deviceStatus: deviceStatus,
            diagnostics: locationDiagnostics,
            isForeground: { UIApplication.shared.applicationState == .active },
            canShare: { [weak sharingGate] in sharingGate?.allowsSharing == true },
            onSharingChanged: { [weak delivery] active in delivery?.setSharing(active) },
            onHistorySync: { [weak delivery] in delivery?.requestHistorySync() }
        )
        let locationSharing = shareLocation
        events.onExpire = { [weak locationSharing] in locationSharing?.stop() }
        locationService.onAuthorizationChange = { status in
            guard status == .denied || status == .restricted else { return }
            Task { @MainActor in locationSharing.stop() }
        }
    }

    // MARK: - Session lifecycle

    func restoreSession() async -> User? {
        await RestoreSessionUseCase(auth: authRepository, session: session, realtime: realtime)()
    }

    func logout(allDevices: Bool = false) async -> Bool {
        shareLocation.stop()
        networkPathObserver?.stop()
        await mobileMetrics.setEnabled(false)
        locationSharingGate.suspendUntilServerCheck()
        await tokenRefreshCoordinator.cancelSession()
        let result = await LogoutUseCase(auth: authRepository, session: session, realtime: realtime,
                                        shareLocation: shareLocation)(allDevices: allDevices)
        await locationDelivery.waitForPendingWrites()
        return result
    }

    /// iOS relaunched the app in the background for a location event: resume sharing without UI.
    func resumeBackgroundSharingIfPossible() {
        guard let token = session.accessToken else { return }
        if realtime.connectionState == .disconnected {
            realtime.connect(token: token)
        }
        Task { [weak self] in await self?.startLocationSharingIfAllowed() }
    }

    var locationSharingStatus: LocationSharingAccessState { locationSharingGate.status }

    func refreshLocationSharingStatus() async -> LocationSharingAccessState {
        await startLocationSharingIfAllowed()
        return locationSharingGate.status
    }

    func startLocationSharingIfAllowed() async {
        guard let identity = session.locationSessionIdentity else { return }
        shareLocation.stop()
        locationSharingGate.activate(ownerID: identity.ownerID)
        if locationSharingGate.hasPendingPause {
            locationDelivery.endSession(clearBuffer: true)
        }
        let revision = locationSharingGate.revision
        do {
            let state = try await locationSharingRepository.fetch()
            guard !Task.isCancelled, session.locationSessionIdentity == identity,
                  locationSharingGate.revision == revision else { return }
            locationSharingGate.confirm(state)
            locationSharingGate.expirePendingPause()
            if locationSharingGate.hasPendingPause {
                let paused = try await locationSharingRepository.update(
                    .pause(until: locationSharingGate.pendingPauseUntil))
                guard !Task.isCancelled, session.locationSessionIdentity == identity,
                      locationSharingGate.revision == revision else { return }
                locationSharingGate.confirm(paused)
            }
            if locationSharingGate.allowsSharing {
                shareLocation.start()
            } else {
                locationDelivery.endSession(clearBuffer: true)
            }
        } catch {
            // Unknown remote state remains closed; a later foreground/network retry may reopen it.
            locationSharingGate.markCheckFailed()
        }
    }

    func pauseLocationSharing(until: Date? = nil) async throws {
        guard let identity = session.locationSessionIdentity else { throw DomainError.unauthorized }
        shareLocation.stop()
        Task { await mobileMetrics.record(.increment(.sharingPause)) }
        locationDelivery.endSession(clearBuffer: true)
        locationSharingGate.activate(ownerID: identity.ownerID)
        try locationSharingGate.beginPause(until: until)
        let revision = locationSharingGate.revision
        await locationDelivery.waitForPendingWrites()
        let state = try await locationSharingRepository.update(.pause(until: until))
        guard session.locationSessionIdentity == identity,
              locationSharingGate.revision == revision else { return }
        guard !state.enabled else { throw DomainError.server("Pause was not confirmed by the server.") }
        locationSharingGate.confirm(state)
        guard !locationSharingGate.hasPendingPause else {
            throw DomainError.server("Pause duration was not confirmed by the server.")
        }
    }

    func resumeLocationSharing() async throws {
        guard let identity = session.locationSessionIdentity else { throw DomainError.unauthorized }
        locationSharingGate.suspendUntilServerCheck()
        let revision = locationSharingGate.revision
        let state: LocationSharingState
        do { state = try await locationSharingRepository.update(.resume) }
        catch {
            locationSharingGate.markCheckFailed()
            throw error
        }
        guard session.locationSessionIdentity == identity,
              locationSharingGate.revision == revision else { return }
        guard state.enabled else { throw DomainError.server("Resume was not confirmed by the server.") }
        locationSharingGate.confirmResume(state)
        if locationSharingGate.allowsSharing { shareLocation.start() }
    }
}

// MARK: - Use case factories
extension AppContainer {
    var login: LoginUseCase { LoginUseCase(auth: authRepository, session: session, realtime: realtime) }
    var register: RegisterUseCase { RegisterUseCase(auth: authRepository, session: session, realtime: realtime) }
    var googleSignIn: GoogleSignInUseCase {
        GoogleSignInUseCase(googleSignIn: googleSignInService, auth: authRepository, session: session, realtime: realtime)
    }

    var fetchMyCircles: FetchMyCirclesUseCase { FetchMyCirclesUseCase(repository: circleRepository) }
    var createCircle: CreateCircleUseCase { CreateCircleUseCase(repository: circleRepository) }
    var joinCircle: JoinCircleUseCase { JoinCircleUseCase(repository: circleRepository) }
    var fetchCircleMembers: FetchCircleMembersUseCase { FetchCircleMembersUseCase(repository: circleRepository) }

    var observeMemberLocations: ObserveMemberLocationsUseCase { ObserveMemberLocationsUseCase(repository: realtime) }
    var observeStayAlerts: ObserveStayAlertsUseCase { ObserveStayAlertsUseCase(repository: realtime) }
    var observePresence: ObservePresenceUseCase { ObservePresenceUseCase(repository: realtime) }
    var observeConnectionState: ObserveConnectionStateUseCase { ObserveConnectionStateUseCase(repository: realtime) }
    var observeDeviceLocation: ObserveDeviceLocationUseCase { ObserveDeviceLocationUseCase(repository: deviceLocation) }
    var getCurrentLocation: GetCurrentLocationUseCase { GetCurrentLocationUseCase(repository: deviceLocation) }

    var observeSOSAlerts: ObserveSOSAlertsUseCase { ObserveSOSAlertsUseCase(repository: realtime) }
    var sendSOS: SendSOSUseCase { SendSOSUseCase(repository: realtime, deviceLocation: deviceLocation, deviceStatus: deviceStatus) }

    var fetchLocationHistory: FetchLocationHistoryUseCase { FetchLocationHistoryUseCase(repository: historyRepository) }
    var fetchDayJourney: FetchDayJourneyUseCase { FetchDayJourneyUseCase(repository: historyRepository) }
    var fetchLiveTrail: FetchLiveTrailUseCase { FetchLiveTrailUseCase(repository: liveTrailRepository) }
    var reverseGeocode: ReverseGeocodeUseCase { ReverseGeocodeUseCase(repository: geocoding) }

    var fetchPlaces: FetchPlacesUseCase { FetchPlacesUseCase(repository: placeRepository) }
    var addPlace: AddPlaceUseCase { AddPlaceUseCase(repository: placeRepository) }

    var fetchConversations: FetchConversationsUseCase { FetchConversationsUseCase(repository: chatRepository) }
    var fetchUnreadSummary: FetchUnreadSummaryUseCase { FetchUnreadSummaryUseCase(repository: chatRepository) }
    var openDirectChat: OpenDirectChatUseCase { OpenDirectChatUseCase(repository: chatRepository) }
    var fetchMessages: FetchMessagesUseCase { FetchMessagesUseCase(repository: chatRepository) }
    var sendTextMessage: SendTextMessageUseCase { SendTextMessageUseCase(repository: chatRepository) }
    var prepareImage: PrepareImageUseCase { PrepareImageUseCase(media: mediaRepository) }
    var uploadImage: UploadImageUseCase { UploadImageUseCase(media: mediaRepository) }
    var sendImageMessage: SendImageMessageUseCase { SendImageMessageUseCase(chat: chatRepository) }
    var uploadVoice: UploadVoiceUseCase { UploadVoiceUseCase(media: mediaRepository) }
    var sendVoiceMessage: SendVoiceMessageUseCase { SendVoiceMessageUseCase(chat: chatRepository) }
    var markConversationRead: MarkConversationReadUseCase { MarkConversationReadUseCase(repository: chatRepository) }
    var observeNewMessages: ObserveNewMessagesUseCase { ObserveNewMessagesUseCase(repository: chatRepository) }
    var observeConversationUpdates: ObserveConversationUpdatesUseCase {
        ObserveConversationUpdatesUseCase(repository: chatRepository)
    }
    var observeTyping: ObserveTypingUseCase { ObserveTypingUseCase(repository: chatRepository) }
    var sendTyping: SendTypingUseCase { SendTypingUseCase(repository: chatRepository) }
}

/// Single place where the live container is created (App + AppDelegate share it).
@MainActor
enum CompositionRoot {
    static let container = AppContainer()
}
