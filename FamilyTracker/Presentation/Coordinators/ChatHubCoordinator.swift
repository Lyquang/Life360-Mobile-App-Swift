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
final class ChatHubCoordinator: NavigationCoordinator {
    enum Route: Hashable {
        case conversation(id: String, title: String, emptyGreetingName: String?, groupId: String?)
    }

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

    @Published var path = NavigationPath()
    @Published var sheet: Sheet?
    @Published private(set) var openingPersonID: String?
    @Published var directErrorMessage: String?

    let viewModel: ChatHubViewModel
    let circleViewModel: CircleListViewModel
    let currentUserId: String

    private let container: AppContainer
    private var openDirectTask: Task<Void, Never>?
    private var membersTask: Task<Void, Never>?
    private var pendingRoute: Route?
    private var directRouteStore = DirectChatSheetRouteStore()

    init(container: AppContainer, currentUser: User) {
        self.container = container
        currentUserId = currentUser.id
        viewModel = ChatHubViewModel(
            currentUserId: currentUser.id,
            fetchGroups: container.fetchMyCircles,
            fetchConversations: container.fetchConversations,
            fetchUnreadSummary: container.fetchUnreadSummary,
            observeNewMessages: container.observeNewMessages,
            observeConversationUpdates: container.observeConversationUpdates,
            observePresence: container.observePresence,
            markConversationRead: container.markConversationRead
        )
        circleViewModel = CircleListViewModel(
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
        membersTask?.cancel()
    }

    func openConversation(id: String, title: String) {
        popToRoot()
        push(.conversation(id: id, title: title, emptyGreetingName: nil,
                           groupId: groupID(for: id)))
    }

    func open(_ item: ChatHubItem) {
        guard let id = item.conversationId else { return }
        let greeting = item.kind == .direct ? item.title : nil
        push(.conversation(id: id, title: item.title, emptyGreetingName: greeting,
                           groupId: item.groupId))
    }

    func openDirectConversation(_ conversation: Conversation, fallbackTitle: String) {
        viewModel.upsert(conversation)
        let name = conversation.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? fallbackTitle : name
        popToRoot()
        push(.conversation(id: conversation.id, title: title, emptyGreetingName: title,
                           groupId: nil))
    }

    func openPerson(_ person: ChatHubPerson) {
        guard openingPersonID == nil, person.id != currentUserId else { return }
        openingPersonID = person.id
        let operation = container.openDirectChat
        openDirectTask = Task { [weak self] in
            do {
                let conversation = try await operation(userId: person.id)
                guard !Task.isCancelled, let self else { return }
                self.openingPersonID = nil
                self.openDirectTask = nil
                self.openDirectConversation(conversation, fallbackTitle: person.name)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.openingPersonID = nil
                self.openDirectTask = nil
                self.directErrorMessage = L10n.message(error.localizedDescription)
            }
        }
    }

    func showCreate() { sheet = .create }
    func showJoin() { sheet = .join }

    func showGroupInfo(_ item: ChatHubItem) {
        guard let groupId = item.groupId, let group = viewModel.group(id: groupId) else { return }
        showDetail(group)
    }

    func showGroupInfo(conversationID: String) {
        guard let item = viewModel.snapshot.items.first(where: { $0.conversationId == conversationID }) else { return }
        showGroupInfo(item)
    }

    func showDetail(_ group: FamilyGroup) {
        sheet = .detail(group)
        loadMembers(for: group)
    }

    func loadMembers(for group: FamilyGroup) {
        membersTask?.cancel()
        membersTask = Task { [weak circleViewModel] in
            await circleViewModel?.loadMembers(for: group)
        }
    }

    func dismissSheet() { sheet = nil }

    func openGroupChat(_ group: FamilyGroup) {
        guard let id = group.conversationId else { return }
        pendingRoute = .conversation(id: id, title: group.name,
                                     emptyGreetingName: nil, groupId: group.id)
        sheet = nil
    }

    func openDirectChat(with member: User) {
        guard member.id != currentUserId, openDirectTask == nil else { return }
        startSheetDirectTask { viewModel in await viewModel.openDirectChat(with: member) }
    }

    func retryDirectChat() {
        guard openDirectTask == nil else { return }
        startSheetDirectTask { viewModel in await viewModel.retryDirectChat() }
    }

    func didDismissSheet() {
        membersTask?.cancel()
        membersTask = nil
        circleViewModel.clearMembers()

        for group in circleViewModel.groups where viewModel.group(id: group.id) == nil {
            viewModel.upsert(group)
        }

        if let route = directRouteStore.consume() {
            openDirectTask = nil
            openDirectConversation(route.conversation, fallbackTitle: route.fallbackTitle)
            return
        }
        if let route = pendingRoute {
            pendingRoute = nil
            popToRoot()
            push(route)
            return
        }

        directRouteStore.discard()
        openDirectTask?.cancel()
        openDirectTask = nil
        circleViewModel.cancelDirectChatOpening()
    }

    func didOpen(_ id: String) { viewModel.didOpenConversation(id) }
    func didClose(_ id: String) { viewModel.didCloseConversation(id) }

    func stop() {
        openDirectTask?.cancel()
        openDirectTask = nil
        membersTask?.cancel()
        membersTask = nil
        openingPersonID = nil
        directRouteStore.discard()
        pendingRoute = nil
        viewModel.stop()
    }

    func makeChatViewModel(id: String, title: String, greeting: String?) -> ChatViewModel {
        ChatViewModel(
            conversationId: id, title: title, emptyGreetingName: greeting,
            currentUserId: currentUserId, fetchMessages: container.fetchMessages,
            sendText: container.sendTextMessage, prepareImage: container.prepareImage,
            uploadImage: container.uploadImage, sendImage: container.sendImageMessage,
            uploadVoice: container.uploadVoice, sendVoice: container.sendVoiceMessage,
            markRead: container.markConversationRead, observeNewMessages: container.observeNewMessages,
            observeTyping: container.observeTyping, sendTyping: container.sendTyping,
            recorder: AudioRecorderService(), onForbidden: { [weak self] in self?.popToRoot() }
        )
    }

    private func groupID(for conversationID: String) -> String? {
        viewModel.snapshot.items.first { $0.conversationId == conversationID }?.groupId
    }

    private func startSheetDirectTask(
        _ operation: @escaping @MainActor (CircleListViewModel) async -> CircleListViewModel.DirectChatRoute?
    ) {
        openDirectTask = Task { [weak self, weak circleViewModel] in
            guard let circleViewModel else { return }
            let route = await operation(circleViewModel)
            guard !Task.isCancelled, let self else { return }
            self.openDirectTask = nil
            guard let route, self.sheet != nil else { return }
            self.directRouteStore.stage(route)
            self.sheet = nil
        }
    }
}

struct ChatHubCoordinatorView: View {
    @ObservedObject var coordinator: ChatHubCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ChatHubView(
                viewModel: coordinator.viewModel,
                openingPersonID: coordinator.openingPersonID,
                onOpenChat: coordinator.open,
                onGroupInfo: coordinator.showGroupInfo,
                onOpenPerson: coordinator.openPerson,
                onCreateGroup: coordinator.showCreate,
                onJoinGroup: coordinator.showJoin,
                onCopyInvite: { UIPasteboard.general.string = $0 }
            )
            .navigationDestination(for: ChatHubCoordinator.Route.self) { route in
                switch route {
                case let .conversation(id, title, greeting, groupId):
                    ChatView(viewModel: coordinator.makeChatViewModel(id: id, title: title, greeting: greeting),
                             onShowGroupInfo: groupId == nil ? nil : {
                                 coordinator.showGroupInfo(conversationID: id)
                             })
                        .onAppear { coordinator.didOpen(id) }
                        .onDisappear { coordinator.didClose(id) }
                }
            }
        }
        .sheet(item: $coordinator.sheet, onDismiss: coordinator.didDismissSheet) { sheet in
            switch sheet {
            case .create:
                CreateGroupSheet(viewModel: coordinator.circleViewModel, onClose: coordinator.dismissSheet)
            case .join:
                JoinGroupSheet(viewModel: coordinator.circleViewModel, onClose: coordinator.dismissSheet)
            case .detail(let group):
                GroupDetailView(
                    group: group, viewModel: coordinator.circleViewModel,
                    currentUserId: coordinator.currentUserId,
                    onOpenChat: group.conversationId == nil ? nil : {
                        coordinator.openGroupChat(group)
                    },
                    onMessageMember: coordinator.openDirectChat(with:),
                    onRetryMembers: { coordinator.loadMembers(for: group) },
                    onRetryDirectChat: coordinator.retryDirectChat,
                    onClose: coordinator.dismissSheet
                )
            }
        }
        .ftErrorAlert($coordinator.directErrorMessage)
    }
}
