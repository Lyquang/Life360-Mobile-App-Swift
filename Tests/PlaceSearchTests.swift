import Foundation

private struct SearchTestFailure: Error, CustomStringConvertible {
    let description: String
}

@MainActor
private final class FakeSearchRepository: PlaceSearchRepository {
    var suggestionsCalled: [String] = []
    var searchesCalled: [String] = []
    var resolved: [String] = []
    var cancelCount = 0
    var failure: PlaceSearchFailure?
    var holdSuggestions = false
    var holdSearches = false
    var pendingSuggestions: [String: CheckedContinuation<[PlaceSearchSuggestion], Error>] = [:]
    var pendingSearches: [String: CheckedContinuation<[PlaceSearchResult], Error>] = [:]
    let suggestion = PlaceSearchSuggestion(id: "suggestion", title: "Apple POI title", subtitle: "Provider address")
    let result = PlaceSearchResult(id: "result", name: "Resolved POI", address: "Provider address",
                                   point: GeoPoint(latitude: 10.77, longitude: 106.7))
    var emptyResults = false

    func suggestions(for query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchSuggestion] {
        suggestionsCalled.append(query)
        if let failure { throw failure }
        if holdSuggestions {
            return try await withCheckedThrowingContinuation { pendingSuggestions[query] = $0 }
        }
        return [suggestion]
    }
    func search(query: String, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] {
        searchesCalled.append(query)
        if let failure { throw failure }
        if holdSearches {
            return try await withCheckedThrowingContinuation { pendingSearches[query] = $0 }
        }
        return emptyResults ? [] : [result]
    }
    func resolve(_ suggestion: PlaceSearchSuggestion, in region: PlaceSearchRegion) async throws -> [PlaceSearchResult] {
        resolved.append(suggestion.id)
        if let failure { throw failure }
        return [result]
    }
    // Intentionally ignore cancellation to verify that obsolete callbacks cannot publish.
    func cancel() { cancelCount += 1 }
}

@MainActor
private final class BrokenHistory: SearchHistoryRepository {
    func recentSearches(for accountID: String) throws -> [RecentPlaceSearch] { throw PlaceSearchFailure.historyUnavailable }
    func record(query: String, for accountID: String) throws { throw PlaceSearchFailure.historyUnavailable }
    func remove(id: String, for accountID: String) throws { throw PlaceSearchFailure.historyUnavailable }
    func clear(for accountID: String) throws { throw PlaceSearchFailure.historyUnavailable }
}

@MainActor
private final class DebounceGate {
    var waits: [CheckedContinuation<Void, Error>] = []
    func sleep(_ interval: UInt64) async throws {
        try await withCheckedThrowingContinuation { waits.append($0) }
    }
    func release() { let pending = waits; waits = []; pending.forEach { $0.resume() } }
}

@MainActor
@main
private struct PlaceSearchTests {
    static var passed = 0
    static let region = PlaceSearchRegion(center: GeoPoint(latitude: 10.77, longitude: 106.7),
                                          latitudeDelta: 0.1, longitudeDelta: 0.1)

    static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw SearchTestFailure(description: message) }
    }
    static func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            await Task.yield()
        }
        throw SearchTestFailure(description: "Timed out waiting for deterministic test state")
    }
    static func test(_ name: String, _ body: () async throws -> Void) async throws {
        try await body()
        passed += 1
        print("PASS: \(name)")
    }
    static func defaults() -> (UserDefaults, String) {
        let name = "place-search-tests-" + UUID().uuidString
        return (UserDefaults(suiteName: name)!, name)
    }
    static func model(_ repo: FakeSearchRepository, _ history: SearchHistoryRepository,
                      sleep: @escaping (UInt64) async throws -> Void = { _ in await Task.yield() }) -> PlaceSearchViewModel {
        let vm = PlaceSearchViewModel(search: PlaceSearchUseCases(repository: repo),
                                      history: SearchHistoryUseCases(repository: history, accountID: "account-A"),
                                      sleep: sleep)
        vm.open(in: region)
        return vm
    }
    static func main() async throws {
        try await test("cache survives recreation, trims and deduplicates user query") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            var clock = Date(timeIntervalSince1970: 1000)
            let cache = SearchHistoryCache(defaults: store, now: { clock })
            try cache.record(query: "  Quán   Café  ", for: "account-A")
            clock.addTimeInterval(1)
            try cache.record(query: "quan cafe", for: "account-A")
            let restored = SearchHistoryCache(defaults: store, now: { clock })
            try expect(restored.recentSearches(for: "account-A").map(\.query) == ["quan cafe"], "Normalized duplicate or persistence failed")
        }
        try await test("history capped at 20, newest first") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            var clock = Date(timeIntervalSince1970: 1000)
            let cache = SearchHistoryCache(defaults: store, now: { clock })
            for index in 0..<25 { clock.addTimeInterval(1); try cache.record(query: "Place \(index)", for: "A") }
            let items = try cache.recentSearches(for: "A")
            try expect(items.count == 20 && items.first?.query == "Place 24" && items.last?.query == "Place 5", "History cap/order failed")
        }
        try await test("30-day expiry enforced on read at exact boundary") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            var clock = Date(timeIntervalSince1970: 1000)
            let cache = SearchHistoryCache(defaults: store, now: { clock })
            try cache.record(query: "Old query", for: "A")
            clock.addTimeInterval(30 * 24 * 60 * 60 - 1)
            try expect(cache.recentSearches(for: "A").count == 1, "Expired too early")
            clock.addTimeInterval(1)
            try expect(cache.recentSearches(for: "A").isEmpty, "Stale history retained")
        }
        try await test("accounts isolated; delete-one and clear preserve other account") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store)
            try cache.record(query: "First query", for: "A")
            try cache.record(query: "Second query", for: "A")
            try cache.record(query: "Other account", for: "B")
            try cache.remove(id: PlaceSearchQuery.key("First query"), for: "A")
            try expect(cache.recentSearches(for: "A").map(\.query) == ["Second query"], "Delete-one failed")
            try cache.clear(for: "A")
            try expect(cache.recentSearches(for: "A").isEmpty, "Clear failed")
            try expect(cache.recentSearches(for: "B").map(\.query) == ["Other account"], "Cross-account mutation")
        }
        try await test("invalid input not written and account storage key is hashed") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store)
            for query in ["a", "   ", String(repeating: "x", count: 201)] {
                do { try cache.record(query: query, for: "private-account"); throw SearchTestFailure(description: "Accepted invalid query") }
                catch PlaceSearchFailure.invalidQuery { }
            }
            try cache.record(query: "Valid query", for: "private-account")
            let keys = store.dictionaryRepresentation().keys.filter { $0.hasPrefix("places.recent.v1.") }
            try expect(keys.count == 1 && !keys[0].contains("private-account"), "Raw account ID in cache key")
            let text = String(data: store.data(forKey: keys[0])!, encoding: .utf8)!
            try expect(!text.contains("latitude") && !text.contains("address") && !text.contains("token"), "Unexpected private provider fields")
        }
        try await test("corrupt cache recovers to empty, then accepts new history") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store)
            try cache.record(query: "Any query", for: "A")
            let key = store.dictionaryRepresentation().keys.first { $0.hasPrefix("places.recent.v1.") }!
            store.set(Data("broken-json".utf8), forKey: key)
            try expect(cache.recentSearches(for: "A").isEmpty, "Corruption not recovered")
            try cache.record(query: "New query", for: "A")
            try expect(cache.recentSearches(for: "A").count == 1, "Recovery blocks new writes")
        }
        try await test("future timestamp cannot become immortal cache entry") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let now = Date(timeIntervalSince1970: 1000)
            let cache = SearchHistoryCache(defaults: store, now: { now })
            try cache.record(query: "Any query", for: "A")
            let key = store.dictionaryRepresentation().keys.first { $0.hasPrefix("places.recent.v1.") }!
            store.set(try JSONEncoder().encode([RecentPlaceSearch(query: "Future query", lastUsedAt: now.addingTimeInterval(100))]), forKey: key)
            try expect(cache.recentSearches(for: "A").isEmpty, "Future timestamp trusted")
        }
        try await test("keystrokes get suggestions without history; empty input clears") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store); let repo = FakeSearchRepository(); let vm = model(repo, cache)
            vm.updateQuery("cafe")
            try await wait { !vm.isLoading }
            try expect(vm.suggestions == [repo.suggestion], "Suggestions missing")
            try expect(cache.recentSearches(for: "account-A").isEmpty, "Logged keystrokes")
            vm.updateQuery("")
            try expect(vm.suggestions.isEmpty && vm.results.isEmpty && vm.failure == nil, "Empty input did not reset")
            vm.stop()
        }
        try await test("debounce cancels obsolete query before provider call") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let gate = DebounceGate(); let repo = FakeSearchRepository()
            let vm = model(repo, SearchHistoryCache(defaults: store), sleep: gate.sleep)
            vm.updateQuery("old")
            try await wait { gate.waits.count == 1 }
            vm.updateQuery("new")
            try await wait { gate.waits.count == 2 }
            gate.release()
            try await wait { !vm.isLoading }
            try expect(repo.suggestionsCalled == ["new"], "Debounce called old provider query")
            vm.stop()
        }
        try await test("stale completion cannot overwrite newest query") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let repo = FakeSearchRepository(); repo.holdSuggestions = true
            let vm = model(repo, SearchHistoryCache(defaults: store))
            vm.updateQuery("old")
            try await wait { repo.pendingSuggestions["old"] != nil }
            vm.updateQuery("new")
            try await wait { repo.pendingSuggestions["new"] != nil }
            repo.pendingSuggestions.removeValue(forKey: "new")!.resume(returning: [repo.suggestion])
            try await wait { !vm.isLoading }
            repo.pendingSuggestions.removeValue(forKey: "old")!.resume(returning: [])
            for _ in 0..<10 { await Task.yield() }
            try expect(vm.query == "new" && vm.suggestions == [repo.suggestion], "Obsolete response published")
            vm.stop()
        }
        try await test("submit records only typed query, returns results and authorizes selection") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store); let repo = FakeSearchRepository(); let vm = model(repo, cache)
            vm.updateQuery("typed query"); vm.submit()
            try await wait { !vm.isLoading }
            try expect(repo.searchesCalled == ["typed query"] && vm.results == [repo.result], "Submit failed")
            try expect(cache.recentSearches(for: "account-A").map(\.query) == ["typed query"], "Stored POI instead of typed query")
            try expect(vm.accept(repo.result), "Valid selection rejected")
            try expect(!vm.accept(repo.result), "Accepted selection after dismissal")
        }
        try await test("selected suggestion resolves rather than using displayed POI as history") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store); let repo = FakeSearchRepository(); let vm = model(repo, cache)
            vm.updateQuery("typed fragment"); try await wait { !vm.isLoading }
            vm.chooseSuggestion(repo.suggestion); try await wait { !vm.isLoading }
            try expect(repo.resolved == [repo.suggestion.id] && vm.results == [repo.result], "Suggestion not resolved")
            try expect(cache.recentSearches(for: "account-A").map(\.query) == ["typed fragment"], "Cached Apple title/address")
            vm.stop()
        }
        try await test("recent query fetches fresh results; clear/delete update UI") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store); try cache.record(query: "old query", for: "account-A")
            let repo = FakeSearchRepository(); let vm = model(repo, cache)
            vm.chooseRecent(vm.recent[0]); try await wait { !vm.isLoading }
            try expect(repo.searchesCalled == ["old query"], "History did not fetch again")
            vm.removeRecent(vm.recent[0]); try expect(vm.recent.isEmpty, "Delete UI stale")
            vm.updateQuery("another query"); vm.submit(); try await wait { !vm.isLoading }
            vm.clearHistory(); try expect(vm.recent.isEmpty, "Clear UI stale")
            vm.stop()
        }
        try await test("typed provider failure has retry; empty response distinct from failure") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let repo = FakeSearchRepository(); repo.failure = .throttled
            let vm = model(repo, SearchHistoryCache(defaults: store))
            vm.updateQuery("cafe"); vm.submit(); try await wait { !vm.isLoading }
            try expect(vm.failureKey == "search.error.throttled" && vm.canRetry, "Wrong failure/retry state")
            repo.failure = nil; repo.emptyResults = true; vm.retry(); try await wait { !vm.isLoading }
            try expect(vm.didSearch && vm.results.isEmpty && vm.failure == nil, "Empty confused with outage")
            vm.stop()
        }
        try await test("bad input never calls provider or records history") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let repo = FakeSearchRepository(); let cache = SearchHistoryCache(defaults: store); let vm = model(repo, cache)
            for query in [" ", "a", String(repeating: "a", count: 201)] {
                vm.updateQuery(query); vm.submit()
                try expect(vm.failure == .invalidQuery && !vm.canRetry, "Invalid query or retry state wrong")
            }
            try expect(repo.searchesCalled.isEmpty && repo.suggestionsCalled.isEmpty, "Invalid query reached provider")
            try expect(cache.recentSearches(for: "account-A").isEmpty, "Invalid query persisted")
            vm.stop()
        }
        try await test("close cancels request, suppresses late result and preserves history") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let repo = FakeSearchRepository(); repo.holdSearches = true
            let cache = SearchHistoryCache(defaults: store); let vm = model(repo, cache)
            vm.updateQuery("pending query"); vm.submit()
            try await wait { repo.pendingSearches["pending query"] != nil }
            vm.stop()
            repo.pendingSearches.removeValue(forKey: "pending query")!.resume(returning: [repo.result])
            for _ in 0..<10 { await Task.yield() }
            try expect(vm.results.isEmpty && !vm.isLoading && !vm.accept(repo.result), "Late result after close")
            try expect(cache.recentSearches(for: "account-A").count == 1, "Dismiss cleared session history")
            vm.open(in: region); try expect(vm.recent.count == 1, "Reopen lost history")
            vm.stop()
        }
        try await test("session end clears own history and permanently revokes old model") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store); try cache.record(query: "Other account", for: "B")
            let repo = FakeSearchRepository(); repo.holdSearches = true; let vm = model(repo, cache)
            vm.updateQuery("private query"); vm.submit()
            try await wait { repo.pendingSearches["private query"] != nil }
            vm.endSession()
            repo.pendingSearches.removeValue(forKey: "private query")!.resume(returning: [repo.result])
            for _ in 0..<10 { await Task.yield() }
            vm.open(in: region); vm.updateQuery("must not write"); vm.submit()
            try expect(!vm.isActive && vm.recent.isEmpty && vm.results.isEmpty, "Old model reactivated")
            try expect(cache.recentSearches(for: "account-A").isEmpty, "History recreated after logout")
            try expect(cache.recentSearches(for: "B").count == 1, "Other account cleared")
        }
        try await test("cache failure visible without breaking provider search") {
            let repo = FakeSearchRepository(); let vm = model(repo, BrokenHistory())
            try expect(vm.historyFailed, "History read failure hidden")
            vm.updateQuery("cafe"); vm.submit(); try await wait { !vm.isLoading }
            try expect(vm.historyFailed && vm.results == [repo.result], "Cache failure broke search")
            vm.stop()
        }
        try await test("late failure cannot replace newer search success") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let repo = FakeSearchRepository(); repo.holdSearches = true
            let vm = model(repo, SearchHistoryCache(defaults: store))
            vm.updateQuery("old search"); vm.submit()
            try await wait { repo.pendingSearches["old search"] != nil }
            vm.updateQuery("new search"); vm.submit()
            try await wait { repo.pendingSearches["new search"] != nil }
            repo.pendingSearches.removeValue(forKey: "new search")!.resume(returning: [repo.result])
            try await wait { !vm.isLoading }
            repo.pendingSearches.removeValue(forKey: "old search")!.resume(throwing: PlaceSearchFailure.unavailable)
            for _ in 0..<10 { await Task.yield() }
            try expect(vm.failure == nil && vm.results == [repo.result], "Stale failure replaced success")
            vm.stop()
        }
        try await test("old session teardown is idempotent and cannot clear a later session cache") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let cache = SearchHistoryCache(defaults: store)
            let vm = model(FakeSearchRepository(), cache)
            vm.endSession()
            try cache.record(query: "New session query", for: "account-A")
            vm.endSession()
            try expect(cache.recentSearches(for: "account-A").map(\.query) == ["New session query"], "Old teardown erased later history")
        }
        try await test("view model deallocates while canceled provider ignores cancellation") {
            let (store, name) = defaults(); defer { store.removePersistentDomain(forName: name) }
            let repo = FakeSearchRepository(); repo.holdSearches = true
            var vm: PlaceSearchViewModel? = model(repo, SearchHistoryCache(defaults: store))
            weak var weakModel = vm
            vm?.updateQuery("pending release"); vm?.submit()
            try await wait { repo.pendingSearches["pending release"] != nil }
            vm = nil
            try expect(weakModel == nil, "Search task retained view model")
            repo.pendingSearches.removeValue(forKey: "pending release")!.resume(returning: [])
            for _ in 0..<10 { await Task.yield() }
        }
        print("Place search: \(passed) tests passed")
    }
}
