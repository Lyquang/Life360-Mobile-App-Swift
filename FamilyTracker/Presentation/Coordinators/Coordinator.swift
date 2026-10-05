import SwiftUI

/// Coordinators own navigation state; views only report user intent.
@MainActor
protocol NavigationCoordinator: ObservableObject {
    associatedtype Route: Hashable
    var path: NavigationPath { get set }
}

extension NavigationCoordinator {
    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
