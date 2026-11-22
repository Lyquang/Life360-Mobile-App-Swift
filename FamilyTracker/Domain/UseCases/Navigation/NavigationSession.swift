import Foundation

/// In-memory route progress. It never publishes a device fix to Circle transport.
struct NavigationSession {
    let ownerID: String
    private(set) var route: RouteOption
    private(set) var mode: RouteTravelMode
    private(set) var revision = 0
    private(set) var nextManeuverIndex = 0
    private(set) var rerouteCount = 0
    private(set) var arrived = false
    private(set) var remainingMeters: Double?
    private var lastFixAt: Date?
    private var offRouteSince: Date?
    private var arrivalSince: Date?
    private var lastRerouteAt: Date?

    init(ownerID: String, route: RouteOption, mode: RouteTravelMode) {
        self.ownerID = ownerID
        self.route = route
        self.mode = mode
        remainingMeters = route.distanceMeters
    }

    var needsArrivalConfirmation: Bool { arrivalSince != nil && !arrived }

    /// Departure is a user action, so it must not depend on another GPS callback.
    mutating func begin() -> RouteManeuver? {
        guard nextManeuverIndex == 0, let first = route.maneuvers.first,
              first.code == "DEPART" else { return nil }
        nextManeuverIndex = 1
        return first
    }

    mutating func replaceRoute(_ replacement: RouteOption, at now: Date) {
        route = replacement
        revision += 1
        nextManeuverIndex = 0
        offRouteSince = nil
        arrivalSince = nil
        lastRerouteAt = now
        remainingMeters = replacement.distanceMeters
    }

    mutating func accept(_ fix: LocationFix, now: Date = Date(), online: Bool) -> NavigationUpdate {
        guard !arrived, fix.timestamp <= now.addingTimeInterval(5),
              now.timeIntervalSince(fix.timestamp) <= 15,
              fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= 50,
              lastFixAt.map({ fix.timestamp > $0 }) ?? true else {
            return .unchanged
        }
        lastFixAt = fix.timestamp
        guard let destination = route.geometry.last, route.geometry.count >= 2 else { return .unchanged }
        let distanceToRoute = RouteProgressGeometry.distanceToPolyline(fix.point, route.geometry)
        let distanceToDestination = fix.point.distance(to: destination)
        if distanceToDestination <= 50 {
            if let arrivalSince, fix.timestamp.timeIntervalSince(arrivalSince) >= 30 {
                arrived = true
                return .arrived
            }
            if arrivalSince == nil { arrivalSince = fix.timestamp }
        } else {
            arrivalSince = nil
        }
        if distanceToRoute > max(40, fix.horizontalAccuracy * 2) {
            if let offRouteSince, fix.timestamp.timeIntervalSince(offRouteSince) >= 10,
               online, rerouteCount < 10,
               lastRerouteAt.map({ fix.timestamp.timeIntervalSince($0) >= 60 }) ?? true {
                // The caller must begin one request and only call replaceRoute on success.
                self.offRouteSince = fix.timestamp
                lastRerouteAt = fix.timestamp
                rerouteCount += 1
                return .reroute
            }
            if offRouteSince == nil { offRouteSince = fix.timestamp }
            return .unchanged
        }
        offRouteSince = nil
        let progress = RouteProgressGeometry.progressMeters(fix.point, route.geometry)
        let geometryLength = RouteProgressGeometry.lengthMeters(route.geometry)
        let scaledProgress = geometryLength > 0 ? progress * route.distanceMeters / geometryLength : 0
        remainingMeters = max(0, route.distanceMeters - scaledProgress)
        while nextManeuverIndex < route.maneuvers.count &&
                scaledProgress > route.maneuvers[nextManeuverIndex].routeOffsetMeters + 80 {
            nextManeuverIndex += 1
        }
        guard nextManeuverIndex < route.maneuvers.count else { return .unchanged }
        let step = route.maneuvers[nextManeuverIndex]
        if step.code.hasPrefix("ARRIVE") { return .unchanged }
        let leadMeters = max(40, min(160, max(0, fix.speed) * 8))
        if scaledProgress >= max(0, step.routeOffsetMeters - leadMeters) {
            nextManeuverIndex += 1
            return .maneuver(step)
        }
        return .unchanged
    }
}

enum NavigationUpdate {
    case unchanged
    case maneuver(RouteManeuver)
    case reroute
    case arrived
}

enum RouteProgressGeometry {
    static func lengthMeters(_ geometry: [GeoPoint]) -> Double {
        guard geometry.count >= 2 else { return 0 }
        return (1..<geometry.count).reduce(0) { $0 + geometry[$1 - 1].distance(to: geometry[$1]) }
    }

    static func progressMeters(_ point: GeoPoint, _ geometry: [GeoPoint]) -> Double {
        guard geometry.count >= 2 else { return 0 }
        let latitudeScale = 111_195.0
        let longitudeScale = latitudeScale * cos(point.latitude * .pi / 180)
        var closest = Double.infinity
        var progress = 0.0
        var accumulated = 0.0
        for index in 1..<geometry.count {
            let start = geometry[index - 1]
            let end = geometry[index]
            let ax = (start.longitude - point.longitude) * longitudeScale
            let ay = (start.latitude - point.latitude) * latitudeScale
            let dx = (end.longitude - start.longitude) * longitudeScale
            let dy = (end.latitude - start.latitude) * latitudeScale
            let length2 = dx * dx + dy * dy
            let fraction = length2 > 0 ? max(0, min(1, -(ax * dx + ay * dy) / length2)) : 0
            let distance = hypot(ax + fraction * dx, ay + fraction * dy)
            let length = start.distance(to: end)
            if distance < closest {
                closest = distance
                progress = accumulated + length * fraction
            }
            accumulated += length
        }
        return progress
    }

    static func distanceToPolyline(_ point: GeoPoint, _ geometry: [GeoPoint]) -> Double {
        guard geometry.count >= 2 else { return .infinity }
        let latitudeScale = 111_195.0
        let longitudeScale = latitudeScale * cos(point.latitude * .pi / 180)
        var closest = Double.infinity
        for index in 1..<geometry.count {
            let start = geometry[index - 1]
            let end = geometry[index]
            let ax = (start.longitude - point.longitude) * longitudeScale
            let ay = (start.latitude - point.latitude) * latitudeScale
            let bx = (end.longitude - point.longitude) * longitudeScale
            let by = (end.latitude - point.latitude) * latitudeScale
            let dx = bx - ax, dy = by - ay
            let length2 = dx * dx + dy * dy
            let fraction = length2 > 0 ? max(0, min(1, -(ax * dx + ay * dy) / length2)) : 0
            closest = min(closest, hypot(ax + fraction * dx, ay + fraction * dy))
        }
        return closest
    }
}
