import MapKit

enum RouteMapGeometry {
    static func visibleRect(for bounds: RouteBounds) -> MKMapRect {
        let padded = bounds.padded(by: 1.15)
        let center = MKMapPoint(padded.center.coordinate)
        let north = MKMapPoint(CLLocationCoordinate2D(latitude: padded.maxLatitude,
                                                        longitude: padded.center.longitude))
        let south = MKMapPoint(CLLocationCoordinate2D(latitude: padded.minLatitude,
                                                        longitude: padded.center.longitude))
        let width = max(MKMapSize.world.width * padded.longitudeSpan / 360, 1_000)
        let height = max(south.y - north.y, 1_000)
        return MKMapRect(x: center.x - width / 2, y: north.y,
                         width: width, height: height)
    }

    static func nearestSegment(to tap: CGPoint, paths: [(String, [CGPoint])],
                               threshold: CGFloat = 22, ambiguity: CGFloat = 5) -> String? {
        let distances = paths.compactMap { id, points -> (String, CGFloat)? in
            guard points.count > 1 else { return nil }
            let minimumDistance = zip(points, points.dropFirst()).map { start, end in
                distance(to: tap, from: start, to: end)
            }.min() ?? CGFloat.greatestFiniteMagnitude
            return (id, minimumDistance)
        }.sorted { $0.1 < $1.1 }
        guard let first = distances.first, first.1 <= threshold else { return nil }
        if distances.count > 1, distances[1].1 - first.1 <= ambiguity { return nil }
        return first.0
    }

    private static func distance(to point: CGPoint, from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let fraction = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy)
                                   / lengthSquared))
        return hypot(point.x - start.x - fraction * dx,
                     point.y - start.y - fraction * dy)
    }
}
