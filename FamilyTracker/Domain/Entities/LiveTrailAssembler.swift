import Foundation

enum LiveTrailAssemblyError: Error, Equatable {
    case invalidPage
    case differentTrail
    case revisionChanged
    case unexpectedCursor
}

/// Builds one revision of a trail without assuming insertion order is travel order.
struct LiveTrailAssembler: Sendable {
    private struct GapBoundary: Hashable {
        let fromSeq: Int
        let toSeq: Int
    }

    let trailId: String
    let userId: String
    let date: String
    let timeZone: String
    let revision: Int
    private(set) var cursor: Int
    private(set) var hasMore: Bool
    private(set) var nextAfterSeq: Int?
    private var pointsBySeq: [Int: LiveTrailPoint]
    private var gapsByBoundary: [GapBoundary: LiveTrailGap]
    private var matchesByID: [String: LiveTrailMatch]

    init(firstPage: LiveTrailSnapshot) throws {
        guard firstPage.revision > 0, !firstPage.trailId.isEmpty,
              !firstPage.userId.isEmpty, Self.validCursor(firstPage, afterSeq: 0) else {
            throw LiveTrailAssemblyError.invalidPage
        }
        trailId = firstPage.trailId
        userId = firstPage.userId
        date = firstPage.date
        timeZone = firstPage.timeZone
        revision = firstPage.revision
        cursor = firstPage.points.map(\.seq).max() ?? 0
        hasMore = firstPage.hasMore
        nextAfterSeq = firstPage.nextAfterSeq
        pointsBySeq = Dictionary(firstPage.points.map { ($0.seq, $0) }, uniquingKeysWith: { _, newest in newest })
        gapsByBoundary = Self.gapDictionary(firstPage.gaps)
        matchesByID = Self.matchDictionary(firstPage.matches)
    }

    mutating func append(_ page: LiveTrailSnapshot, requestedAfterSeq: Int) throws {
        guard page.trailId == trailId, page.userId == userId,
              page.date == date, page.timeZone == timeZone else {
            throw LiveTrailAssemblyError.differentTrail
        }
        guard page.revision == revision else { throw LiveTrailAssemblyError.revisionChanged }
        guard requestedAfterSeq == cursor else { throw LiveTrailAssemblyError.unexpectedCursor }
        guard Self.validCursor(page, afterSeq: requestedAfterSeq),
              page.points.allSatisfy({ $0.seq > requestedAfterSeq }) else {
            throw LiveTrailAssemblyError.invalidPage
        }
        for point in page.points { pointsBySeq[point.seq] = point }
        cursor = page.points.map(\.seq).max() ?? cursor
        hasMore = page.hasMore
        nextAfterSeq = page.nextAfterSeq
        gapsByBoundary = Self.gapDictionary(page.gaps)
        matchesByID = Self.matchDictionary(page.matches)
    }

    mutating func apply(_ delta: LiveTrailDelta) throws {
        guard delta.userId == userId, delta.trailId == trailId else {
            throw LiveTrailAssemblyError.differentTrail
        }
        guard delta.revision == revision else { throw LiveTrailAssemblyError.revisionChanged }
        guard delta.afterSeq == cursor else { throw LiveTrailAssemblyError.unexpectedCursor }
        guard delta.points.allSatisfy({ $0.seq > cursor }),
              delta.points.isEmpty || delta.toSeq == delta.points.map(\.seq).max() else {
            throw LiveTrailAssemblyError.invalidPage
        }
        for point in delta.points { pointsBySeq[point.seq] = point }
        for match in delta.matchedUpdates { matchesByID[match.segmentId] = match }
        cursor = delta.points.map(\.seq).max() ?? cursor
    }

    var orderedPoints: [LiveTrailPoint] {
        pointsBySeq.values.sorted {
            if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }
            return $0.seq < $1.seq
        }
    }

    var gaps: [LiveTrailGap] {
        gapsByBoundary.values.sorted {
            if $0.fromSeq != $1.fromSeq { return $0.fromSeq < $1.fromSeq }
            return $0.toSeq < $1.toSeq
        }
    }

    var matches: [LiveTrailMatch] { matchesByID.values.sorted { $0.segmentId < $1.segmentId } }

    var rawRuns: [[LiveTrailPoint]] {
        let ordered = orderedPoints
        guard let first = ordered.first else { return [] }
        var runs = [[first]]
        for point in ordered.dropFirst() {
            let previous = runs[runs.count - 1].last!
            if gapsByBoundary[GapBoundary(fromSeq: previous.seq, toSeq: point.seq)] != nil {
                runs.append([point])
            } else {
                runs[runs.count - 1].append(point)
            }
        }
        return runs
    }

    private static func validCursor(_ page: LiveTrailSnapshot, afterSeq: Int) -> Bool {
        guard page.points.allSatisfy({ $0.seq > 0 }) else { return false }
        if page.hasMore {
            guard let next = page.nextAfterSeq, next > afterSeq,
                  next == page.points.map(\.seq).max() else { return false }
        } else if page.nextAfterSeq != nil {
            return false
        }
        return true
    }

    private static func gapDictionary(_ gaps: [LiveTrailGap]) -> [GapBoundary: LiveTrailGap] {
        Dictionary(gaps.map { (GapBoundary(fromSeq: $0.fromSeq, toSeq: $0.toSeq), $0) },
                   uniquingKeysWith: { _, newest in newest })
    }

    private static func matchDictionary(_ matches: [LiveTrailMatch]) -> [String: LiveTrailMatch] {
        Dictionary(matches.map { ($0.segmentId, $0) }, uniquingKeysWith: { _, newest in newest })
    }
}
