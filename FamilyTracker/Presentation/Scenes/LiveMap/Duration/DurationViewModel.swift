import Foundation

@MainActor
final class DurationViewModel: ObservableObject {
    @Published private(set) var memberLocations: [MemberLocation] = []
    @Published var stayAlerts: [LocationStayAlert] = []

    private let observeMemberLocations: ObserveMemberLocationsUseCase
    private let observeStayAlerts: ObserveStayAlertsUseCase
    private var tasks: [Task<Void, Never>] = []

    init(observeMemberLocations: ObserveMemberLocationsUseCase, observeStayAlerts: ObserveStayAlertsUseCase) {
        self.observeMemberLocations = observeMemberLocations
        self.observeStayAlerts = observeStayAlerts
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    func start() {
        guard tasks.isEmpty else { return }
        let locations = observeMemberLocations()
        let alerts = observeStayAlerts()

        tasks.append(Task { [weak self] in
            for await location in locations { self?.upsert(location) }
        })
        tasks.append(Task { [weak self] in
            for await alert in alerts { self?.show(alert) }
        })
    }

    func dismiss(_ alert: LocationStayAlert) {
        stayAlerts.removeAll { $0.id == alert.id }
    }

    private func show(_ alert: LocationStayAlert) {
        stayAlerts.append(alert)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            self?.dismiss(alert)
        }
    }

    private func upsert(_ location: MemberLocation) {
        if let index = memberLocations.firstIndex(where: { $0.id == location.id }) {
            memberLocations[index] = location
        } else {
            memberLocations.append(location)
        }
    }
}
