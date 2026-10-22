import Foundation

struct RouteOverlayModel: Sendable {
    struct Segment: Identifiable, Sendable {
        let id: String
        let points: [GeoPoint]
    }

    struct Stay: Identifiable, Sendable {
        let id: String
        let point: GeoPoint
        let durationMinutes: Int
    }

    let segments: [Segment]
    let stays: [Stay]
    let start: GeoPoint?
    let end: GeoPoint?
    let selectedEntryID: String?
    let bounds: RouteBounds?
    let geometryID: UInt64

    var hasPath: Bool { !segments.isEmpty }

    static var empty: RouteOverlayModel {
        RouteOverlayModel(segments: [], stays: [], start: nil, end: nil,
                          selectedEntryID: nil, bounds: nil, geometryID: 0)
    }

    func selecting(_ entryID: String?) -> RouteOverlayModel {
        RouteOverlayModel(segments: segments, stays: stays, start: start, end: end,
                          selectedEntryID: entryID, bounds: bounds, geometryID: geometryID)
    }

    static func build(from journey: DayJourney, toleranceMeters: Double,
                      selectedEntryID: String? = nil) -> RouteOverlayModel {
        var segments = [Segment]()
        var stays = [Stay]()
        var allPoints = [GeoPoint]()

        for entry in journey.entries {
            switch entry {
            case .stay(let stay):
                guard let point = PolylineSimplifier.validPoints([stay.point]).first else { continue }
                stays.append(Stay(id: entry.id, point: point, durationMinutes: stay.durationMinutes))
                allPoints.append(point)
            case .moving(let moving):
                let valid = PolylineSimplifier.validPoints(moving.path)
                allPoints.append(contentsOf: valid)
                let simplified = PolylineSimplifier.simplify(valid, toleranceMeters: toleranceMeters)
                if simplified.count >= 2 {
                    segments.append(Segment(id: entry.id, points: simplified))
                }
            }
        }

        return RouteOverlayModel(
            segments: segments, stays: stays, start: allPoints.first, end: allPoints.last,
            selectedEntryID: selectedEntryID, bounds: RouteBounds(points: allPoints),
            geometryID: fingerprint(segments: segments, stays: stays, allPoints: allPoints)
        )
    }

    private static func fingerprint(segments: [Segment], stays: [Stay],
                                    allPoints: [GeoPoint]) -> UInt64 {
        var value: UInt64 = 14_695_981_039_346_656_037
        func mix(_ next: UInt64) { value = (value ^ next) &* 1_099_511_628_211 }
        func mix(_ string: String) {
            for byte in string.utf8 { mix(UInt64(byte)) }
            mix(255)
        }
        for segment in segments {
            mix(1)
            mix(segment.id)
            mix(UInt64(segment.points.count))
            for point in segment.points {
                mix(point.latitude.bitPattern)
                mix(point.longitude.bitPattern)
            }
        }
        for stay in stays {
            mix(2)
            mix(stay.id)
            mix(stay.point.latitude.bitPattern)
            mix(stay.point.longitude.bitPattern)
            mix(UInt64(bitPattern: Int64(stay.durationMinutes)))
        }
        mix(3)
        mix(UInt64(allPoints.count))
        for point in allPoints {
            mix(point.latitude.bitPattern)
            mix(point.longitude.bitPattern)
        }
        return value
    }
}

struct RouteBounds: Equatable, Sendable {
    let minLatitude: Double
    let maxLatitude: Double
    let westLongitude: Double
    let longitudeSpan: Double

    var center: GeoPoint {
        GeoPoint(latitude: (minLatitude + maxLatitude) / 2,
                 longitude: Self.normalized(westLongitude + longitudeSpan / 2))
    }

    var latitudeSpan: Double { maxLatitude - minLatitude }

    init?(points: [GeoPoint]) {
        let valid = PolylineSimplifier.validPoints(points)
        guard let minLatitude = valid.map(\.latitude).min(),
              let maxLatitude = valid.map(\.latitude).max() else { return nil }
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude

        let sorted = valid.map { longitude in
            let value = longitude.longitude.truncatingRemainder(dividingBy: 360)
            return value < 0 ? value + 360 : value
        }.sorted()
        var largestGap = -1.0
        var startIndex = 0
        for index in sorted.indices {
            let next = index + 1 < sorted.count ? sorted[index + 1] : sorted[0] + 360
            let gap = next - sorted[index]
            if gap > largestGap {
                largestGap = gap
                startIndex = (index + 1) % sorted.count
            }
        }
        westLongitude = Self.normalized(sorted[startIndex])
        longitudeSpan = max(0, 360 - largestGap)
    }

    func padded(by factor: Double, minimumSpan: Double = 0.005) -> RouteBounds {
        let scale = factor.isFinite ? max(1, factor) : 1
        let minimum = minimumSpan.isFinite ? max(0, minimumSpan) : 0
        let latitude = max(latitudeSpan * scale, minimum)
        let longitude = min(360, max(longitudeSpan * scale, minimum))
        let center = center
        return RouteBounds(
            minLatitude: max(-90, center.latitude - latitude / 2),
            maxLatitude: min(90, center.latitude + latitude / 2),
            westLongitude: Self.normalized(center.longitude - longitude / 2),
            longitudeSpan: longitude
        )
    }

    private init(minLatitude: Double, maxLatitude: Double,
                 westLongitude: Double, longitudeSpan: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.westLongitude = westLongitude
        self.longitudeSpan = longitudeSpan
    }

    private static func normalized(_ longitude: Double) -> Double {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }
}
