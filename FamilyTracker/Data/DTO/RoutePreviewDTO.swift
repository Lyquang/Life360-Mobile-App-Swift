import Foundation

struct RoutePreviewDTO: Decodable {
    let provider: String
    let travelMode: RouteTravelMode
    let fetchedAt: String
    let routes: [RouteOptionDTO]

    func toDomain() throws -> RoutePreview {
        guard provider == "tomtom-v1", routes.count <= 3,
              let date = ISO8601DateFormatter().date(from: fetchedAt) ??
                ISO8601DateFormatter.fractional.date(from: fetchedAt) else {
            throw RoutePreviewFailure.invalidResponse
        }
        return RoutePreview(mode: travelMode, fetchedAt: date,
                            routes: try routes.map { try $0.toDomain(mode: travelMode) })
    }
}

private extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct RouteOptionDTO: Decodable {
    let id: String
    let distanceMeters: Double
    let durationSeconds: Double
    let geometry: [RoutePointDTO]
    let maneuvers: [RouteManeuverDTO]
    let modeSections: [RouteModeSectionDTO]
    let traffic: RouteTrafficDTO

    func toDomain(mode: RouteTravelMode) throws -> RouteOption {
        guard geometry.count >= 2, distanceMeters.isFinite, distanceMeters >= 0,
              durationSeconds.isFinite, durationSeconds >= 0, !maneuvers.isEmpty else {
            throw RoutePreviewFailure.invalidResponse
        }
        let points = try geometry.map { try $0.toDomain() }
        let steps = try maneuvers.map { step -> RouteManeuver in
            guard points.indices.contains(step.pointIndex), step.routeOffsetMeters.isFinite,
                  step.routeOffsetMeters >= 0 else { throw RoutePreviewFailure.invalidResponse }
            return RouteManeuver(code: step.code, pointIndex: step.pointIndex,
                                 routeOffsetMeters: step.routeOffsetMeters, streetName: step.streetName)
        }
        let sections = try modeSections.map { section -> RouteModeSection in
            guard points.indices.contains(section.startPointIndex),
                  points.indices.contains(section.endPointIndex),
                  section.startPointIndex <= section.endPointIndex,
                  ["motorcycle", "car", "pedestrian", "other"].contains(section.travelMode) else {
                throw RoutePreviewFailure.invalidResponse
            }
            return RouteModeSection(startPointIndex: section.startPointIndex,
                                    endPointIndex: section.endPointIndex, travelMode: section.travelMode)
        }
        guard !sections.isEmpty,
              ["provider_reported", "unavailable"].contains(traffic.status) else {
            throw RoutePreviewFailure.invalidResponse
        }
        if let delay = traffic.delaySeconds, !delay.isFinite || delay < 0 {
            throw RoutePreviewFailure.invalidResponse
        }
        let trafficAvailable = mode != .walking && traffic.status == "provider_reported" &&
            traffic.delaySeconds != nil
        return RouteOption(id: id, distanceMeters: distanceMeters, durationSeconds: durationSeconds,
                           geometry: points, maneuvers: steps, modeSections: sections,
                           trafficDelaySeconds: trafficAvailable ? traffic.delaySeconds : nil,
                           trafficAvailable: trafficAvailable)
    }
}

struct RoutePointDTO: Decodable {
    let latitude: Double
    let longitude: Double
    func toDomain() throws -> GeoPoint {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180 else {
            throw RoutePreviewFailure.invalidResponse
        }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}

struct RouteManeuverDTO: Decodable {
    let code: String
    let pointIndex: Int
    let routeOffsetMeters: Double
    let streetName: String?
}

struct RouteModeSectionDTO: Decodable {
    let startPointIndex: Int
    let endPointIndex: Int
    let travelMode: String
}

struct RouteTrafficDTO: Decodable {
    let status: String
    let delaySeconds: Double?
}
