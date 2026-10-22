import Foundation

struct LiveTrailSnapshot: Sendable {
    let trailId: String
    let userId: String
    let date: String
    let timeZone: String
    let revision: Int
    let lastSeq: Int
    let points: [LiveTrailPoint]
    let gaps: [LiveTrailGap]
    let matches: [LiveTrailMatch]
    let hasMore: Bool
    let nextAfterSeq: Int?
}

struct LiveTrailPoint: Sendable, Equatable {
    let seq: Int
    let coordinate: GeoPoint
    let recordedAt: Date
    let accuracy: Double?
    let motionState: String?
    let pointId: UUID?
}

struct LiveTrailGap: Sendable, Hashable {
    let fromSeq: Int
    let toSeq: Int
    let seconds: Double
    let meters: Double
}

enum LiveTrailMatchStatus: Sendable, Equatable {
    case provisional
    case final
    case unmatched
    case unknown(String)
}

struct LiveTrailGeometry: Sendable, Equatable {
    let encoding: String
    let data: String
}

struct LiveTrailMatch: Sendable {
    let segmentId: String
    let fromSeq: Int
    let toSeq: Int
    let status: LiveTrailMatchStatus
    let geometry: LiveTrailGeometry?
    let provider: String
    let providerVersion: String
    let confidence: Double?
    let sourceRevision: String
    let generatedAt: Date
}

enum LiveTrailLoadError: Error {
    case notFound
    case revisionChanged
    case unavailable
    case rateLimited(retryAfter: String?)
}

struct LiveTrailDelta: Sendable {
    let userId: String
    let trailId: String
    let revision: Int
    let afterSeq: Int
    let toSeq: Int
    let points: [LiveTrailPoint]
    let matchedUpdates: [LiveTrailMatch]
}

enum LiveTrailEvent: Sendable {
    case delta(LiveTrailDelta)
    case reset(userId: String, revision: Int)
    case closed(userId: String)
}
