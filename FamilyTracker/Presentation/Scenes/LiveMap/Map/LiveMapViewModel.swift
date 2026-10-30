import Foundation
import MapKit

@MainActor
final class LiveMapViewModel: ObservableObject {
    @Published var mapRegion: MKCoordinateRegion = .defaultCity
    @Published private(set) var memberLocations: [MemberLocation] = []
    @Published private(set) var connectionState: RealtimeConnectionState
    @Published var isTrackingUser = true
    @Published private(set) var trailDrawing = TrailDrawing.empty
    @Published private(set) var trailUnavailable = false
    @Published private(set) var selectedTrailUserId: String
    @Published private(set) var sosFollowActive = false
    @Published private(set) var sosLocationUpdatedAt: Date?

    let currentUserId: String

    private let observeMemberLocations: ObserveMemberLocationsUseCase
    private let observeConnection: ObserveConnectionStateUseCase
    private let observeDeviceLocation: ObserveDeviceLocationUseCase
    private let getCurrentLocation: GetCurrentLocationUseCase
    private let fetchLiveTrail: FetchLiveTrailUseCase
    private let realtime: SocketRealtimeRepository
    private var tasks: [Task<Void, Never>] = []
    private var trailLoadTask: Task<Void, Never>?
    private var trail: LiveTrailAssembler?
    private var baseDrawing = TrailDrawing.empty
    private var drawingTask: Task<Void, Never>?
    private var drawingGeneration = 0
    private var localFixes: [LocationFix] = []
    private var watchedUserId: String?
    private var watchedDate: String?
    private var lastTrailRefreshAt = Date.distantPast
    private var trailAccessClosed = false
    private var followedSOSMemberId: String?
    private var followedSOSLastTime: Date?
    private var watchMismatchCount = 0
    private var loadGeneration = 0

    init(
        currentUserId: String,
        observeMemberLocations: ObserveMemberLocationsUseCase,
        observeConnection: ObserveConnectionStateUseCase,
        observeDeviceLocation: ObserveDeviceLocationUseCase,
        getCurrentLocation: GetCurrentLocationUseCase,
        fetchLiveTrail: FetchLiveTrailUseCase,
        realtime: SocketRealtimeRepository
    ) {
        self.currentUserId = currentUserId
        self.observeMemberLocations = observeMemberLocations
        self.observeConnection = observeConnection
        self.observeDeviceLocation = observeDeviceLocation
        self.getCurrentLocation = getCurrentLocation
        self.fetchLiveTrail = fetchLiveTrail
        self.realtime = realtime
        self.selectedTrailUserId = currentUserId
        self.connectionState = observeConnection.current
    }

    deinit {
        tasks.forEach { $0.cancel() }
        trailLoadTask?.cancel()
        drawingTask?.cancel()
    }

    var isConnected: Bool { connectionState == .connected }

    func start() {
        guard tasks.isEmpty else { return }
        let locations = observeMemberLocations()
        let connection = observeConnection()
        let device = observeDeviceLocation()
        let trailEvents = realtime.observeTrailEvents()
        let readiness = realtime.observeSessionReadiness()
        let outgoingFixes = realtime.observeOutgoingFixes()

        tasks.append(Task { [weak self] in
            for await location in locations { self?.upsert(location) }
        })
        tasks.append(Task { [weak self] in
            for await state in connection { self?.connectionState = state }
        })
        tasks.append(Task { [weak self] in
            for await point in device {
                if self?.isTrackingUser == true { self?.center(on: point) }
                if self?.selectedTrailUserId == self?.currentUserId { self?.refreshMissingTrail() }
            }
        })
        tasks.append(Task { [weak self] in
            for await event in trailEvents { await self?.handleTrailEvent(event) }
        })
        tasks.append(Task { [weak self] in
            for await ready in readiness {
                guard let self else { return }
                if ready {
                    self.trailAccessClosed = false
                    self.refreshTrail()
                }
                else {
                    self.watchedUserId = nil
                    self.watchedDate = nil
                }
            }
        })
        tasks.append(Task { [weak self] in
            for await fix in outgoingFixes { self?.acceptLocalFix(fix) }
        })
        connectionState = observeConnection.current
        refreshTrail()
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        trailLoadTask?.cancel()
        drawingTask?.cancel()
        loadGeneration += 1
        unwatch()
        localFixes.removeAll()
    }

    func centerOnUser() {
        followedSOSMemberId = nil
        sosFollowActive = false
        selectTrail(userId: currentUserId)
        guard let point = getCurrentLocation() else { return }
        isTrackingUser = true
        center(on: point)
    }

    func centerOnMember(_ member: MemberLocation) {
        followedSOSMemberId = nil
        sosFollowActive = false
        isTrackingUser = false
        center(on: member.point)
        selectTrail(userId: member.id)
    }

    func focus(on point: GeoPoint) {
        followedSOSMemberId = nil
        sosFollowActive = false
        isTrackingUser = false
        center(on: point)
    }

    /// Follow live updates when available; the SOS fix is only a fallback snapshot.
    func followSOSMember(_ userID: String, fallback: GeoPoint?, recordedAt: Date?) {
        isTrackingUser = false
        followedSOSMemberId = userID
        followedSOSLastTime = recordedAt
        sosFollowActive = true
        sosLocationUpdatedAt = recordedAt
        selectTrail(userId: userID)
        if let member = memberLocations.first(where: { $0.id == userID }),
           acceptSOSLocationTime(member.timestamp) {
            center(on: member.point)
        } else if let fallback { center(on: fallback) }
    }

    func userMovedMap() { isTrackingUser = false; followedSOSMemberId = nil; sosFollowActive = false }

    private func center(on point: GeoPoint) {
        mapRegion = MKCoordinateRegion(center: point.coordinate, delta: 0.01)
    }

    private func upsert(_ location: MemberLocation) {
        let isFollowed = location.id == followedSOSMemberId
        if isFollowed && !acceptSOSLocationTime(location.timestamp) { return }
        if let index = memberLocations.firstIndex(where: { $0.id == location.id }) {
            memberLocations[index] = location
        } else {
            memberLocations.append(location)
        }
        if isFollowed { center(on: location.point) }
        if location.id == selectedTrailUserId { refreshMissingTrail() }
    }

    private func acceptSOSLocationTime(_ timestamp: String) -> Bool {
        guard let date = SOSFollowTimestampPolicy.accepts(timestamp, after: followedSOSLastTime) else { return false }
        followedSOSLastTime = date
        sosLocationUpdatedAt = date
        return true
    }

    private func refreshMissingTrail() {
        guard trail == nil, !trailUnavailable, !trailAccessClosed,
              Date().timeIntervalSince(lastTrailRefreshAt) >= 5 else { return }
        refreshTrail()
    }

    private var today: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func selectTrail(userId: String) {
        guard selectedTrailUserId != userId else { return }
        unwatch()
        selectedTrailUserId = userId
        watchMismatchCount = 0
        localFixes.removeAll()
        trailAccessClosed = false
        trail = nil
        updateDrawing()
        refreshTrail()
    }

    private func unwatch() {
        if let watchedUserId, let watchedDate {
            realtime.unwatchTrail(userId: watchedUserId, date: watchedDate)
        }
        watchedUserId = nil
        watchedDate = nil
    }

    func refreshTrail() {
        lastTrailRefreshAt = Date()
        loadGeneration += 1
        let generation = loadGeneration
        let userId = selectedTrailUserId
        let date = today
        if watchedDate != nil, watchedDate != date { unwatch() }
        trailLoadTask?.cancel()
        trailLoadTask = Task { [weak self, fetchLiveTrail, realtime] in
            guard let self else { return }
            do {
                let loaded: LiveTrailAssembler
                if let trail = self.trail, trail.userId == userId, trail.date == date {
                    do { loaded = try await fetchLiveTrail.catchUp(trail) }
                    catch {
                        try Task.checkCancellation()
                        loaded = try await fetchLiveTrail(userId: userId, date: date)
                    }
                } else {
                    loaded = try await fetchLiveTrail(userId: userId, date: date)
                }
                guard !Task.isCancelled, generation == self.loadGeneration else { return }
                self.trail = loaded
                self.updateDrawing()
                self.trailUnavailable = false
                self.trailAccessClosed = false
            } catch LiveTrailLoadError.notFound {
                guard generation == self.loadGeneration else { return }
                self.trail = nil
                self.updateDrawing()
            } catch LiveTrailLoadError.unavailable {
                guard generation == self.loadGeneration else { return }
                self.trailUnavailable = true
                self.updateDrawing()
                return
            } catch {
                guard generation == self.loadGeneration, !Task.isCancelled else { return }
                if (error as? DomainError) == .forbidden {
                    self.trail = nil
                    self.updateDrawing()
                    self.trailAccessClosed = true
                    self.unwatch()
                }
                return
            }
            guard !Task.isCancelled, generation == self.loadGeneration,
                  self.trail != nil, realtime.isSessionReady else { return }
            do {
                let revision = try await realtime.watchTrail(userId: userId, date: date)
                guard !Task.isCancelled, generation == self.loadGeneration else {
                    realtime.unwatchTrail(userId: userId, date: date)
                    return
                }
                self.watchedUserId = userId
                self.watchedDate = date
                if revision > 0, revision != self.trail?.revision {
                    self.watchMismatchCount += 1
                    if self.watchMismatchCount <= 2 { self.refreshTrail() }
                } else {
                    self.watchMismatchCount = 0
                }
            } catch {
                if (error as? DomainError) == .forbidden, generation == self.loadGeneration {
                    self.trail = nil
                    self.updateDrawing()
                    self.trailAccessClosed = true
                }
            }
        }
    }

    func refreshOnForeground() {
        guard !tasks.isEmpty else { return }
        refreshTrail()
    }

    private func handleTrailEvent(_ event: LiveTrailEvent) async {
        switch event {
        case .delta(let delta):
            guard delta.userId == selectedTrailUserId else { return }
            guard var trail else { refreshTrail(); return }
            do {
                try trail.apply(delta)
                self.trail = trail
                updateDrawing()
            } catch {
                refreshTrail()
            }
        case .reset(let userId, _):
            guard userId == selectedTrailUserId else { return }
            trail = nil
            updateDrawing()
            trailAccessClosed = false
            refreshTrail()
        case .closed(let userId):
            guard userId == selectedTrailUserId else { return }
            trailLoadTask?.cancel()
            loadGeneration += 1
            trail = nil
            localFixes.removeAll()
            updateDrawing()
            trailAccessClosed = true
            watchedUserId = nil
            watchedDate = nil
        }
    }

    private func acceptLocalFix(_ fix: LocationFix) {
        guard selectedTrailUserId == currentUserId else { return }
        guard !localFixes.contains(where: { $0.timestamp == fix.timestamp }) else { return }
        localFixes.append(fix)
        if localFixes.count > 100 { localFixes.removeFirst(localFixes.count - 100) }
        updateDrawing(rebuildBase: false)
    }

    private func updateDrawing(rebuildBase: Bool = true) {
        if rebuildBase {
            drawingGeneration += 1
            let generation = drawingGeneration
            drawingTask?.cancel()
            if let trail {
                drawingTask = Task { [weak self] in
                    let drawing = await Task.detached(priority: .userInitiated) {
                        TrailDrawing.build(from: trail)
                    }.value
                    guard let self, !Task.isCancelled, self.drawingGeneration == generation else { return }
                    self.baseDrawing = drawing
                    self.combineDrawing()
                }
            } else {
                baseDrawing = .empty
            }
        }
        combineDrawing()
    }

    private func combineDrawing() {
        let base = baseDrawing
        guard selectedTrailUserId == currentUserId, !localFixes.isEmpty else {
            trailDrawing = base
            return
        }
        let latest = trail?.orderedPoints.last
        let pending = localFixes.filter { fix in
            guard let latest else { return true }
            return fix.timestamp > latest.recordedAt
        }
        if let latest { localFixes.removeAll { $0.timestamp <= latest.recordedAt } }
        var points = pending.map(\.point)
        if let latest, let first = pending.first,
           first.timestamp.timeIntervalSince(latest.recordedAt) <= 120,
           latest.coordinate.distance(to: first.point) <= 500 {
            points.insert(latest.coordinate, at: 0)
        }
        var lines = base.lines
        if points.count >= 2 {
            lines.append(TrailDrawing.Line(id: "local-pending", points: points, style: .gps))
        }
        trailDrawing = TrailDrawing(lines: lines, fixes: base.fixes + pending.map(\.point))
    }
}
