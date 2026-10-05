import Foundation

struct FetchLocationHistoryUseCase {
    let repository: HistoryRepository

    func callAsFunction(userId: String) async throws -> LocationHistory {
        try await repository.fetchTodayHistory(userId: userId)
    }
}

struct FetchDayJourneyUseCase {
    let repository: HistoryRepository

    func callAsFunction(userId: String, day: Date, calendar: Calendar = .current) async throws -> DayJourney {
        let date: String? = calendar.isDateInToday(day) ? nil : Self.apiDateString(day)
        return try await repository.fetchDayJourney(userId: userId, date: date)
    }

    static func apiDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct ReverseGeocodeUseCase {
    let repository: GeocodingRepository

    func callAsFunction(_ point: GeoPoint) async -> String? {
        await repository.address(for: point)
    }
}
