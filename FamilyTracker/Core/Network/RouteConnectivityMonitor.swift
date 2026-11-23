import Foundation
import Network

@MainActor
final class RouteConnectivityMonitor: RouteConnectivity {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "familytracker.route.connectivity")
    private var generation = 0
    private(set) var isOnline = true
    var onChange: ((Bool) -> Void)?

    func start() {
        guard monitor == nil else { return }
        generation += 1
        let startedGeneration = generation
        let next = NWPathMonitor()
        next.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self, self.generation == startedGeneration else { return }
                self.isOnline = online
                self.onChange?(online)
            }
        }
        monitor = next
        next.start(queue: queue)
    }

    func stop() {
        generation += 1
        monitor?.cancel()
        monitor = nil
        onChange = nil
    }
}
