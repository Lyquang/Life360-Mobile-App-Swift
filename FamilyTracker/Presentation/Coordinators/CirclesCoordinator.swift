import SwiftUI
import UIKit

struct DirectChatSheetRouteStore {
    private var pending: CircleListViewModel.DirectChatRoute?

    mutating func stage(_ route: CircleListViewModel.DirectChatRoute) {
        pending = route
    }

    mutating func consume() -> CircleListViewModel.DirectChatRoute? {
        defer { pending = nil }
        return pending
    }

    mutating func discard() {
        pending = nil
    }
}

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
    let currentUserId: String
    var onOpenConversation: ((_ conversationId: String, _ title: String) -> Void)?
    var onOpenDirectConversation: ((_ conversation: Conversation, _ fallbackTitle: String) -> Void)?

    private var openDirectTask: Task<Void, Never>?
    private var directRouteStore = DirectChatSheetRouteStore()

    init(container: AppContainer, currentUser: User) {
        currentUserId = currentUser.id
        viewModel = CircleListViewModel(
            fetchMyCircles: container.fetchMyCircles,
            createCircle: container.createCircle,
            joinCircle: container.joinCircle,
            fetchMembers: container.fetchCircleMembers,
            observePresence: container.observePresence,
            openDirectChat: container.openDirectChat
        )
    }

    deinit {
        openDirectTask?.cancel()
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

    func openDirectChat(with member: User) {
        guard member.id != currentUserId, openDirectTask == nil else { return }
        startDirectChatTask { viewModel in
            await viewModel.openDirectChat(with: member)
        }
    }

    func retryDirectChat() {
        guard openDirectTask == nil else { return }
        startDirectChatTask { viewModel in
            await viewModel.retryDirectChat()
        }
    }

    func didDismissSheet() {
        if let route = directRouteStore.consume() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpenDirectConversation?(route.conversation, route.fallbackTitle)
            return
        }

        directRouteStore.discard()
        openDirectTask?.cancel()
        openDirectTask = nil
        viewModel.cancelDirectChatOpening()
    }

    private func startDirectChatTask(
        operation: @escaping @MainActor (CircleListViewModel) async -> CircleListViewModel.DirectChatRoute?
    ) {
        openDirectTask = Task { [weak self, weak viewModel] in
            guard let viewModel else { return }
            let route = await operation(viewModel)
            guard !Task.isCancelled, let self else { return }
            self.openDirectTask = nil
            guard let route else {
                if viewModel.directChatFailure != nil {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                return
            }
            self.directRouteStore.stage(route)
            self.sheet = nil
        }
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
        .sheet(item: $coordinator.sheet, onDismiss: coordinator.didDismissSheet) { sheet in
            switch sheet {
            case .create:
                CreateGroupSheet(viewModel: coordinator.viewModel, onClose: coordinator.dismissSheet)
            case .join:
                JoinGroupSheet(viewModel: coordinator.viewModel, onClose: coordinator.dismissSheet)
            case .detail(let group):
                GroupDetailView(
                    group: group,
                    viewModel: coordinator.viewModel,
                    currentUserId: coordinator.currentUserId,
                    onOpenChat: group.conversationId == nil ? nil : { coordinator.openChat(for: group) },
                    onMessageMember: coordinator.openDirectChat(with:),
                    onRetryDirectChat: coordinator.retryDirectChat,
                    onClose: coordinator.dismissSheet
                )
            }
        }
    }
}
