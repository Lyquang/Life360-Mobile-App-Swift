import Foundation

struct ObserveSOSAlertsUseCase {
    let repository: SOSRepository
    func callAsFunction() -> AsyncStream<SOSAlert> { repository.observeSOSAlerts() }
}
