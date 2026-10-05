import Foundation

@MainActor
final class CircleListViewModel: ObservableObject {
    @Published private(set) var groups: [FamilyGroup] = []
    @Published private(set) var members: [User] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isMembersLoading = false
    /// Form errors shown inline in create/join sheets.
    @Published var errorMessage: String?
    /// Loading errors shown as an alert on the list.
    @Published var loadErrorMessage: String?
    @Published var successMessage: String?

    private let fetchMyCircles: FetchMyCirclesUseCase
    private let createCircle: CreateCircleUseCase
    private let joinCircle: JoinCircleUseCase
    private let fetchMembers: FetchCircleMembersUseCase
    private let observePresence: ObservePresenceUseCase
    private var presenceTask: Task<Void, Never>?

    init(
        fetchMyCircles: FetchMyCirclesUseCase,
        createCircle: CreateCircleUseCase,
        joinCircle: JoinCircleUseCase,
        fetchMembers: FetchCircleMembersUseCase,
        observePresence: ObservePresenceUseCase
    ) {
        self.fetchMyCircles = fetchMyCircles
        self.createCircle = createCircle
        self.joinCircle = joinCircle
        self.fetchMembers = fetchMembers
        self.observePresence = observePresence
    }

    deinit {
        presenceTask?.cancel()
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
        isLoading = true
        loadErrorMessage = nil
        defer { isLoading = false }
        do {
            groups = try await fetchMyCircles()
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    /// Returns true on success so the sheet can dismiss itself.
    func createGroup(name: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let group = try await createCircle(name: name)
            groups.insert(group, at: 0)
            successMessage = "Tạo nhóm '\(group.name)' thành công! Mã mời: \(group.inviteCode ?? "")"
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
            successMessage = "Tham gia nhóm '\(group.name)' thành công!"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loadMembers(for group: FamilyGroup) async {
        isMembersLoading = true
        defer { isMembersLoading = false }
        do {
            members = try await fetchMembers(circleId: group.id)
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func updateMemberStatus(userId: String, isOnline: Bool) {
        guard let index = members.firstIndex(where: { $0.id == userId }) else { return }
        members[index].isOnline = isOnline
    }
}
