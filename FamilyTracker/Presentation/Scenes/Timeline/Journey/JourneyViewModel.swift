import Foundation
import MapKit

@MainActor
final class JourneyViewModel: ObservableObject {
    @Published private(set) var journeyEntries: [JourneyEntry] = []
    @Published private(set) var geocodedAddresses: [String: String] = [:]
    @Published var journeyMapRegion = MKCoordinateRegion(center: MKCoordinateRegion.defaultCity.center, delta: 0.1)
    @Published private(set) var selectedEntry: JourneyEntry?
    @Published private(set) var summary: DayJourneySummary?
    @Published private(set) var displayDate = Date()
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let userId: String
    let memberName: String

    private let fetchDayJourney: FetchDayJourneyUseCase
    private let reverseGeocode: ReverseGeocodeUseCase
    private var geocodeTask: Task<Void, Never>?

    init(userId: String, memberName: String, fetchDayJourney: FetchDayJourneyUseCase, reverseGeocode: ReverseGeocodeUseCase) {
        self.userId = userId
        self.memberName = memberName
        self.fetchDayJourney = fetchDayJourney
        self.reverseGeocode = reverseGeocode
    }

    deinit {
        geocodeTask?.cancel()
    }

    // MARK: - Derived

    var stayPoints: [StayPoint] {
        journeyEntries.compactMap {
            if case .stay(let sp) = $0 { return sp }
            return nil
        }
    }

    var formattedDisplayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM, yyyy"
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: displayDate).capitalized
    }

    var isToday: Bool { Calendar.current.isDateInToday(displayDate) }

    var selectedStayId: String? {
        if case .stay(let sp) = selectedEntry { return sp.id }
        return nil
    }

    func address(for stayPoint: StayPoint) -> String {
        geocodedAddresses[stayPoint.arrivedAt] ?? "Đang tải địa chỉ..."
    }

    // MARK: - Actions

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let journey = try await fetchDayJourney(userId: userId, day: displayDate)
            journeyEntries = journey.entries
            summary = journey.summary
            fitMapToJourney()
            geocodeStayPoints()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goToPreviousDay() {
        displayDate = Calendar.current.date(byAdding: .day, value: -1, to: displayDate) ?? displayDate
        Task { await load() }
    }

    func goToNextDay() {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: displayDate) ?? displayDate
        guard next <= Date() else { return }
        displayDate = next
        Task { await load() }
    }

    func goToToday() {
        displayDate = Date()
        Task { await load() }
    }

    func select(_ entry: JourneyEntry) {
        selectedEntry = entry
        switch entry {
        case .stay(let sp):
            journeyMapRegion = MKCoordinateRegion(center: sp.coordinate, delta: 0.005)
        case .moving(let ms):
            if let region = MKCoordinateRegion(fitting: ms.polylineCoordinates, padding: 1.5) {
                journeyMapRegion = region
            }
        }
    }

    // MARK: - Private

    private func fitMapToJourney() {
        let coordinates = journeyEntries.flatMap(\.points).map(\.coordinate)
        if let region = MKCoordinateRegion(fitting: coordinates) {
            journeyMapRegion = region
        }
    }

    private func geocodeStayPoints() {
        geocodeTask?.cancel()
        let pending = stayPoints.filter { geocodedAddresses[$0.arrivedAt] == nil }
        geocodeTask = Task { [weak self, reverseGeocode] in
            for stayPoint in pending {
                guard !Task.isCancelled else { return }
                let address = await reverseGeocode(stayPoint.point) ?? "Không xác định"
                self?.geocodedAddresses[stayPoint.arrivedAt] = address
            }
        }
    }
}
