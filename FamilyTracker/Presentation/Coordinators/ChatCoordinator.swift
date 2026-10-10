import SwiftUI

@MainActor
final class ChatCoordinator: NavigationCoordinator {
    enum Route: Hashable {
        case conversation(id: String, title: String)
    }

    @Published var path = NavigationPath()

    let listViewModel: ConversationListViewModel
    private let container: AppContainer
    private let currentUser: User

    init(container: AppContainer, currentUser: User) {
        self.container = container
        self.currentUser = currentUser
        listViewModel = ConversationListViewModel(
            currentUserId: currentUser.id,
            fetchConversations: container.fetchConversations,
            observeNewMessages: container.observeNewMessages
        )
    }

    func openConversation(id: String, title: String) {
        popToRoot()
        push(.conversation(id: id, title: title))
    }

    func show(_ conversation: Conversation) {
        push(.conversation(id: conversation.id, title: conversation.displayName))
    }

    func didOpen(conversationId: String) {
        container.pushService.activeConversationId = conversationId
        listViewModel.activeConversationId = conversationId
        listViewModel.markRead(conversationId)
    }

    func didClose(conversationId: String) {
        if container.pushService.activeConversationId == conversationId {
            container.pushService.activeConversationId = nil
        }
        if listViewModel.activeConversationId == conversationId {
            listViewModel.activeConversationId = nil
        }
    }

    func makeChatViewModel(conversationId: String, title: String) -> ChatViewModel {
        ChatViewModel(
            conversationId: conversationId,
            title: title,
            currentUserId: currentUser.id,
            fetchMessages: container.fetchMessages,
            sendText: container.sendTextMessage,
            sendImage: container.sendImageMessage,
            markRead: container.markConversationRead,
            observeNewMessages: container.observeNewMessages,
            observeTyping: container.observeTyping,
            sendTyping: container.sendTyping
        )
    }
}

struct ChatCoordinatorView: View {
    @ObservedObject var coordinator: ChatCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ConversationListView(viewModel: coordinator.listViewModel, onSelect: coordinator.show)
                .navigationDestination(for: ChatCoordinator.Route.self) { route in
                    switch route {
                    case let .conversation(id, title):
                        ChatView(viewModel: coordinator.makeChatViewModel(conversationId: id, title: title))
                            .onAppear { coordinator.didOpen(conversationId: id) }
                            .onDisappear { coordinator.didClose(conversationId: id) }
                    }
                }
        }
    }
}
