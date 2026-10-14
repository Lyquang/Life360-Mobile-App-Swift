import Foundation

struct LocationBatchRequestDTO: Encodable {
    let points: [LocationBatchPointDTO]
}

struct LocationBatchPointDTO: Encodable {
    let pointId: UUID
    let latitude: Double
    let longitude: Double
    let recordedAt: String
    let accuracy: Double?
    let batteryLevel: Double?

    init(_ point: BufferedLocationPoint) {
        pointId = point.pointId
        latitude = point.latitude
        longitude = point.longitude
        recordedAt = ISO8601.string(from: point.recordedAt)
        accuracy = point.accuracy
        batteryLevel = point.batteryLevel
    }
}

struct LocationBatchResultDTO: Decodable {
    let accepted: [UUID]
    let duplicates: [UUID]
    let rejected: [LocationBatchRejectionDTO]

    func toDomain() -> LocationBatchResult {
        LocationBatchResult(accepted: accepted, duplicates: duplicates,
                            rejected: rejected.map {
                                LocationBatchRejection(index: $0.index, pointId: $0.pointId,
                                                       code: $0.code, reason: $0.reason)
                            })
    }
}

struct LocationBatchRejectionDTO: Decodable {
    let index: Int
    let pointId: UUID?
    let code: String
    let reason: String
}
