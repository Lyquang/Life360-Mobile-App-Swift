import Foundation

struct FetchMyCirclesUseCase {
    let repository: CircleRepository

    func callAsFunction() async throws -> [FamilyGroup] {
        try await repository.fetchMyCircles()
    }
}

struct CreateCircleUseCase {
    let repository: CircleRepository

    func callAsFunction(name: String) async throws -> FamilyGroup {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw DomainError.validation("Vui lòng nhập tên nhóm.") }
        return try await repository.createCircle(name: trimmed)
    }
}

struct JoinCircleUseCase {
    let repository: CircleRepository

    func callAsFunction(inviteCode: String) async throws -> FamilyGroup {
        let code = inviteCode.trimmingCharacters(in: .whitespaces)
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            throw DomainError.validation("Mã mời phải gồm đúng 6 chữ số.")
        }
        return try await repository.joinCircle(inviteCode: code)
    }
}

struct FetchCircleMembersUseCase {
    let repository: CircleRepository

    func callAsFunction(circleId: String) async throws -> [User] {
        try await repository.fetchMembers(circleId: circleId)
    }
}
