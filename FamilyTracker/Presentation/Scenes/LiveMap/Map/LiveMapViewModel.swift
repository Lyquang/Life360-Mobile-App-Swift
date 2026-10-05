import Foundation
import MapKit

@MainActor
final class LiveMapViewModel: ObservableObject {
    @Published var mapRegion: MKCoordinateRegion = .defaultCity
    @Published private(set) var memberLocations: [MemberLocation] = []
    @Published private(set) var connectionState: RealtimeConnectionState
    @Published var isTrackingUser = true

    let currentUserId: String

    private let observeMemberLocations: ObserveMemberLocationsUseCase
    private let observeConnection: ObserveConnectionStateUseCase
    private let observeDeviceLocation: ObserveDeviceLocationUseCase
    private let getCurrentLocation: GetCurrentLocationUseCase
    private var tasks: [Task<Void, Never>] = []

    init(
        currentUserId: String,
        observeMemberLocations: ObserveMemberLocationsUseCase,
        observeConnection: ObserveConnectionStateUseCase,
        observeDeviceLocation: ObserveDeviceLocationUseCase,
        getCurrentLocation: GetCurrentLocationUseCase
    ) {
        self.currentUserId = currentUserId
        self.observeMemberLocations = observeMemberLocations
        self.observeConnection = observeConnection
        self.observeDeviceLocation = observeDeviceLocation
        self.getCurrentLocation = getCurrentLocation
        self.connectionState = observeConnection.current
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    var isConnected: Bool { connectionState == .connected }

    func start() {
        guard tasks.isEmpty else { return }
        let locations = observeMemberLocations()
        let connection = observeConnection()
        let device = observeDeviceLocation()

        tasks.append(Task { [weak self] in
            for await location in locations { self?.upsert(location) }
        })
        tasks.append(Task { [weak self] in
            for await state in connection { self?.connectionState = state }
        })
        tasks.append(Task { [weak self] in
            for await point in device where self?.isTrackingUser == true {
                self?.center(on: point)
            }
        })
        connectionState = observeConnection.current
    }

    func centerOnUser() {
        guard let point = getCurrentLocation() else { return }
        isTrackingUser = true
        center(on: point)
    }

    func centerOnMember(_ member: MemberLocation) {
        isTrackingUser = false
        center(on: member.point)
    }

    func focus(on point: GeoPoint) {
        isTrackingUser = false
        center(on: point)
    }

    private func center(on point: GeoPoint) {
        mapRegion = MKCoordinateRegion(center: point.coordinate, delta: 0.01)
    }

    private func upsert(_ location: MemberLocation) {
        if let index = memberLocations.firstIndex(where: { $0.id == location.id }) {
            memberLocations[index] = location
        } else {
            memberLocations.append(location)
        }
    }
}
