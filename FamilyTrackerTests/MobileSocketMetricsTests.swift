import Foundation
import XCTest
@testable import FamilyTracker

final class MobileSocketMetricsTests: XCTestCase {
    func testEventAllowlistAndPayloadEstimate() throws {
        XCTAssertEqual(SocketMetricsPolicy.event("chat:send_message"), .chatSendMessage)
        XCTAssertEqual(SocketMetricsPolicy.event("location_update"), .locationUpdate)
        XCTAssertNil(SocketMetricsPolicy.event("chat:private-user-id"))
        XCTAssertNil(SocketMetricsPolicy.event("unknown_event"))
        let payload: [String: Any] = ["content": "private message", "latitude": 10.2]
        let estimate = try XCTUnwrap(SocketMetricsPolicy.estimatedPayloadBytes(payload))
        XCTAssertEqual(estimate, try JSONSerialization.data(withJSONObject: payload).count)
        XCTAssertNil(SocketMetricsPolicy.estimatedPayloadBytes(["invalid": Double.nan]))
    }

    func testSocketWindowsKeepOnlyAggregateAllowlistedData() throws {
        var window = MobileMetricWindow(start: Date(timeIntervalSince1970: 0))
        window.apply(.socketPayload(.chatSendMessage, network: .cellular, sent: 120, received: 0))
        window.apply(.socketPayload(.chatSendMessage, network: .cellular, sent: 0, received: 80))
        window.apply(.bytes(.cellular, sent: 10, received: 20))
        window.apply(.socketReady(milliseconds: 1_000))
        window.apply(.increment(.socketConnect))
        window.apply(.increment(.socketReconnect))
        XCTAssertEqual(window.socketSentBytesByEvent[.chatSendMessage], 120)
        XCTAssertEqual(window.socketReceivedBytesByEvent[.chatSendMessage], 80)
        XCTAssertEqual(window.socketSentBytesByNetwork[.cellular], 120)
        XCTAssertEqual(window.socketReceivedBytesByNetwork[.cellular], 80)
        XCTAssertEqual(window.sentBytes[.cellular], 10)
        XCTAssertEqual(window.receivedBytes[.cellular], 20)
        XCTAssertEqual(window.socketReadyLatencyBuckets, [0, 0, 1, 0])
        XCTAssertEqual(window.counters[.socketReconnect], 1)
        let text = String(decoding: try JSONEncoder().encode(window), as: UTF8.self)
        for forbidden in ["private message", "latitude", "userId", "token", "ssid"] {
            XCTAssertFalse(text.contains(forbidden))
        }
        let decoded = try JSONDecoder().decode(MobileMetricWindow.self, from: JSONEncoder().encode(window))
        XCTAssertEqual(decoded, window)
    }

    func testOldWindowsLoadWithEmptySocketMetrics() throws {
        let old = Data(#"{"start":0,"counters":{}}"#.utf8)
        let decoded = try JSONDecoder().decode(MobileMetricWindow.self, from: old)
        XCTAssertTrue(decoded.socketSentBytesByEvent.isEmpty)
        XCTAssertTrue(decoded.socketReceivedBytesByEvent.isEmpty)
        XCTAssertTrue(decoded.socketSentBytesByNetwork.isEmpty)
        XCTAssertEqual(decoded.socketReadyLatencyBuckets, [0, 0, 0, 0])
    }

    func testNetworkClassificationAndInvalidMeasurements() {
        XCTAssertEqual(NetworkPathObserver.classify(satisfied: false, cellular: true, wifi: true), .offline)
        XCTAssertEqual(NetworkPathObserver.classify(satisfied: true, cellular: true, wifi: true), .cellular)
        XCTAssertEqual(NetworkPathObserver.classify(satisfied: true, cellular: false, wifi: true), .wifi)
        XCTAssertEqual(NetworkPathObserver.classify(satisfied: true, cellular: false, wifi: false), .other)
        var window = MobileMetricWindow(start: Date())
        window.apply(.socketPayload(.sosAlert, network: .wifi, sent: -1, received: 5))
        window.apply(.socketReady(milliseconds: -1))
        XCTAssertTrue(window.socketSentBytesByEvent.isEmpty)
        XCTAssertEqual(window.socketReadyLatencyBuckets, [0, 0, 0, 0])
    }
}
