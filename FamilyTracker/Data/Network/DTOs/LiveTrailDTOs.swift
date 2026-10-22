import Foundation

struct LiveTrailResponseDTO: Decodable {
    let success: Bool
    let trailId: String
    let userId: String
    let date: String
    let timeZone: String
    let revision: Int
    let lastSeq: Int
    let points: [LiveTrailPointDTO]
    let gaps: [LiveTrailGapDTO]
    let matched: [LiveTrailMatchDTO]
    let hasMore: Bool
    let nextAfterSeq: Int?

    func toDomain() -> LiveTrailSnapshot {
        LiveTrailSnapshot(trailId: trailId, userId: userId, date: date, timeZone: timeZone,
                          revision: revision, lastSeq: lastSeq, points: points.map { $0.toDomain() },
                          gaps: gaps.map { $0.toDomain() }, matches: matched.map { $0.toDomain() },
                          hasMore: hasMore, nextAfterSeq: nextAfterSeq)
    }
}

struct LiveTrailPointDTO: Decodable {
    let seq: Int
    let latitude: Double
    let longitude: Double
    let recordedAt: Date
    let accuracy: Double?
    let motionState: String?
    let pointId: UUID?

    func toDomain() -> LiveTrailPoint {
        LiveTrailPoint(seq: seq, coordinate: GeoPoint(latitude: latitude, longitude: longitude),
                       recordedAt: recordedAt, accuracy: accuracy, motionState: motionState,
                       pointId: pointId)
    }
}

struct LiveTrailGapDTO: Decodable {
    let fromSeq: Int
    let toSeq: Int
    let seconds: Double
    let meters: Double

    func toDomain() -> LiveTrailGap {
        LiveTrailGap(fromSeq: fromSeq, toSeq: toSeq, seconds: seconds, meters: meters)
    }
}

struct LiveTrailMatchDTO: Decodable {
    let segmentId: String
    let fromSeq: Int
    let toSeq: Int
    let status: String
    let geometry: LiveTrailGeometryDTO?
    let matcher: LiveTrailMatcherDTO
    let confidence: Double?
    let sourceRevision: String
    let generatedAt: Date

    func toDomain() -> LiveTrailMatch {
        let mappedStatus: LiveTrailMatchStatus
        switch status {
        case "provisional": mappedStatus = .provisional
        case "final": mappedStatus = .final
        case "unmatched": mappedStatus = .unmatched
        default: mappedStatus = .unknown(status)
        }
        return LiveTrailMatch(segmentId: segmentId, fromSeq: fromSeq, toSeq: toSeq,
                              status: mappedStatus, geometry: geometry?.toDomain(),
                              provider: matcher.provider, providerVersion: matcher.version,
                              confidence: confidence, sourceRevision: sourceRevision,
                              generatedAt: generatedAt)
    }
}

struct LiveTrailGeometryDTO: Decodable {
    let encoding: String
    let data: String

    func toDomain() -> LiveTrailGeometry {
        LiveTrailGeometry(encoding: encoding, data: data)
    }
}

struct LiveTrailMatcherDTO: Decodable {
    let provider: String
    let version: String
}

struct LiveTrailDeltaDTO: Decodable {
    let userId: String
    let trailId: String
    let revision: Int
    let afterSeq: Int
    let toSeq: Int
    let points: [LiveTrailPointDTO]
    let matchedUpdates: [LiveTrailMatchDTO]

    func toDomain() -> LiveTrailDelta {
        LiveTrailDelta(userId: userId, trailId: trailId, revision: revision,
                       afterSeq: afterSeq, toSeq: toSeq, points: points.map { $0.toDomain() },
                       matchedUpdates: matchedUpdates.map { $0.toDomain() })
    }
}

struct LiveTrailSignalDTO: Decodable {
    let userId: String
    let revision: Int?
}
