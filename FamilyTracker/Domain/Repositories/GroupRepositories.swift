import Foundation

protocol CircleRepository {
    func fetchMyCircles() async throws -> [FamilyGroup]
    func createCircle(name: String) async throws -> FamilyGroup
    func joinCircle(inviteCode: String) async throws -> FamilyGroup
    func fetchMembers(circleId: String) async throws -> [User]
}

protocol PlaceRepository {
    func fetchPlaces(circleId: String) async throws -> [FavoritePlace]
    func addPlace(circleId: String, name: String, category: PlaceCategory, location: GeoPoint) async throws -> FavoritePlace
}

protocol HistoryRepository {
    func fetchTodayHistory(userId: String) async throws -> LocationHistory
    /// `date` format "yyyy-MM-dd"; nil means today.
    func fetchDayJourney(userId: String, date: String?) async throws -> DayJourney
}
