@MainActor
protocol RouteConnectivity: AnyObject {
    var isOnline: Bool { get }
    var onChange: ((Bool) -> Void)? { get set }
    func start()
    func stop()
}
