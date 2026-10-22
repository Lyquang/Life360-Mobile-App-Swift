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
        guard let accessToken, let refreshToken, let expiresIn,
              !accessToken.isEmpty, !refreshToken.isEmpty, expiresIn > 0 else {
            throw APIError.decodingError("Thiếu cặp token đăng nhập.")
        }
        return AuthSession(user: user.toDomain(), tokens: AuthTokens(
            accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn
        ))
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
        let entries = (journey ?? []).compactMap { $0.toDomain() }
        return DayJourney(date: date, summary: summary?.toDomain(entries: entries), entries: entries)
    }
}

extension DayJourneySummaryDTO {
    func toDomain(entries: [JourneyEntry]) -> DayJourneySummary {
        let stayMinutes = entries.reduce(0) { total, entry in
            if case .stay(let stay) = entry { return total + stay.durationMinutes }
            return total
        }
        let movingMinutes = entries.reduce(0) { total, entry in
            if case .moving(let moving) = entry { return total + moving.durationMinutes }
            return total
        }
        let firstTime: String? = entries.first.map { entry in
            switch entry {
            case .stay(let stay): return stay.arrivedAt
            case .moving(let moving): return moving.startTime
            }
        }
        let lastTime: String? = entries.last.map { entry in
            switch entry {
            case .stay(let stay): return stay.leftAt
            case .moving(let moving): return moving.endTime
            }
        }
        return DayJourneySummary(
            totalPoints: totalPoints ?? 0,
            stayPointCount: stayPointCount ?? 0,
            totalStayMinutes: totalStayMinutes ?? stayMinutes,
            totalStayFormatted: totalStayFormatted ?? "--",
            totalMovingMinutes: totalMovingMinutes ?? movingMinutes,
            totalMovingFormatted: totalMovingFormatted ?? "--",
            firstSeenAt: firstSeenAt ?? firstTime,
            lastSeenAt: lastSeenAt ?? lastTime
        )
    }
}

extension JourneyItemDTO {
    func toDomain() -> JourneyEntry? {
        let start = startTime ?? arrivedAt
        let end = endTime ?? leftAt
        let measuredMinutes: Int? = {
            guard let start, let end,
                  let startDate = ISO8601.date(from: start),
                  let endDate = ISO8601.date(from: end) else { return nil }
            return max(0, Int(endDate.timeIntervalSince(startDate) / 60))
        }()
        let minutes = durationMinutes ?? measuredMinutes ?? 0
        let formatted = durationFormatted ?? String(minutes)

        switch type {
        case "stay":
            guard let latitude, let longitude, let start, let end else { return nil }
            return .stay(StayPoint(
                latitude: latitude, longitude: longitude, arrivedAt: start, leftAt: end,
                durationMinutes: minutes, durationFormatted: formatted,
                pointCount: pointCount ?? points?.count ?? 0
            ))
        case "moving":
            guard let start, let end else { return nil }
            let route = !(path ?? []).isEmpty
                ? (path ?? []).map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
                : (points ?? []).map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
            guard let fromLatitude = fromLatitude ?? route.first?.latitude,
                  let fromLongitude = fromLongitude ?? route.first?.longitude,
                  let toLatitude = toLatitude ?? route.last?.latitude,
                  let toLongitude = toLongitude ?? route.last?.longitude else { return nil }
            return .moving(MovingSegment(
                fromLatitude: fromLatitude, fromLongitude: fromLongitude,
                toLatitude: toLatitude, toLongitude: toLongitude,
                startTime: start, endTime: end,
                durationMinutes: minutes, durationFormatted: formatted,
                path: route
            ))
        default:
            return nil
        }
    }
}
