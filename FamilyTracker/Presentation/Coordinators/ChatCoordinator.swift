import SwiftUI

@MainActor
final class ChatCoordinator: NavigationCoordinator {
    enum Route: Hashable {
        case conversation(id: String, title: String, emptyGreetingName: String?)
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
        push(.conversation(id: id, title: title, emptyGreetingName: nil))
    }

    func show(_ conversation: Conversation) {
        let title = conversation.displayName
        push(.conversation(
            id: conversation.id,
            title: title,
            emptyGreetingName: conversation.type == .direct ? title : nil
        ))
    }

    func openDirectConversation(_ conversation: Conversation, fallbackTitle: String) {
        listViewModel.upsert(conversation)
        listViewModel.refreshInBackground()
        let displayName = conversation.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = displayName.isEmpty ? fallbackTitle : displayName
        popToRoot()
        push(.conversation(id: conversation.id, title: title, emptyGreetingName: title))
    }

    func didOpen(conversationId: String) {
        listViewModel.activeConversationId = conversationId
        listViewModel.markRead(conversationId)
    }

    func didClose(conversationId: String) {
        if listViewModel.activeConversationId == conversationId {
            listViewModel.activeConversationId = nil
        }
    }

    func makeChatViewModel(
        conversationId: String,
        title: String,
        emptyGreetingName: String?
    ) -> ChatViewModel {
        ChatViewModel(
            conversationId: conversationId,
            title: title,
            emptyGreetingName: emptyGreetingName,
            currentUserId: currentUser.id,
            fetchMessages: container.fetchMessages,
            sendText: container.sendTextMessage,
            prepareImage: container.prepareImage,
            uploadImage: container.uploadImage,
            sendImage: container.sendImageMessage,
            uploadVoice: container.uploadVoice,
            sendVoice: container.sendVoiceMessage,
            markRead: container.markConversationRead,
            observeNewMessages: container.observeNewMessages,
            observeTyping: container.observeTyping,
            sendTyping: container.sendTyping,
            recorder: AudioRecorderService(),
            onForbidden: { [weak self] in self?.popToRoot() }
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
                    case let .conversation(id, title, emptyGreetingName):
                        ChatView(viewModel: coordinator.makeChatViewModel(
                            conversationId: id,
                            title: title,
                            emptyGreetingName: emptyGreetingName
                        ))
                            .onAppear { coordinator.didOpen(conversationId: id) }
                            .onDisappear { coordinator.didClose(conversationId: id) }
                    }
                }
        }
    }
}
