import Foundation

enum PolylineSimplifier {
    private static let earthRadius = 6_371_000.0

    static func validPoints(_ points: [GeoPoint]) -> [GeoPoint] {
        var result = [GeoPoint]()
        result.reserveCapacity(points.count)
        for point in points where point.latitude.isFinite && point.longitude.isFinite
            && (-90...90).contains(point.latitude) && (-180...180).contains(point.longitude) {
            if result.last != point { result.append(point) }
        }
        return result
    }

    static func simplify(_ points: [GeoPoint], toleranceMeters: Double) -> [GeoPoint] {
        let cleaned = validPoints(points)
        guard cleaned.count > 2 else { return cleaned }

        // Unwrap consecutive longitudes so a crossing at +/-180 is a short line.
        var unwrapped = [Double]()
        unwrapped.reserveCapacity(cleaned.count)
        unwrapped.append(cleaned[0].longitude)
        for point in cleaned.dropFirst() {
            var longitude = point.longitude
            let previous = unwrapped[unwrapped.count - 1]
            while longitude - previous > 180 { longitude -= 360 }
            while longitude - previous < -180 { longitude += 360 }
            unwrapped.append(longitude)
        }

        let meanLatitude = cleaned.reduce(0) { $0 + $1.latitude } / Double(cleaned.count)
        let longitudeScale = max(0.000_001, cos(meanLatitude * .pi / 180))
        let projected = cleaned.indices.map { index in
            ProjectedPoint(
                x: unwrapped[index] * .pi / 180 * earthRadius * longitudeScale,
                y: cleaned[index].latitude * .pi / 180 * earthRadius
            )
        }
        let tolerance = toleranceMeters.isFinite ? max(0, toleranceMeters) : 0
        var keep = Array(repeating: false, count: cleaned.count)
        keep[0] = true
        keep[cleaned.count - 1] = true
        var ranges = [(0, cleaned.count - 1)]

        while let (first, last) = ranges.popLast() {
            guard last > first + 1 else { continue }
            var farthest = first + 1
            var maximum = 0.0
            for index in (first + 1)..<last {
                let distance = projected[index].distance(toLineFrom: projected[first], to: projected[last])
                if distance > maximum {
                    maximum = distance
                    farthest = index
                }
            }
            if maximum > tolerance {
                keep[farthest] = true
                ranges.append((first, farthest))
                ranges.append((farthest, last))
            }
        }
        return cleaned.indices.compactMap { keep[$0] ? cleaned[$0] : nil }
    }
}

private struct ProjectedPoint {
    let x: Double
    let y: Double

    func distance(toLineFrom start: ProjectedPoint, to end: ProjectedPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(x - start.x, y - start.y) }
        let fraction = min(1, max(0, ((x - start.x) * dx + (y - start.y) * dy) / lengthSquared))
        return hypot(x - start.x - fraction * dx, y - start.y - fraction * dy)
    }
}
