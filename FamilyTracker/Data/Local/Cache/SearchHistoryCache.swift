import Foundation
import CryptoKit

/// A disposable on-device query cache. No Apple POI payload or GPS is stored.
@MainActor
final class SearchHistoryCache: SearchHistoryRepository {
    private let defaults: UserDefaults
    private let now: () -> Date
    private let lifetime: TimeInterval = 30 * 24 * 60 * 60
    private let limit = 20

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    func recentSearches(for accountID: String) throws -> [RecentPlaceSearch] {
        guard !accountID.isEmpty else { throw PlaceSearchFailure.historyUnavailable }
        let cacheKey = key(accountID)
        guard let data = defaults.data(forKey: cacheKey) else { return [] }
        let decoded: [RecentPlaceSearch]
        do { decoded = try JSONDecoder().decode([RecentPlaceSearch].self, from: data) }
        catch {
            // Cache is disposable; remove corrupt state instead of blocking search.
            defaults.removeObject(forKey: cacheKey)
            return []
        }
        let clock = now()
        var seen = Set<String>()
        let valid = decoded.sorted { $0.lastUsedAt > $1.lastUsedAt }.filter {
            (2...200).contains(PlaceSearchQuery.trimmed($0.query).count) &&
                $0.lastUsedAt <= clock && clock.timeIntervalSince($0.lastUsedAt) < lifetime &&
                seen.insert($0.id).inserted
        }
        let entries = Array(valid.prefix(limit))
        if entries != decoded { try save(entries, for: accountID) }
        return entries
    }

    func record(query: String, for accountID: String) throws {
        let query = try PlaceSearchQuery.validated(query)
        var entries = try recentSearches(for: accountID)
        let id = PlaceSearchQuery.key(query)
        entries.removeAll { $0.id == id }
        entries.insert(RecentPlaceSearch(query: query, lastUsedAt: now()), at: 0)
        try save(Array(entries.prefix(limit)), for: accountID)
    }

    func remove(id: String, for accountID: String) throws {
        try save(recentSearches(for: accountID).filter { $0.id != id }, for: accountID)
    }

    func clear(for accountID: String) throws {
        guard !accountID.isEmpty else { throw PlaceSearchFailure.historyUnavailable }
        defaults.removeObject(forKey: key(accountID))
    }

    private func save(_ entries: [RecentPlaceSearch], for accountID: String) throws {
        do { defaults.set(try JSONEncoder().encode(entries), forKey: key(accountID)) }
        catch { throw PlaceSearchFailure.historyUnavailable }
    }

    private func key(_ accountID: String) -> String {
        let hash = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
        return "places.recent.v1." + hash
    }
}
