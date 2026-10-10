import Foundation
import MapKit

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var historyEntries: [LocationHistoryEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var displayDate = ""
    @Published var selectedEntry: LocationHistoryEntry?
    @Published var historyMapRegion: MKCoordinateRegion = .defaultCity

    let userId: String
    private let fetchHistory: FetchLocationHistoryUseCase

    init(userId: String, fetchHistory: FetchLocationHistoryUseCase) {
        self.userId = userId
        self.fetchHistory = fetchHistory
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let history = try await fetchHistory(userId: userId)
            historyEntries = history.entries
            displayDate = history.date ?? FetchDayJourneyUseCase.apiDateString(Date())
            if let first = history.entries.first {
                historyMapRegion = MKCoordinateRegion(center: first.coordinate, delta: 0.03)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ entry: LocationHistoryEntry) {
        selectedEntry = entry
        historyMapRegion = MKCoordinateRegion(center: entry.coordinate, delta: 0.005)
    }

    func formattedDisplayDate(locale: Locale) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: displayDate) else { return displayDate }
        let output = DateFormatter()
        output.dateFormat = "d MMMM, yyyy"
        output.locale = locale
        return output.string(from: date)
    }

    var totalStops: Int { historyEntries.count }

    var timeRange: String {
        guard let first = historyEntries.first?.formattedTime,
              let last = historyEntries.last?.formattedTime else { return "-" }
        return "\(first) - \(last)"
    }
}
