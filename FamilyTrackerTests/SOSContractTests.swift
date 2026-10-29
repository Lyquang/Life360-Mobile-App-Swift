import Foundation
import XCTest
@testable import FamilyTracker

final class SOSContractTests: XCTestCase {
    private let id = "000000000000000000000001"

    func testCreationPayloadIsStrictAndRetryKeepsUUID() throws {
        let uuid = UUID()
        let intent = SOSCreationIntent(clientRequestId: uuid, message: " Help ", location: nil)
        let first = try body(SOSEndpoint.create(intent))
        let retry = try body(SOSEndpoint.create(intent))
        XCTAssertEqual(first["clientRequestId"] as? String, uuid.uuidString.lowercased())
        XCTAssertEqual(first["clientRequestId"] as? String, retry["clientRequestId"] as? String)
        XCTAssertEqual(first["message"] as? String, "Help")
        XCTAssertEqual(Set(first.keys), ["clientRequestId", "message"])

        let time = try XCTUnwrap(ISO8601.date(from: "2026-10-29T10:00:00.123Z"))
        let located = SOSCreationIntent(clientRequestId: uuid, message: nil,
                                        location: SOSLocation(latitude: 10.77, longitude: 106.69, recordedAt: time))
        let payload = try body(SOSEndpoint.create(located))
        XCTAssertEqual(payload["recordedAt"] as? String, ISO8601.string(from: time))
        XCTAssertEqual(Set(payload.keys), ["clientRequestId", "latitude", "longitude", "recordedAt"])
    }

    func testEndpointMethodsAndDistinctPagination() throws {
        let list = try SOSEndpoint.list(status: .all, limit: 100, cursor: id)
        let detail = try SOSEndpoint.detail(id: id, limit: 1, afterId: id)
        XCTAssertEqual(list.path, "/sos")
        XCTAssertEqual(list.method, .GET)
        XCTAssertTrue(list.requiresAuth)
        XCTAssertEqual(Set(list.query.map(\.name)), ["status", "limit", "cursor"])
        XCTAssertEqual(Set(detail.query.map(\.name)), ["limit", "afterId"])
        XCTAssertEqual(try SOSEndpoint.respond(id: id).method, .POST)
        XCTAssertEqual(try body(SOSEndpoint.respond(id: id))["status"] as? String, "coming")
        XCTAssertEqual(try SOSEndpoint.close(id: id, status: .resolved).method, .PATCH)
        XCTAssertEqual(try body(SOSEndpoint.close(id: id, status: .cancelled))["status"] as? String, "cancelled")
        XCTAssertThrowsError(try SOSEndpoint.detail(id: "../auth", limit: 50, afterId: nil))
        XCTAssertThrowsError(try SOSEndpoint.list(status: .active, limit: 101, cursor: nil))
        XCTAssertThrowsError(try SOSEndpoint.list(status: .active, limit: 50, cursor: "invalid"))
    }

    func testRejectsInvalidGPSAndBackendUTF16MessageLimit() throws {
        let invalid = SOSCreationIntent(clientRequestId: UUID(), message: nil,
                                        location: SOSLocation(latitude: .nan, longitude: 0, recordedAt: nil))
        XCTAssertThrowsError(try SOSEndpoint.create(invalid))
        let long = SOSCreationIntent(clientRequestId: UUID(), message: String(repeating: "😀", count: 251), location: nil)
        XCTAssertThrowsError(try SOSEndpoint.create(long))
    }

    func testSummaryDoesNotRequireDetailFieldsAndUnknownStatusIsNotActive() throws {
        let data = Data("""
        {"id":"\(id)","ownerId":"000000000000000000000002","status":"future_status",
         "revision":1,"groupCount":2,"recipientCount":3,"createdAt":"2026-10-29T10:00:00Z"}
        """.utf8)
        let summary = try BackendJSONCoding.makeDecoder().decode(SOSSummaryDTO.self, from: data).toDomain()
        XCTAssertEqual(summary.status, .unknown)
        XCTAssertNil(summary.closedAt)
        XCTAssertThrowsError(try BackendJSONCoding.makeDecoder().decode(SOSIncidentDTO.self, from: data))
    }

    func testNullableDetailAndMissingPaginationCursor() throws {
        let json = """
        {"incident":{"id":"\(id)","ownerId":"000000000000000000000002","status":"active",
        "revision":2,"message":"Help","location":null,"groupIds":[],
        "createdAt":"2026-10-29T10:00:00.123Z","closedAt":null},
        "responders":[{"id":"000000000000000000000004","responderId":"000000000000000000000005",
        "name":null,"avatar":null,"status":"coming","respondedAt":"2026-10-29T10:01:00Z"}],
        "hasMore":false,"nextAfterId":null}
        """
        let decoder = BackendJSONCoding.makeDecoder()
        let detail = try decoder.decode(SOSDetailDTO.self, from: Data(json.utf8)).toDomain()
        XCTAssertNil(detail.incident.location)
        XCTAssertNil(detail.responders.first?.name)
        XCTAssertEqual(detail.incident.createdAt, ISO8601.date(from: "2026-10-29T10:00:00.123Z"))
        let broken = json.replacingOccurrences(of: "\"hasMore\":false", with: "\"hasMore\":true")
        XCTAssertThrowsError(try decoder.decode(SOSDetailDTO.self, from: Data(broken.utf8)).toDomain())
    }

    private func body(_ endpoint: Endpoint) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(endpoint.encodedBody())) as? [String: Any])
    }
}
