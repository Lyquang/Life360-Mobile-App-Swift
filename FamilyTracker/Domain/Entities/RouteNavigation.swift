import Foundation

enum RouteTravelMode: String, CaseIterable, Codable, Sendable {
    case motorcycle, car, walking
}

struct RouteManeuver: Sendable {
    let code: String
    let pointIndex: Int
    let routeOffsetMeters: Double
    let streetName: String?
}

struct RouteModeSection: Sendable {
    let startPointIndex: Int
    let endPointIndex: Int
    let travelMode: String
}

struct RouteOption: Identifiable, Sendable {
    let id: String
    let distanceMeters: Double
    let durationSeconds: Double
    let geometry: [GeoPoint]
    let maneuvers: [RouteManeuver]
    let modeSections: [RouteModeSection]
    let trafficDelaySeconds: Double?
    let trafficAvailable: Bool

    var hasUnverifiedMotorcycleSegment: Bool {
        modeSections.contains { $0.travelMode == "other" }
    }
}

struct RoutePreview: Sendable {
    let mode: RouteTravelMode
    let fetchedAt: Date
    let routes: [RouteOption]
}

enum RoutePreviewFailure: Error {
    case noLocation, quota, offline, unavailable, invalidResponse, unauthorized
}
