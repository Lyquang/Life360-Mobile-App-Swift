import Foundation

extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            name: name,
            email: email ?? "",
            avatar: avatar,
            batteryLevel: batteryLevel.map { Int($0) },
            isOnline: isOnline,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension AuthDataDTO {
    func toDomain() throws -> AuthSession {
        guard let token = token ?? accessToken else { throw APIError.serverError("Thiếu token đăng nhập.") }
        return AuthSession(user: user.toDomain(), token: token)
    }
}

extension GroupDTO {
    func toDomain() -> FamilyGroup {
        FamilyGroup(
            id: id,
            name: name,
            inviteCode: inviteCode,
            admin: admin?.user?.toDomain(),
            members: members?.compactMap { $0.user?.toDomain() },
            conversationId: conversationId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension PlaceDTO {
    func toDomain() -> FavoritePlace {
        FavoritePlace(
            id: id,
            groupId: groupId,
            name: name,
            category: PlaceCategory(rawValue: category) ?? .other,
            latitude: latitude,
            longitude: longitude,
            addedBy: addedBy?.user?.toDomain(),
            createdAt: createdAt
        )
    }
}

extension HistoryResponseDTO {
    func toDomain() -> LocationHistory {
        LocationHistory(
            date: date,
            entries: (data ?? []).map {
                LocationHistoryEntry(id: $0.id ?? $0.timestamp, latitude: $0.latitude, longitude: $0.longitude, timestamp: $0.timestamp)
            }
        )
    }
}

extension DayJourneyResponseDTO {
    func toDomain() -> DayJourney {
        DayJourney(date: date, summary: summary?.toDomain(), entries: (journey ?? []).compactMap { $0.toDomain() })
    }
}

extension DayJourneySummaryDTO {
    func toDomain() -> DayJourneySummary {
        DayJourneySummary(
            totalPoints: totalPoints ?? 0,
            stayPointCount: stayPointCount ?? 0,
            totalStayMinutes: totalStayMinutes ?? 0,
            totalStayFormatted: totalStayFormatted ?? "--",
            totalMovingMinutes: totalMovingMinutes ?? 0,
            totalMovingFormatted: totalMovingFormatted ?? "--",
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt
        )
    }
}

extension JourneyItemDTO {
    func toDomain() -> JourneyEntry? {
        let minutes = durationMinutes ?? 0
        let formatted = durationFormatted ?? "\(minutes) phút"

        switch type {
        case "stay":
            guard let latitude, let longitude, let arrivedAt, let leftAt else { return nil }
            return .stay(StayPoint(
                latitude: latitude, longitude: longitude, arrivedAt: arrivedAt, leftAt: leftAt,
                durationMinutes: minutes, durationFormatted: formatted, pointCount: pointCount ?? 0
            ))
        case "moving":
            guard let fromLatitude, let fromLongitude, let toLatitude, let toLongitude,
                  let startTime, let endTime else { return nil }
            return .moving(MovingSegment(
                fromLatitude: fromLatitude, fromLongitude: fromLongitude,
                toLatitude: toLatitude, toLongitude: toLongitude,
                startTime: startTime, endTime: endTime,
                durationMinutes: minutes, durationFormatted: formatted,
                path: (path ?? []).map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
            ))
        default:
            return nil
        }
    }
}
