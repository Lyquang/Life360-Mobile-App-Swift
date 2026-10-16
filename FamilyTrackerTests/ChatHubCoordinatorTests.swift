import XCTest
@testable import FamilyTracker

@MainActor
final class ChatHubCoordinatorTests: XCTestCase {
    func testNotificationConversationOpensChatHubAndResetsPreviousRoute() {
        let coordinator = makeMainCoordinator()
        coordinator.openConversation(id: "first", title: "First")
        coordinator.handle(.conversation("second"))

        XCTAssertEqual(coordinator.selectedTab, .chatHub)
        XCTAssertEqual(coordinator.chatHub.path.count, 1)
    }

    func testGroupChatWaitsForSheetDismissAndRoutesOnce() {
        let coordinator = makeHubCoordinator()
        let group = FamilyGroup(id: "group", name: "Family", conversationId: "conversation")
        coordinator.sheet = .detail(group)

        coordinator.openGroupChat(group)
        XCTAssertEqual(coordinator.path.count, 0)

        coordinator.didDismissSheet()
        XCTAssertEqual(coordinator.path.count, 1)
        coordinator.didDismissSheet()
        XCTAssertEqual(coordinator.path.count, 1)
    }

    func testInteractiveSheetDismissDoesNotNavigate() {
        let coordinator = makeHubCoordinator()
        coordinator.sheet = .create
        coordinator.dismissSheet()
        coordinator.didDismissSheet()

        XCTAssertEqual(coordinator.path.count, 0)
    }

    private func makeHubCoordinator() -> ChatHubCoordinator {
        ChatHubCoordinator(container: AppContainer(environment: .local()),
                           currentUser: User(id: "me", name: "Me", email: "me@example.com"))
    }

    private func makeMainCoordinator() -> MainTabCoordinator {
        MainTabCoordinator(container: AppContainer(environment: .local()),
                           currentUser: User(id: "me", name: "Me", email: "me@example.com"),
                           onLogout: {}, onLogoutAll: {})
    }
}
