import Foundation

struct TrailDrawing: Sendable {
    enum Style: Sendable, Equatable { case gps, matched }
    struct Line: Sendable {
        let id: String
        let points: [GeoPoint]
        let style: Style
    }

    let lines: [Line]
    let fixes: [GeoPoint]

    static let empty = TrailDrawing(lines: [], fixes: [])

    static func build(from trail: LiveTrailAssembler) -> TrailDrawing {
        let ordered = trail.orderedPoints
        let validMatches = trail.matches.compactMap { match -> (LiveTrailMatch, [GeoPoint])? in
            let statusIsMatched = match.status == .provisional || match.status == .final
            guard statusIsMatched, !["noop", "fake", "none"].contains(match.provider.lowercased()),
                  !match.sourceRevision.isEmpty,
                  match.confidence.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
                  let start = ordered.firstIndex(where: { $0.seq == match.fromSeq }),
                  let end = ordered.firstIndex(where: { $0.seq == match.toSeq }), start < end,
                  let geometry = match.geometry, geometry.encoding == "polyline6",
                  let points = decodePolyline6(geometry.data), points.count >= 2 else { return nil }
            return (match, points)
        }
        let matchedEdges = Set(validMatches.flatMap { match, _ -> [String] in
            guard let start = ordered.firstIndex(where: { $0.seq == match.fromSeq }),
                  let end = ordered.firstIndex(where: { $0.seq == match.toSeq }), start < end else { return [] }
            return (start..<end).map { "\(ordered[$0].seq):\(ordered[$0 + 1].seq)" }
        })
        let gapEdges = Set(trail.gaps.map { "\($0.fromSeq):\($0.toSeq)" })
        var lines = validMatches.map { match, points in
            Line(id: "matched:\(match.segmentId)", points: points, style: .matched)
        }
        var run = [GeoPoint]()
        var runIndex = 0
        func finishRun() {
            if run.count >= 2 {
                lines.append(Line(id: "gps:\(runIndex)", points: run, style: .gps))
                runIndex += 1
            }
            run.removeAll()
        }
        for pair in zip(ordered, ordered.dropFirst()) {
            let key = "\(pair.0.seq):\(pair.1.seq)"
            guard !gapEdges.contains(key), !matchedEdges.contains(key) else {
                finishRun()
                continue
            }
            if run.isEmpty { run.append(pair.0.coordinate) }
            run.append(pair.1.coordinate)
        }
        finishRun()
        return TrailDrawing(lines: lines, fixes: ordered.map(\.coordinate))
    }

    private static func decodePolyline6(_ encoded: String) -> [GeoPoint]? {
        let bytes = Array(encoded.utf8)
        var index = 0
        var latitude: Int64 = 0
        var longitude: Int64 = 0
        var result = [GeoPoint]()
        func component() -> Int64? {
            var value: UInt64 = 0
            var shift: UInt64 = 0
            while index < bytes.count, shift <= 60 {
                let byte = bytes[index]
                index += 1
                guard byte >= 63, byte <= 126 else { return nil }
                let chunk = UInt64(byte - 63)
                value |= (chunk & 31) << shift
                if chunk < 32 {
                    let magnitude = Int64(value >> 1)
                    return value & 1 == 0 ? magnitude : ~magnitude
                }
                shift += 5
            }
            return nil
        }
        while index < bytes.count {
            guard let lat = component(), let lon = component() else { return nil }
            let (nextLat, latOverflow) = latitude.addingReportingOverflow(lat)
            let (nextLon, lonOverflow) = longitude.addingReportingOverflow(lon)
            guard !latOverflow, !lonOverflow else { return nil }
            latitude = nextLat
            longitude = nextLon
            let point = GeoPoint(latitude: Double(latitude) / 1_000_000,
                                 longitude: Double(longitude) / 1_000_000)
            guard abs(point.latitude) <= 90, abs(point.longitude) <= 180 else { return nil }
            result.append(point)
        }
        return result
    }
}
