import Foundation
import Combine

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published private(set) var query = ""
    @Published private(set) var suggestions: [PlaceSearchSuggestion] = []
    @Published private(set) var results: [PlaceSearchResult] = []
    @Published private(set) var recent: [RecentPlaceSearch] = []
    @Published private(set) var isLoading = false
    @Published private(set) var didSearch = false
    @Published private(set) var failure: PlaceSearchFailure?
    @Published private(set) var historyFailed = false
    private(set) var isActive = false
    private var sessionEnded = false
    private let search: PlaceSearchUseCases
    private let history: SearchHistoryUseCases
    private let sleep: (UInt64) async throws -> Void
    private var region: PlaceSearchRegion?
    private var requestTask: Task<Void, Never>?
    private var generation = 0
    private var lastOperation: Operation?

    private enum Operation {
        case suggestions(String)
        case search(String)
        case resolve(PlaceSearchSuggestion, String)
    }

    init(search: PlaceSearchUseCases, history: SearchHistoryUseCases,
         sleep: @escaping (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        self.search = search
        self.history = history
        self.sleep = sleep
    }

    deinit { requestTask?.cancel() }

    var failureKey: String? {
        switch failure {
        case .invalidQuery: return "search.error.query"
        case .throttled: return "search.error.throttled"
        case .some: return "search.error.unavailable"
        case .none: return nil
        }
    }

    var canRetry: Bool { failure != nil && failure != .invalidQuery && lastOperation != nil }

    func open(in region: PlaceSearchRegion) {
        guard !sessionEnded else { return }
        stop()
        self.region = region
        isActive = true
        query = ""
        didSearch = false
        failure = nil
        lastOperation = nil
        loadHistory()
    }

    func updateQuery(_ text: String) {
        guard isActive else { return }
        cancelPending()
        query = text
        failure = nil
        lastOperation = nil
        didSearch = false
        suggestions = []
        results = []
        let trimmed = PlaceSearchQuery.trimmed(text)
        guard !trimmed.isEmpty else { loadHistory(); return }
        guard (2...200).contains(trimmed.count) else {
            if trimmed.count > 200 { failure = .invalidQuery }
            return
        }
        perform(.suggestions(trimmed), debounce: true)
    }

    func submit() {
        guard isActive else { return }
        do { perform(.search(try PlaceSearchQuery.validated(query))) }
        catch { cancelPending(); failure = .invalidQuery }
    }

    func chooseSuggestion(_ suggestion: PlaceSearchSuggestion) {
        guard isActive, suggestions.contains(suggestion) else { return }
        do { perform(.resolve(suggestion, try PlaceSearchQuery.validated(query))) }
        catch { failure = .invalidQuery }
    }

    func chooseRecent(_ entry: RecentPlaceSearch) {
        guard isActive, recent.contains(entry) else { return }
        query = entry.query
        submit()
    }

    /// Coordinator checks this capability before dismissing/focusing a result.
    func accept(_ result: PlaceSearchResult) -> Bool {
        guard isActive, !sessionEnded, results.contains(result) else { return false }
        stop()
        return true
    }

    func retry() {
        guard isActive, let operation = lastOperation else { return }
        switch operation {
        case let .suggestions(query): perform(.suggestions(query))
        case let .search(query), let .resolve(_, query): perform(.search(query))
        }
    }

    func removeRecent(_ entry: RecentPlaceSearch) {
        guard isActive else { return }
        do { try history.remove(entry.id); loadHistory() }
        catch { historyFailed = true }
    }

    func clearHistory() {
        guard isActive else { return }
        do { try history.clear(); loadHistory() }
        catch { historyFailed = true }
    }

    func stop() {
        cancelPending()
        isActive = false
        suggestions = []
        results = []
    }

    /// Called synchronously at session teardown, before any async logout work.
    func endSession() {
        guard !sessionEnded else { return }
        stop()
        sessionEnded = true
        lastOperation = nil
        region = nil
        query = ""
        recent = []
        do { try history.clear() }
        catch { historyFailed = true }
    }

    private func cancelPending() {
        generation += 1
        requestTask?.cancel()
        requestTask = nil
        search.cancel()
        isLoading = false
    }

    private func loadHistory() {
        do { recent = try history.recent(); historyFailed = false }
        catch { recent = []; historyFailed = true }
    }

    private func record(_ query: String) {
        do { try history.record(query); loadHistory() }
        catch { historyFailed = true }
    }

    private func perform(_ operation: Operation, debounce: Bool = false) {
        guard isActive, let region else { return }
        cancelPending()
        let version = generation
        lastOperation = operation
        failure = nil
        suggestions = []
        results = []
        isLoading = true
        switch operation {
        case .suggestions: didSearch = false
        case let .search(query), let .resolve(_, query):
            didSearch = true
            record(query)
        }
        let useCases = search
        let wait = sleep
        requestTask = Task { [weak self] in
            do {
                if debounce { try await wait(300_000_000) }
                try Task.checkCancellation()
                switch operation {
                case let .suggestions(query):
                    let values = try await useCases.suggestions(for: query, in: region)
                    guard !Task.isCancelled, let self, self.isActive, self.generation == version else { return }
                    self.suggestions = values
                case let .search(query):
                    let values = try await useCases.search(query: query, in: region)
                    guard !Task.isCancelled, let self, self.isActive, self.generation == version else { return }
                    self.results = values
                case let .resolve(suggestion, _):
                    let values = try await useCases.resolve(suggestion, in: region)
                    guard !Task.isCancelled, let self, self.isActive, self.generation == version else { return }
                    self.results = values
                }
                guard let self, self.generation == version else { return }
                self.isLoading = false
                self.requestTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.isActive, self.generation == version else { return }
                self.isLoading = false
                self.requestTask = nil
                if error is CancellationError { return }
                self.failure = (error as? PlaceSearchFailure) ?? .unavailable
            }
        }
    }
}
