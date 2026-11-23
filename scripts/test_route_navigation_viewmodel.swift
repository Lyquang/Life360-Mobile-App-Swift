import Foundation

enum LocationAuthorization { case whenInUse, always, denied }

protocol DeviceLocationRepository: AnyObject {
    var authorization: LocationAuthorization { get }
    var lastKnownFix: LocationFix? { get }
    func requestNavigationPermission()
    func startNavigationTracking()
    func stopNavigationTracking()
    func requestFreshLocation()
    func observeFixes() -> AsyncStream<LocationFix>
}

@MainActor
final class NavigationSpeechService {
    func speak(_ maneuver: RouteManeuver) {}
    func stop() {}
}

final class FakeLocation: DeviceLocationRepository {
    var authorization: LocationAuthorization = .whenInUse
    var lastKnownFix: LocationFix?
    var startCount = 0
    var stopCount = 0

    init(point: GeoPoint) {
        lastKnownFix = LocationFix(latitude: point.latitude, longitude: point.longitude,
                                   timestamp: Date(), horizontalAccuracy: 5, speed: 0, course: -1)
    }
    func requestNavigationPermission() {}
    func startNavigationTracking() { startCount += 1 }
    func stopNavigationTracking() { stopCount += 1 }
    func requestFreshLocation() {}
    func observeFixes() -> AsyncStream<LocationFix> { AsyncStream { _ in } }
}

@MainActor
final class FakeConnectivity: RouteConnectivity {
    var isOnline = true
    var onChange: ((Bool) -> Void)?
    func start() {}
    func stop() { onChange = nil }
    func setOnline(_ online: Bool) { isOnline = online; onChange?(online) }
}

actor FakeRoutes: RoutePreviewRepository {
    var calls = 0
    var failMode: RouteTravelMode?

    func callCount() -> Int { calls }
    func setFailure(_ mode: RouteTravelMode?) { failMode = mode }

    func preview(origin: GeoPoint, destination: GeoPoint, mode: RouteTravelMode,
                 sessionGeneration: Int) async throws -> RoutePreview {
        calls += 1
        try await Task.sleep(nanoseconds: mode == .motorcycle ? 250_000_000 : 20_000_000)
        if mode == failMode { throw RoutePreviewFailure.unauthorized }
        let option = RouteOption(id: mode.rawValue, distanceMeters: 1000, durationSeconds: 300,
                                 geometry: [origin, destination],
                                 maneuvers: [RouteManeuver(code: "DEPART", pointIndex: 0,
                                                           routeOffsetMeters: 0, streetName: nil),
                                             RouteManeuver(code: "TURN_RIGHT", pointIndex: 1,
                                                           routeOffsetMeters: 500, streetName: nil)],
                                 modeSections: [RouteModeSection(startPointIndex: 0,
                                                                 endPointIndex: 1,
                                                                 travelMode: mode.rawValue)],
                                 trafficDelaySeconds: nil, trafficAvailable: false)
        return RoutePreview(mode: mode, fetchedAt: Date(), routes: [option])
    }
}

@main
enum RouteViewModelChecks {
    @MainActor static func main() async {
        let origin = GeoPoint(latitude: 21, longitude: 105)
        let destination = GeoPoint(latitude: 21, longitude: 105.01)
        let repo = FakeRoutes()
        let location = FakeLocation(point: origin)
        let connectivity = FakeConnectivity()
        let model = RouteNavigationViewModel(ownerID: "alice", repository: repo,
                                             location: location, connectivity: connectivity,
                                             sessionGeneration: { 1 })
        model.open(destination: destination)
        model.enablePrivateLocation()
        try? await Task.sleep(nanoseconds: 40_000_000)
        let initialCalls = await repo.callCount()
        assert(initialCalls == 1, "Enabling private location must request once")
        model.setMode(.car)
        try? await Task.sleep(nanoseconds: 320_000_000)
        assert(model.routes.count == 1 && model.selectedID == "car",
               "Old motorcycle response must not replace car route")
        let modeCalls = await repo.callCount()
        assert(modeCalls == 2)
        model.start()
        assert(model.active && model.remainingMeters == 1000)
        assert(model.nextStep?.code == "TURN_RIGHT" && model.distanceToNextManeuver == 500,
               "Starting with a reliable current fix must process departure immediately")
        connectivity.setOnline(false)
        model.refresh()
        assert(model.offline && model.active)
        let offlineCalls = await repo.callCount()
        assert(offlineCalls == 2, "Offline state must not issue a route request")
        model.end()
        assert(location.stopCount == 1 && !model.privateLocationEnabled)

        await repo.setFailure(.walking)
        model.open(destination: destination)
        model.enablePrivateLocation()
        connectivity.setOnline(true)
        model.setMode(.walking)
        try? await Task.sleep(nanoseconds: 100_000_000)
        assert(!model.privateLocationEnabled && model.destination == nil,
               "Unauthorized response must stop private location")
        print("RouteNavigation ViewModel checks passed")
    }
}
