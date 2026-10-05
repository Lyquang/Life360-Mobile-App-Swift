import SwiftUI

/// "Lộ trình" tab: member picker → journey / today's history.
@MainActor
final class TimelineCoordinator: NavigationCoordinator {
    enum Route: Hashable {
        case journey(userId: String, name: String)
        case history
    }

    @Published var path = NavigationPath()

    let pickerViewModel: MemberPickerViewModel
    private let container: AppContainer
    private let currentUser: User

    init(container: AppContainer, currentUser: User) {
        self.container = container
        self.currentUser = currentUser
        pickerViewModel = MemberPickerViewModel(
            currentUser: currentUser,
            fetchMyCircles: container.fetchMyCircles,
            fetchMembers: container.fetchCircleMembers
        )
    }

    func showJourney(userId: String, name: String) {
        push(.journey(userId: userId, name: name))
    }

    func showHistory() {
        push(.history)
    }

    func makeJourneyViewModel(userId: String, name: String) -> JourneyViewModel {
        JourneyViewModel(userId: userId, memberName: name,
                         fetchDayJourney: container.fetchDayJourney, reverseGeocode: container.reverseGeocode)
    }

    func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(userId: currentUser.id, fetchHistory: container.fetchLocationHistory)
    }
}

struct TimelineCoordinatorView: View {
    @ObservedObject var coordinator: TimelineCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            MemberPickerView(
                viewModel: coordinator.pickerViewModel,
                onSelectMember: coordinator.showJourney(userId:name:),
                onShowHistory: coordinator.showHistory
            )
            .navigationDestination(for: TimelineCoordinator.Route.self) { route in
                switch route {
                case let .journey(userId, name):
                    JourneyView(viewModel: coordinator.makeJourneyViewModel(userId: userId, name: name))
                case .history:
                    HistoryView(viewModel: coordinator.makeHistoryViewModel()) {
                        coordinator.showJourney(userId: coordinator.pickerViewModel.currentUser.id,
                                                name: coordinator.pickerViewModel.currentUser.name)
                    }
                }
            }
        }
    }
}
