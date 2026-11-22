import Combine
import Foundation

@MainActor
final class RouteNavigationViewModel: ObservableObject {
    @Published var mode: RouteTravelMode = .motorcycle
    @Published private(set) var routes: [RouteOption] = []
    @Published private(set) var selectedID: String?
    @Published private(set) var loading = false
    @Published private(set) var privateLocationEnabled = false
    @Published private(set) var active = false
    @Published private(set) var offline = false
    @Published private(set) var noticeKey: String?
    @Published private(set) var nextStep: RouteManeuver?
    @Published private(set) var remainingMeters: Double?
    @Published private(set) var remainingSeconds: Double?
    @Published private(set) var voiceEnabled = true

    private let ownerID: String
    private let repository: RoutePreviewRepository
    private let location: DeviceLocationRepository
    private let connectivity: RouteConnectivity
    private let sessionGeneration: () -> Int
    private let speech = NavigationSpeechService()
    @Published private(set) var destination: GeoPoint?
    private var generation = 0
    private var previewTask: Task<Void, Never>?
    private var fixTask: Task<Void, Never>?
    private var arrivalTask: Task<Void, Never>?
    private var navigation: NavigationSession?
    private var lastFix: LocationFix?
    private var previewAt: Date?
    private var rerouteBlocked = false

    init(ownerID: String, repository: RoutePreviewRepository,
         location: DeviceLocationRepository, connectivity: RouteConnectivity,
         sessionGeneration: @escaping () -> Int) {
        self.ownerID = ownerID
        self.repository = repository
        self.location = location
        self.connectivity = connectivity
        self.sessionGeneration = sessionGeneration
    }

    var selectedRoute: RouteOption? { routes.first { $0.id == selectedID } }
    var geometry: [GeoPoint] { selectedRoute?.geometry ?? [] }
    var hasUnverifiedSegment: Bool {
        mode == .motorcycle && selectedRoute?.hasUnverifiedMotorcycleSegment == true
    }
    var distanceToNextManeuver: Double? {
        guard let nextStep, let route = selectedRoute, let remainingMeters else { return nil }
        let progress = route.distanceMeters - remainingMeters
        return max(0, nextStep.routeOffsetMeters - progress)
    }

    func toggleVoice() {
        voiceEnabled.toggle()
        if !voiceEnabled { speech.stop() }
    }

    func open(destination: GeoPoint) {
        end()
        self.destination = destination
        noticeKey = "route.state.consent"
    }

    func enablePrivateLocation() {
        guard destination != nil, !privateLocationEnabled else { return }
        privateLocationEnabled = true
        connectivity.onChange = { [weak self] online in
            self?.offline = !online
            if !online { self?.noticeKey = "route.state.offline" }
            else if self?.noticeKey == "route.state.offline" { self?.noticeKey = nil }
        }
        connectivity.start()
        location.requestNavigationPermission()
        location.startNavigationTracking()
        let fixes = location.observeFixes()
        fixTask = Task { [weak self] in
            for await fix in fixes {
                guard !Task.isCancelled, let self else { return }
                self.accept(fix)
            }
        }
        if let fix = location.lastKnownFix { accept(fix) }
        if routes.isEmpty && !loading { refresh() }
    }

    func setMode(_ newMode: RouteTravelMode) {
        guard !active, mode != newMode else { return }
        mode = newMode
        invalidate()
        routes = []
        selectedID = nil
        previewAt = nil
        refresh()
    }

    func select(_ id: String) {
        guard !active, routes.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    func refresh() {
        guard privateLocationEnabled, let destination else { return }
        if !connectivity.isOnline {
            offline = true
            noticeKey = "route.state.offline"
            return
        }
        rerouteBlocked = false
        let fix = lastFix ?? location.lastKnownFix
        guard let fix, (-5...30).contains(Date().timeIntervalSince(fix.timestamp)),
              fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= 100 else {
            noticeKey = "route.state.waiting_location"
            location.requestFreshLocation()
            return
        }
        invalidate()
        let requestID = generation
        let accountGeneration = sessionGeneration()
        let requestedMode = mode
        loading = true
        noticeKey = nil
        previewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let preview = try await repository.preview(origin: fix.point, destination: destination,
                                                           mode: requestedMode, sessionGeneration: accountGeneration)
                guard !Task.isCancelled, generation == requestID,
                      sessionGeneration() == accountGeneration else { return }
                routes = preview.routes
                previewAt = preview.fetchedAt
                selectedID = preview.routes.first?.id
                offline = false
                noticeKey = preview.routes.isEmpty ? "route.state.no_route" : nil
            } catch {
                guard !Task.isCancelled, generation == requestID,
                      sessionGeneration() == accountGeneration else { return }
                switch error {
                case RoutePreviewFailure.quota:
                    noticeKey = "route.state.quota"
                    rerouteBlocked = true
                case RoutePreviewFailure.unauthorized:
                    end()
                    noticeKey = "route.state.session"
                case RoutePreviewFailure.offline:
                    noticeKey = "route.state.offline"
                    offline = true
                default: noticeKey = "route.state.unavailable"
                }
            }
            loading = false
        }
    }

    func start() {
        guard privateLocationEnabled, let route = selectedRoute,
              location.authorization == .whenInUse || location.authorization == .always else {
            noticeKey = "route.state.permission"
            return
        }
        guard route.geometry.count >= 2, let previewAt, (-5...300).contains(Date().timeIntervalSince(previewAt)),
              let fix = lastFix, (-5...30).contains(Date().timeIntervalSince(fix.timestamp)),
              fix.point.distance(to: route.geometry[0]) <= 200 else {
            noticeKey = "route.state.stale"
            refresh()
            return
        }
        var started = NavigationSession(ownerID: ownerID, route: route, mode: mode)
        let departure = started.begin()
        navigation = started
        active = true
        nextStep = started.nextManeuverIndex < route.maneuvers.count
            ? route.maneuvers[started.nextManeuverIndex] : nil
        remainingMeters = route.distanceMeters
        remainingSeconds = route.durationSeconds
        noticeKey = nil
        // Starting is explicit; announce it even if adaptive GPS sends no new fix.
        if let departure, voiceEnabled { speech.speak(departure) }
        // A reliable current fix can also update progress without another GPS event.
        if fix.horizontalAccuracy <= 50 { accept(fix) }
    }

    func end() {
        invalidate()
        speech.stop()
        fixTask?.cancel()
        fixTask = nil
        arrivalTask?.cancel()
        arrivalTask = nil
        if privateLocationEnabled { location.stopNavigationTracking() }
        connectivity.stop()
        privateLocationEnabled = false
        active = false
        offline = false
        rerouteBlocked = false
        navigation = nil
        nextStep = nil
        remainingMeters = nil
        remainingSeconds = nil
        lastFix = nil
        routes = []
        selectedID = nil
        previewAt = nil
        destination = nil
        noticeKey = nil
    }

    private func invalidate() {
        generation += 1
        previewTask?.cancel()
        previewTask = nil
        loading = false
    }

    private func accept(_ fix: LocationFix) {
        lastFix = fix
        if location.authorization == .denied {
            end()
            noticeKey = "route.state.permission"
            return
        }
        guard active, var navigation, let destination else {
            if routes.isEmpty && !loading && destination != nil { refresh() }
            return
        }
        let update = navigation.accept(fix, online: connectivity.isOnline && !rerouteBlocked)
        self.navigation = navigation
        if let remaining = navigation.remainingMeters {
            remainingMeters = remaining
            remainingSeconds = navigation.route.distanceMeters > 0
                ? navigation.route.durationSeconds * remaining / navigation.route.distanceMeters : 0
        }
        if navigation.needsArrivalConfirmation && arrivalTask == nil {
            arrivalTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 31_000_000_000)
                guard !Task.isCancelled, let self, self.active else { return }
                self.location.requestFreshLocation()
                self.arrivalTask = nil
            }
        } else if !navigation.needsArrivalConfirmation {
            arrivalTask?.cancel()
            arrivalTask = nil
        }
        switch update {
        case .unchanged: break
        case .maneuver(let maneuver):
            if voiceEnabled { speech.speak(maneuver) }
            nextStep = navigation.nextManeuverIndex < navigation.route.maneuvers.count
                ? navigation.route.maneuvers[navigation.nextManeuverIndex] : nil
        case .arrived:
            end()
            noticeKey = "route.state.arrived"
        case .reroute:
            guard !loading else { return }
            let requestID = generation
            let accountGeneration = sessionGeneration()
            loading = true
            previewTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let preview = try await repository.preview(origin: fix.point, destination: destination,
                                                               mode: mode, sessionGeneration: accountGeneration)
                    guard !Task.isCancelled, generation == requestID,
                          sessionGeneration() == accountGeneration, active else { return }
                    if let replacement = preview.routes.first, var updated = self.navigation {
                        updated.replaceRoute(replacement, at: Date())
                        self.navigation = updated
                        routes = preview.routes
                        selectedID = replacement.id
                        previewAt = preview.fetchedAt
                        nextStep = replacement.maneuvers.first
                        remainingMeters = replacement.distanceMeters
                        remainingSeconds = replacement.durationSeconds
                        offline = false
                    } else {
                        noticeKey = "route.state.no_route"
                    }
                } catch {
                    guard !Task.isCancelled, generation == requestID,
                          sessionGeneration() == accountGeneration else { return }
                    switch error {
                    case RoutePreviewFailure.quota:
                        rerouteBlocked = true
                        noticeKey = "route.state.quota"
                    case RoutePreviewFailure.offline:
                        offline = true
                        noticeKey = "route.state.offline"
                    case RoutePreviewFailure.unauthorized:
                        end()
                        noticeKey = "route.state.session"
                    default: noticeKey = "route.state.unavailable"
                    }
                }
                loading = false
            }
        }
    }
}
