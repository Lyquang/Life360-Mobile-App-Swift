import Foundation

final class AuthRepositoryImpl: AuthRepository {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func login(email: String, password: String) async throws -> AuthSession {
        try await withDomainErrors {
            try await api.send(AuthEndpoint.login(email: email, password: password), as: APIResponseDTO<AuthDataDTO>.self)
                .unwrap(fallbackMessage: "Đăng nhập thất bại.")
                .toDomain()
        }
    }

    func register(name: String, email: String, password: String) async throws -> AuthSession {
        try await withDomainErrors {
            try await api.send(AuthEndpoint.register(name: name, email: email, password: password), as: APIResponseDTO<AuthDataDTO>.self)
                .unwrap(fallbackMessage: "Đăng ký thất bại.")
                .toDomain()
        }
    }

    func fetchCurrentUser() async throws -> User {
        try await withDomainErrors {
            try await api.send(AuthEndpoint.me, as: APIResponseDTO<UserDTO>.self)
                .unwrap(fallbackMessage: "Không thể tải thông tin tài khoản.")
                .toDomain()
        }
    }
}

final class CircleRepositoryImpl: CircleRepository {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func fetchMyCircles() async throws -> [FamilyGroup] {
        try await withDomainErrors {
            let response = try await api.send(GroupEndpoint.list, as: APIResponseDTO<[GroupDTO]>.self)
            guard response.success else { throw APIError.serverError(response.message ?? "Không thể tải danh sách nhóm.") }
            return (response.data ?? []).map { $0.toDomain() }
        }
    }

    func createCircle(name: String) async throws -> FamilyGroup {
        try await withDomainErrors {
            try await api.send(GroupEndpoint.create(name: name), as: APIResponseDTO<GroupDTO>.self)
                .unwrap(fallbackMessage: "Tạo nhóm thất bại.")
                .toDomain()
        }
    }

    func joinCircle(inviteCode: String) async throws -> FamilyGroup {
        try await withDomainErrors {
            try await api.send(GroupEndpoint.join(inviteCode: inviteCode), as: APIResponseDTO<GroupDTO>.self)
                .unwrap(fallbackMessage: "Mã mời không hợp lệ.")
                .toDomain()
        }
    }

    func fetchMembers(circleId: String) async throws -> [User] {
        try await withDomainErrors {
            try await api.send(GroupEndpoint.members(groupId: circleId), as: APIResponseDTO<GroupMembersDTO>.self)
                .unwrap(fallbackMessage: "Không thể tải thành viên.")
                .members.map { $0.toDomain() }
        }
    }
}

final class PlaceRepositoryImpl: PlaceRepository {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func fetchPlaces(circleId: String) async throws -> [FavoritePlace] {
        try await withDomainErrors {
            let response = try await api.send(PlaceEndpoint.list(groupId: circleId), as: APIResponseDTO<[PlaceDTO]>.self)
            guard response.success else { throw APIError.serverError(response.message ?? "Không thể tải địa điểm.") }
            return (response.data ?? []).map { $0.toDomain() }
        }
    }

    func addPlace(circleId: String, name: String, category: PlaceCategory, location: GeoPoint) async throws -> FavoritePlace {
        try await withDomainErrors {
            let endpoint = PlaceEndpoint.add(groupId: circleId, name: name, category: category.rawValue,
                                             latitude: location.latitude, longitude: location.longitude)
            return try await api.send(endpoint, as: APIResponseDTO<PlaceDTO>.self)
                .unwrap(fallbackMessage: "Thêm địa điểm thất bại.")
                .toDomain()
        }
    }
}

final class HistoryRepositoryImpl: HistoryRepository {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func fetchTodayHistory(userId: String) async throws -> LocationHistory {
        try await withDomainErrors {
            let response = try await api.send(HistoryEndpoint.today(userId: userId), as: HistoryResponseDTO.self)
            guard response.success else { throw APIError.serverError(response.message ?? "Không thể tải lịch sử vị trí.") }
            return response.toDomain()
        }
    }

    func fetchDayJourney(userId: String, date: String?) async throws -> DayJourney {
        try await withDomainErrors {
            let response = try await api.send(HistoryEndpoint.journey(userId: userId, date: date), as: DayJourneyResponseDTO.self)
            guard response.success else { throw APIError.serverError(response.message ?? "Không thể tải lộ trình.") }
            return response.toDomain()
        }
    }
}
