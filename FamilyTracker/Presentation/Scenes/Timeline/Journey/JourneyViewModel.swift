import Foundation
import MapKit

enum JourneyLoadError: Equatable {
    case forbidden
    case failed
}

@MainActor
final class JourneyViewModel: ObservableObject {
    @Published private(set) var journeyEntries: [JourneyEntry] = []
    @Published private(set) var geocodedAddresses: [String: String] = [:]
    @Published private(set) var routeModel = RouteOverlayModel.empty
    @Published private(set) var trailDrawing = TrailDrawing.empty
    @Published private(set) var usesLiveTrail = false
    @Published private(set) var trailUnavailable = false
    @Published private(set) var trailRegion = MKCoordinateRegion.defaultCity
    @Published private(set) var cameraRequest = RouteCameraRequest(revision: 0, entryID: nil)
    @Published private(set) var selectedEntry: JourneyEntry?
    @Published private(set) var summary: DayJourneySummary?
    @Published private(set) var displayDate = Date()
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: JourneyLoadError?

    let userId: String
    let memberName: String

    private let fetchDayJourney: FetchDayJourneyUseCase
    private let fetchLiveTrail: FetchLiveTrailUseCase
    private let reverseGeocode: ReverseGeocodeUseCase
    private var geocodeTask: Task<Void, Never>?
    private var routeBuildTask: Task<RouteOverlayModel, Never>?
    private var trailBuildTask: Task<TrailDrawing, Never>?
    private var dayLoadTask: Task<Void, Never>?
    private var loadRevision = 0

    init(userId: String, memberName: String, fetchDayJourney: FetchDayJourneyUseCase,
         fetchLiveTrail: FetchLiveTrailUseCase, reverseGeocode: ReverseGeocodeUseCase) {
        self.userId = userId
        self.memberName = memberName
        self.fetchDayJourney = fetchDayJourney
        self.fetchLiveTrail = fetchLiveTrail
        self.reverseGeocode = reverseGeocode
    }

    deinit {
        geocodeTask?.cancel()
        routeBuildTask?.cancel()
        trailBuildTask?.cancel()
        dayLoadTask?.cancel()
    }

    var stayPoints: [StayPoint] {
        journeyEntries.compactMap {
            if case .stay(let stay) = $0 { return stay }
            return nil
        }
    }

    var selectedEntryID: String? { selectedEntry?.id }

    var totalStayMinutes: Int {
        summary?.totalStayMinutes ?? stayPoints.reduce(0) { $0 + $1.durationMinutes }
    }

    var totalMovingMinutes: Int {
        summary?.totalMovingMinutes ?? journeyEntries.reduce(0) { total, entry in
            if case .moving(let segment) = entry { return total + segment.durationMinutes }
            return total
        }
    }

    var selectedStayId: String? {
        if case .stay(let stay) = selectedEntry { return stay.id }
        return nil
    }

    var isToday: Bool { Calendar.current.isDateInToday(displayDate) }

    func formattedDisplayDate(locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM, yyyy"
        formatter.locale = locale
        return formatter.string(from: displayDate).capitalized
    }

    func address(for stayPoint: StayPoint) -> String {
        geocodedAddresses[stayPoint.arrivedAt] ?? "Đang tải địa chỉ..."
    }

    func load() async {
        loadRevision += 1
        let revision = loadRevision
        let day = displayDate
        routeBuildTask?.cancel()
        trailBuildTask?.cancel()
        geocodeTask?.cancel()
        isLoading = true
        loadError = nil
        defer { if revision == loadRevision { isLoading = false } }

        do {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            usesLiveTrail = true
            trailUnavailable = false
            do {
                let live = try await fetchLiveTrail(userId: userId, date: formatter.string(from: day))
                guard revision == loadRevision, !Task.isCancelled else { return }
                let buildTask = Task.detached(priority: .userInitiated) {
                    TrailDrawing.build(from: live)
                }
                trailBuildTask = buildTask
                let drawing = await buildTask.value
                guard revision == loadRevision, !Task.isCancelled else { return }
                trailDrawing = drawing
                usesLiveTrail = true
                fitTrail()
            } catch LiveTrailLoadError.notFound {
                trailDrawing = .empty
                usesLiveTrail = true
            } catch LiveTrailLoadError.unavailable {
                trailDrawing = .empty
                trailUnavailable = true
            } catch {
                if (error as? DomainError) == .forbidden { throw error }
                trailDrawing = .empty
                trailUnavailable = true
            }
            let journey: DayJourney
            do { journey = try await fetchDayJourney(userId: userId, day: day) }
            catch {
                if (error as? DomainError) == .forbidden { throw error }
                journey = DayJourney(date: nil, summary: nil, entries: [])
            }
            guard revision == loadRevision, !Task.isCancelled else { return }
            let buildTask = Task.detached(priority: .userInitiated) {
                RouteOverlayModel.build(from: journey, toleranceMeters: 8)
            }
            routeBuildTask = buildTask
            let model = await buildTask.value
            guard revision == loadRevision, !Task.isCancelled else { return }
            journeyEntries = journey.entries
            summary = journey.summary
            selectedEntry = nil
            routeModel = model
            cameraRequest = RouteCameraRequest(revision: cameraRequest.revision + 1, entryID: nil)
            geocodeStayPoints()
        } catch {
            guard revision == loadRevision, !Task.isCancelled else { return }
            journeyEntries = []
            summary = nil
            routeModel = .empty
            trailDrawing = .empty
            usesLiveTrail = false
            trailUnavailable = false
            selectedEntry = nil
            loadError = (error as? DomainError) == .forbidden ? .forbidden : .failed
        }
    }

    func goToPreviousDay() {
        guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: displayDate) else { return }
        changeDay(to: previous)
    }

    func goToNextDay() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: displayDate),
              next <= Date() else { return }
        changeDay(to: next)
    }

    func goToToday() { changeDay(to: Date()) }

    func select(_ entry: JourneyEntry) {
        selectedEntry = entry
        routeModel = routeModel.selecting(entry.id)
        cameraRequest = RouteCameraRequest(revision: cameraRequest.revision + 1,
                                           entryID: entry.id)
        if usesLiveTrail {
            switch entry {
            case .stay(let stay): focusTrail(on: [stay.point])
            case .moving(let moving): focusTrail(on: moving.path)
            }
        }
    }

    func selectEntry(id: String) {
        guard let entry = journeyEntries.first(where: { $0.id == id }) else { return }
        select(entry)
    }

    func recenter() {
        selectedEntry = nil
        routeModel = routeModel.selecting(nil)
        cameraRequest = RouteCameraRequest(revision: cameraRequest.revision + 1,
                                           entryID: nil)
        if usesLiveTrail { fitTrail() }
    }

    func cancelPendingWork() {
        loadRevision += 1
        dayLoadTask?.cancel()
        routeBuildTask?.cancel()
        trailBuildTask?.cancel()
        geocodeTask?.cancel()
    }

    private func changeDay(to day: Date) {
        loadRevision += 1
        dayLoadTask?.cancel()
        routeBuildTask?.cancel()
        trailBuildTask?.cancel()
        geocodeTask?.cancel()
        displayDate = day
        journeyEntries = []
        summary = nil
        routeModel = .empty
        trailDrawing = .empty
        usesLiveTrail = false
        trailUnavailable = false
        selectedEntry = nil
        dayLoadTask = Task { [weak self] in await self?.load() }
    }

    private func geocodeStayPoints() {
        let pending = stayPoints.filter { geocodedAddresses[$0.arrivedAt] == nil }
        geocodeTask = Task { [weak self, reverseGeocode] in
            for stay in pending {
                guard !Task.isCancelled else { return }
                let address = await reverseGeocode(stay.point) ?? "Không xác định"
                guard !Task.isCancelled else { return }
                self?.geocodedAddresses[stay.arrivedAt] = address
            }
        }
    }

    private func fitTrail() {
        focusTrail(on: trailDrawing.lines.flatMap(\.points) + trailDrawing.fixes)
    }

    private func focusTrail(on points: [GeoPoint]) {
        guard let bounds = RouteBounds(points: points) else { return }
        let padded = bounds.padded(by: 1.3)
        trailRegion = MKCoordinateRegion(center: padded.center.coordinate,
                                         span: MKCoordinateSpan(latitudeDelta: max(0.005, padded.latitudeSpan),
                                                                longitudeDelta: max(0.005, padded.longitudeSpan)))
    }
}
