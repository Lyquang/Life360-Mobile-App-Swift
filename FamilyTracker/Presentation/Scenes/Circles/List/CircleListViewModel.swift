import Foundation

@MainActor
final class CircleListViewModel: ObservableObject {
    struct DirectChatRoute {
        let conversation: Conversation
        let fallbackTitle: String
    }

    struct DirectChatFailure: Identifiable, Equatable {
        let memberId: String
        let memberName: String
        let message: String

        var id: String { memberId }
    }

    @Published private(set) var groups: [FamilyGroup] = []
    @Published private(set) var members: [User] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isMembersLoading = false
    @Published private(set) var membersErrorMessage: String?
    /// Form errors shown inline in create/join sheets.
    @Published var errorMessage: String?
    /// Loading errors shown as an alert on the list.
    @Published var loadErrorMessage: String?
    @Published var successMessage: String?
    @Published private(set) var openingDirectMemberId: String?
    @Published var directChatFailure: DirectChatFailure?

    private let fetchMyCircles: FetchMyCirclesUseCase
    private let createCircle: CreateCircleUseCase
    private let joinCircle: JoinCircleUseCase
    private let fetchMembers: FetchCircleMembersUseCase
    private let observePresence: ObservePresenceUseCase
    private let openDirectChat: OpenDirectChatUseCase
    private var presenceTask: Task<Void, Never>?
    private var groupLoadTask: Task<Void, Never>?
    private var memberLoadGeneration = 0

    init(
        fetchMyCircles: FetchMyCirclesUseCase,
        createCircle: CreateCircleUseCase,
        joinCircle: JoinCircleUseCase,
        fetchMembers: FetchCircleMembersUseCase,
        observePresence: ObservePresenceUseCase,
        openDirectChat: OpenDirectChatUseCase
    ) {
        self.fetchMyCircles = fetchMyCircles
        self.createCircle = createCircle
        self.joinCircle = joinCircle
        self.fetchMembers = fetchMembers
        self.observePresence = observePresence
        self.openDirectChat = openDirectChat
    }

    deinit {
        presenceTask?.cancel()
        groupLoadTask?.cancel()
    }

    func startObservingPresence() {
        guard presenceTask == nil else { return }
        let stream = observePresence()
        presenceTask = Task { [weak self] in
            for await presence in stream {
                self?.updateMemberStatus(userId: presence.userId, isOnline: presence.isOnline)
            }
        }
    }

    func loadGroups() async {
        if let groupLoadTask {
            await groupLoadTask.value
            return
        }
        isLoading = true
        loadErrorMessage = nil
        let fetch = fetchMyCircles
        let task = Task { [weak self, fetch] in
            let result: Result<[FamilyGroup], Error>
            do { result = .success(try await fetch()) }
            catch { result = .failure(error) }
            guard let self else { return }
            switch result {
            case .success(let groups): self.groups = groups
            case .failure(let error) where !(error is CancellationError):
                self.loadErrorMessage = error.localizedDescription
            case .failure: break
            }
            self.isLoading = false
            self.groupLoadTask = nil
        }
        groupLoadTask = task
        await task.value
    }

    /// Returns true on success so the sheet can dismiss itself.
    func createGroup(name: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let group = try await createCircle(name: name)
            groups.insert(group, at: 0)
            successMessage = L10n.format("Tạo nhóm '%@' thành công! Mã mời: %@", group.name, group.inviteCode ?? "")
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func joinGroup(inviteCode: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let group = try await joinCircle(inviteCode: inviteCode)
            if !groups.contains(where: { $0.id == group.id }) {
                groups.insert(group, at: 0)
            }
            successMessage = L10n.format("Tham gia nhóm '%@' thành công!", group.name)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loadMembers(for group: FamilyGroup) async {
        memberLoadGeneration += 1
        let requestGeneration = memberLoadGeneration
        members = []
        membersErrorMessage = nil
        isMembersLoading = true
        do {
            let loaded = try await fetchMembers(circleId: group.id)
            if requestGeneration == memberLoadGeneration, !Task.isCancelled {
                members = loaded
            }
        } catch is CancellationError {
            // Closing the sheet cancels its request without showing an error.
        } catch {
            if requestGeneration == memberLoadGeneration, !Task.isCancelled {
                membersErrorMessage = error.localizedDescription
            }
        }
        if requestGeneration == memberLoadGeneration {
            isMembersLoading = false
        }
    }

    func clearMembers() {
        memberLoadGeneration += 1
        members = []
        membersErrorMessage = nil
        isMembersLoading = false
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    var isOpeningDirectChat: Bool { openingDirectMemberId != nil }

    func openDirectChat(with member: User) async -> DirectChatRoute? {
        guard openingDirectMemberId == nil else { return nil }
        return await performOpenDirectChat(memberId: member.id, memberName: member.name)
    }

    func retryDirectChat() async -> DirectChatRoute? {
        guard openingDirectMemberId == nil, let failure = directChatFailure else { return nil }
        return await performOpenDirectChat(memberId: failure.memberId, memberName: failure.memberName)
    }

    func cancelDirectChatOpening() {
        openingDirectMemberId = nil
    }

    private func performOpenDirectChat(memberId: String, memberName: String) async -> DirectChatRoute? {
        openingDirectMemberId = memberId
        directChatFailure = nil
        defer {
            if openingDirectMemberId == memberId {
                openingDirectMemberId = nil
            }
        }

        do {
            let conversation = try await openDirectChat(userId: memberId)
            guard !Task.isCancelled else { return nil }
            return DirectChatRoute(conversation: conversation, fallbackTitle: memberName)
        } catch {
            guard !Task.isCancelled else { return nil }
            directChatFailure = DirectChatFailure(
                memberId: memberId,
                memberName: memberName,
                message: Self.directChatMessage(for: error)
            )
            return nil
        }
    }

    private static func directChatMessage(for error: Error) -> String {
        switch error {
        case DomainError.forbidden:
            return L10n.text("Người này không còn trong nhóm.")
        case DomainError.network:
            return L10n.text("Không có kết nối mạng. Hãy thử lại.")
        case DomainError.unauthorized:
            return DomainError.unauthorized.localizedDescription
        default:
            return L10n.text("Có lỗi xảy ra. Hãy thử lại sau.")
        }
    }

    private func updateMemberStatus(userId: String, isOnline: Bool) {
        guard let index = members.firstIndex(where: { $0.id == userId }) else { return }
        members[index].isOnline = isOnline
    }
}
