import Foundation

@main
enum RouteNavigationChecks {
    static func main() {
        let first = GeoPoint(latitude: 21, longitude: 105)
        let middle = GeoPoint(latitude: 21, longitude: 105.005)
        let last = GeoPoint(latitude: 21, longitude: 105.01)
        let route = RouteOption(id: "0", distanceMeters: 1040, durationSeconds: 300,
                                geometry: [first, middle, last],
                                maneuvers: [
                                    RouteManeuver(code: "DEPART", pointIndex: 0,
                                                  routeOffsetMeters: 0, streetName: nil),
                                    RouteManeuver(code: "TURN_RIGHT", pointIndex: 1,
                                                  routeOffsetMeters: 520, streetName: nil),
                                ],
                                modeSections: [RouteModeSection(startPointIndex: 0,
                                                                endPointIndex: 2, travelMode: "motorcycle")],
                                trafficDelaySeconds: nil, trafficAvailable: false)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        func fix(_ seconds: TimeInterval, _ latitude: Double, _ longitude: Double,
                 accuracy: Double = 5) -> LocationFix {
            LocationFix(latitude: latitude, longitude: longitude,
                        timestamp: start.addingTimeInterval(seconds),
                        horizontalAccuracy: accuracy, speed: 5, course: 90)
        }
        func accept(_ session: inout NavigationSession, _ f: LocationFix,
                    online: Bool = true) -> NavigationUpdate {
            session.accept(f, now: f.timestamp, online: online)
        }
        var session = NavigationSession(ownerID: "alice", route: route, mode: .motorcycle)
        assert(session.begin()?.code == "DEPART", "Departure must start before a new GPS callback")
        assert(session.begin() == nil, "Departure must be announced only once")
        if case .unchanged = accept(&session, fix(0, 21, 105)) {} else {
            fatalError("Initial GPS fix repeated departure")
        }
        assert(session.nextManeuverIndex == 1)
        if case .unchanged = accept(&session, fix(5, 21, 105, accuracy: 200)) {} else {
            fatalError("Noisy fix advanced route")
        }
        if case .maneuver(let step) = accept(&session, fix(10, 21, 105.0049)) {
            assert(step.code == "TURN_RIGHT")
        } else { fatalError("Turn did not advance") }
        assert(session.nextManeuverIndex == 2)
        assert((session.remainingMeters ?? 1040) < 600)
        if case .unchanged = accept(&session, fix(20, 21.001, 105.006), online: false) {} else {
            fatalError("Offline fix requested a reroute")
        }
        if case .reroute = accept(&session, fix(31, 21.001, 105.006)) {} else {
            fatalError("Two credible off-route fixes did not request reroute")
        }
        assert(session.rerouteCount == 1)
        if case .unchanged = accept(&session, fix(40, 21.001, 105.006)) {} else {
            fatalError("Reroute cooldown failed")
        }
        session.replaceRoute(route, at: start.addingTimeInterval(45))
        assert(session.revision == 1 && session.rerouteCount == 1)
        if case .unchanged = accept(&session, fix(50, 21, 105.01)) {} else {
            fatalError("Single arrival fix ended trip")
        }
        if case .arrived = accept(&session, fix(80, 21, 105.01)) {} else {
            fatalError("Stable arrival did not end trip")
        }
        if case .unchanged = accept(&session, fix(81, 21, 105.01)) {} else {
            fatalError("Arrival repeated")
        }
        let emptyRoute = RouteOption(id: "empty", distanceMeters: 0, durationSeconds: 0,
                                     geometry: [], maneuvers: route.maneuvers,
                                     modeSections: route.modeSections,
                                     trafficDelaySeconds: nil, trafficAvailable: false)
        var invalidSession = NavigationSession(ownerID: "alice", route: emptyRoute, mode: .car)
        if case .unchanged = accept(&invalidSession, fix(0, 21, 105)) {} else {
            fatalError("Invalid geometry should not advance")
        }
        let arrivingRoute = RouteOption(id: "arriving", distanceMeters: 100, durationSeconds: 60,
                                        geometry: [first, last],
                                        maneuvers: [RouteManeuver(code: "ARRIVE", pointIndex: 1,
                                                                  routeOffsetMeters: 0, streetName: nil)],
                                        modeSections: route.modeSections,
                                        trafficDelaySeconds: nil, trafficAvailable: false)
        var arrivingSession = NavigationSession(ownerID: "alice", route: arrivingRoute, mode: .walking)
        if case .unchanged = accept(&arrivingSession, fix(0, 21, 105)) {} else {
            fatalError("Arrival should not be announced before stable confirmation")
        }
        let json = """
        {
          "provider":"tomtom-v1","travelMode":"walking","fetchedAt":"2026-11-14T00:00:00.000Z",
          "routes":[{
            "id":"0","distanceMeters":200,"durationSeconds":180,
            "geometry":[{"latitude":21,"longitude":105},{"latitude":21,"longitude":105.001}],
            "maneuvers":[{"code":"DEPART","pointIndex":0,"routeOffsetMeters":0,"streetName":null}],
            "modeSections":[{"startPointIndex":0,"endPointIndex":1,"travelMode":"other"}],
            "traffic":{"status":"provider_reported","delaySeconds":0}
          }]
        }
        """
        do {
            let dto = try JSONDecoder().decode(RoutePreviewDTO.self, from: Data(json.utf8))
            let preview = try dto.toDomain()
            assert(preview.mode == .walking)
            assert(preview.routes[0].hasUnverifiedMotorcycleSegment)
            assert(!preview.routes[0].trafficAvailable)
            assert(preview.routes[0].trafficDelaySeconds == nil)
        } catch { fatalError("Route DTO failed: \(error)") }
        for mode in RouteTravelMode.allCases {
            let modeJSON = json.replacingOccurrences(of: "\"walking\"",
                                                      with: "\"\(mode.rawValue)\"")
            do {
                let preview = try JSONDecoder().decode(RoutePreviewDTO.self,
                                                       from: Data(modeJSON.utf8)).toDomain()
                assert(preview.mode == mode && preview.routes.count == 1)
                assert(preview.routes[0].trafficAvailable == (mode != .walking))
            } catch { fatalError("Mode DTO failed: \(error)") }
        }
        print("RouteNavigation domain checks passed")
    }
}
