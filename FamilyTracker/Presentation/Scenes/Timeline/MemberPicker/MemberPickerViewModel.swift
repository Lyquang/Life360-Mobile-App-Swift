import Foundation

@MainActor
final class MemberPickerViewModel: ObservableObject {
    @Published private(set) var groups: [FamilyGroup] = []
    @Published private(set) var membersByGroup: [String: [User]] = [:]
    @Published private(set) var loadingGroupIds: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let currentUser: User

    private let fetchMyCircles: FetchMyCirclesUseCase
    private let fetchMembers: FetchCircleMembersUseCase

    init(currentUser: User, fetchMyCircles: FetchMyCirclesUseCase, fetchMembers: FetchCircleMembersUseCase) {
        self.currentUser = currentUser
        self.fetchMyCircles = fetchMyCircles
        self.fetchMembers = fetchMembers
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            groups = try await fetchMyCircles()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await withTaskGroup(of: Void.self) { group in
            for circle in groups {
                group.addTask { await self.loadMembers(of: circle) }
            }
        }
    }

    /// Members excluding the current user (shown separately as "me").
    func otherMembers(of group: FamilyGroup) -> [User] {
        (membersByGroup[group.id] ?? []).filter { $0.id != currentUser.id }
    }

    private func loadMembers(of group: FamilyGroup) async {
        loadingGroupIds.insert(group.id)
        defer { loadingGroupIds.remove(group.id) }
        membersByGroup[group.id] = (try? await fetchMembers(circleId: group.id)) ?? []
    }
}
