import SwiftUI

@MainActor
final class CirclesCoordinator: ObservableObject {
    enum Sheet: Identifiable {
        case create
        case join
        case detail(FamilyGroup)

        var id: String {
            switch self {
            case .create: return "create"
            case .join: return "join"
            case .detail(let group): return "detail_\(group.id)"
            }
        }
    }

    @Published var sheet: Sheet?

    let viewModel: CircleListViewModel
    var onOpenConversation: ((_ conversationId: String, _ title: String) -> Void)?

    init(container: AppContainer) {
        viewModel = CircleListViewModel(
            fetchMyCircles: container.fetchMyCircles,
            createCircle: container.createCircle,
            joinCircle: container.joinCircle,
            fetchMembers: container.fetchCircleMembers,
            observePresence: container.observePresence
        )
    }

    func showCreate() { sheet = .create }
    func showJoin() { sheet = .join }

    func showDetail(of group: FamilyGroup) {
        sheet = .detail(group)
        Task { await viewModel.loadMembers(for: group) }
    }

    func dismissSheet() {
        sheet = nil
    }

    func openChat(for group: FamilyGroup) {
        guard let conversationId = group.conversationId else { return }
        sheet = nil
        onOpenConversation?(conversationId, group.name)
    }
}

struct CirclesCoordinatorView: View {
    @ObservedObject var coordinator: CirclesCoordinator

    var body: some View {
        NavigationStack {
            CircleListView(
                viewModel: coordinator.viewModel,
                onCreate: coordinator.showCreate,
                onJoin: coordinator.showJoin,
                onSelect: coordinator.showDetail(of:)
            )
        }
        .sheet(item: $coordinator.sheet) { sheet in
            switch sheet {
            case .create:
                CreateGroupSheet(viewModel: coordinator.viewModel, onClose: coordinator.dismissSheet)
            case .join:
                JoinGroupSheet(viewModel: coordinator.viewModel, onClose: coordinator.dismissSheet)
            case .detail(let group):
                GroupDetailView(
                    group: group,
                    viewModel: coordinator.viewModel,
                    onOpenChat: group.conversationId == nil ? nil : { coordinator.openChat(for: group) },
                    onClose: coordinator.dismissSheet
                )
            }
        }
    }
}
