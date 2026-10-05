import Foundation

struct ObserveSOSAlertsUseCase {
    let repository: SOSRepository
    func callAsFunction() -> AsyncStream<SOSAlert> { repository.observeSOSAlerts() }
}

@MainActor
struct SendSOSUseCase {
    let repository: SOSRepository
    let deviceLocation: DeviceLocationRepository
    let deviceStatus: DeviceStatusRepository

    func callAsFunction(message: String = "Tôi cần giúp đỡ khẩn cấp!") {
        repository.sendSOS(
            message: message,
            location: deviceLocation.lastKnownLocation,
            batteryLevel: deviceStatus.batteryLevel
        )
    }
}
