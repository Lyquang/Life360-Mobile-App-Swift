import Foundation
import Combine
import GoogleSignIn

@MainActor
final class SessionExpiryEvents {
    let publisher = PassthroughSubject<Void, Never>()
    private var didExpire = false

    func reset() { didExpire = false }
    func expire() {
        guard !didExpire else { return }
        didExpire = true
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
    let realtime: SocketRealtimeRepository
    let chatRepository: ChatRepository
    let mediaRepository: MediaRepository
    let deviceLocation: DeviceLocationRepository
    let deviceStatus: DeviceStatusRepository
    let geocoding: GeocodingRepository
    let googleSignInService: GoogleSignInService

    // MARK: Long-lived use cases / services
    let shareLocation: ShareLocationUseCase
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
        pushService = PushNotificationService()
        session = KeychainSessionRepository()
        socketClient = SocketIOClientAdapter(url: environment.socketURL, logger: logger, tokenProvider: session)
        locationService = CLLocationService(battery: batteryMonitor.snapshot)
        let refreshTransport = URLSessionRefreshTransport(baseURL: environment.apiBaseURL, logger: logger)
        let events = sessionEvents
        let socket = socketClient
        let sessionStore = session
        let offlineQueue = OfflineQueue()
        tokenRefreshCoordinator = TokenRefreshCoordinator(
            store: session, transport: refreshTransport,
            onRotated: { token in await MainActor.run { socket.connect(token: token) } },
            onExpired: { generation in
                await MainActor.run {
                    guard sessionStore.clear(ifGeneration: generation) else { return }
                    socket.disconnect()
                    offlineQueue.clear()
                    events.expire()
                }
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
                                  logger: logger, refreshCoordinator: tokenRefreshCoordinator)
        authRepository = AuthRepositoryImpl(api: api)
        circleRepository = CircleRepositoryImpl(api: api)
        placeRepository = PlaceRepositoryImpl(api: api)
        historyRepository = HistoryRepositoryImpl(api: api)
        realtime = SocketRealtimeRepository(socket: socketClient, offlineQueue: offlineQueue)
        chatRepository = ChatRepositoryImpl(api: api, socket: socketClient)
        mediaRepository = MediaRepositoryImpl(
            uploader: MediaUploadService(api: api, logger: logger)
        )
        deviceLocation = DeviceLocationRepositoryImpl(service: locationService)
        deviceStatus = DeviceStatusRepositoryImpl(battery: batteryMonitor)
        geocoding = GeocodingRepositoryImpl(geocoder: ReverseGeocoder(), cache: GeocodeCache())
        googleSignInService = GoogleSignInService()

        shareLocation = ShareLocationUseCase(
            deviceLocation: deviceLocation,
            liveLocation: realtime,
            deviceStatus: deviceStatus
        )
    }

    // MARK: - Session lifecycle

    func restoreSession() async -> User? {
        await RestoreSessionUseCase(auth: authRepository, session: session, realtime: realtime)()
    }

    func logout(allDevices: Bool = false) async -> Bool {
        await tokenRefreshCoordinator.cancelSession()
        return await LogoutUseCase(auth: authRepository, session: session, realtime: realtime,
                                   shareLocation: shareLocation)(allDevices: allDevices)
    }

    /// iOS relaunched the app in the background for a location event: resume sharing without UI.
    func resumeBackgroundSharingIfPossible() {
        guard let token = session.accessToken else { return }
        if realtime.connectionState == .disconnected {
            realtime.connect(token: token)
        }
        shareLocation.start()
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
    var reverseGeocode: ReverseGeocodeUseCase { ReverseGeocodeUseCase(repository: geocoding) }

    var fetchPlaces: FetchPlacesUseCase { FetchPlacesUseCase(repository: placeRepository) }
    var addPlace: AddPlaceUseCase { AddPlaceUseCase(repository: placeRepository) }

    var fetchConversations: FetchConversationsUseCase { FetchConversationsUseCase(repository: chatRepository) }
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
    var observeTyping: ObserveTypingUseCase { ObserveTypingUseCase(repository: chatRepository) }
    var sendTyping: SendTypingUseCase { SendTypingUseCase(repository: chatRepository) }
}

/// Single place where the live container is created (App + AppDelegate share it).
@MainActor
enum CompositionRoot {
    static let container = AppContainer()
}
