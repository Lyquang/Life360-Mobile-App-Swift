import Foundation

enum FetchLiveTrailError: Error {
    case pageLimitExceeded
    case revisionChangedTwice
}

struct FetchLiveTrailUseCase {
    let repository: LiveTrailRepository
    let pageLimit: Int
    let maxPages: Int

    init(repository: LiveTrailRepository, pageLimit: Int = 200, maxPages: Int = 200) {
        self.repository = repository
        self.pageLimit = min(500, max(1, pageLimit))
        self.maxPages = max(1, maxPages)
    }

    func callAsFunction(userId: String, date: String) async throws -> LiveTrailAssembler {
        for attempt in 0..<2 {
            do {
                try Task.checkCancellation()
                let first = try await repository.snapshot(userId: userId, date: date, limit: pageLimit)
                var trail = try LiveTrailAssembler(firstPage: first)
                var loadedPages = 1
                while trail.hasMore {
                    try Task.checkCancellation()
                    guard loadedPages < maxPages, let cursor = trail.nextAfterSeq else {
                        throw FetchLiveTrailError.pageLimitExceeded
                    }
                    let page = try await repository.catchUp(userId: userId, date: date,
                                                            afterSeq: cursor, revision: trail.revision,
                                                            limit: pageLimit)
                    try trail.append(page, requestedAfterSeq: cursor)
                    loadedPages += 1
                }
                return trail
            } catch LiveTrailLoadError.revisionChanged {
                if attempt == 1 { throw FetchLiveTrailError.revisionChangedTwice }
            } catch LiveTrailAssemblyError.revisionChanged {
                if attempt == 1 { throw FetchLiveTrailError.revisionChangedTwice }
            }
        }
        throw FetchLiveTrailError.revisionChangedTwice
    }

    func catchUp(_ current: LiveTrailAssembler) async throws -> LiveTrailAssembler {
        var trail = current
        var pages = 0
        repeat {
            try Task.checkCancellation()
            guard pages < maxPages else { throw FetchLiveTrailError.pageLimitExceeded }
            let page = try await repository.catchUp(userId: trail.userId, date: trail.date,
                                                    afterSeq: trail.cursor, revision: trail.revision,
                                                    limit: pageLimit)
            let previous = trail.cursor
            try trail.append(page, requestedAfterSeq: previous)
            pages += 1
        } while trail.hasMore
        return trail
    }
}
