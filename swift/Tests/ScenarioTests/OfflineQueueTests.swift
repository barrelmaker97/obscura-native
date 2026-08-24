import XCTest
@testable import ObscuraKit

/// Offline entry queuing — disconnect → server queues → reconnect → receive.
final class OfflineQueueTests: XCTestCase {

    func testOfflineMessageDelivery() async throws {
        // send() requires an accepted friendship; the handshake leaves both connected.
        let (alice, bob) = try await ObscuraTestClient.registerPairAndBecomeFriends()

        // Bob goes offline
        bob.disconnectWebSocket()
        await rateLimitDelay()

        try await alice.client.send(
            to: [bob.userId!], modelKey: "testModel", entryId: "offline-one",
            payload: Data("you there?".utf8)
        )
        await rateLimitDelay()

        // Bob reconnects
        try await bob.connectWebSocket()
        await rateLimitDelay()

        let msg = try await bob.waitForMessage(timeout: 10)
        XCTAssertEqual(msg.type, "APP_ENTRY")
        XCTAssertEqual(msg.sourceUserId, alice.userId!)
        let rows = try await bob.client.inbox.peek()
        XCTAssertTrue(rows.contains { $0.entryId == "offline-one" })

        alice.disconnectWebSocket()
        bob.disconnectWebSocket()
    }

    func testMultipleOfflineMessages() async throws {
        let (alice, bob) = try await ObscuraTestClient.registerPairAndBecomeFriends()

        // Bob goes offline
        bob.disconnectWebSocket()
        await rateLimitDelay()

        try await alice.client.send(
            to: [bob.userId!], modelKey: "testModel", entryId: "offline-one",
            payload: Data("message 1".utf8)
        )
        await rateLimitDelay()
        try await alice.client.send(
            to: [bob.userId!], modelKey: "testModel", entryId: "offline-two",
            payload: Data("message 2".utf8)
        )
        await rateLimitDelay()

        // Bob reconnects
        try await bob.connectWebSocket()
        await rateLimitDelay()

        // Bob should receive both queued messages
        let msg1 = try await bob.waitForMessage(timeout: 10)
        let msg2 = try await bob.waitForMessage(timeout: 10)

        XCTAssertEqual([msg1.type, msg2.type], ["APP_ENTRY", "APP_ENTRY"])
        let ids = try await bob.client.inbox.peek().compactMap(\.entryId).sorted()
        XCTAssertEqual(ids, ["offline-one", "offline-two"])

        alice.disconnectWebSocket()
        bob.disconnectWebSocket()
    }

    func testSessionSurvivesReconnect() async throws {
        let (alice, bob) = try await ObscuraTestClient.registerPairAndBecomeFriends()

        try await alice.client.send(
            to: [bob.userId!], modelKey: "testModel", entryId: "before-disconnect",
            payload: Data("before disconnect".utf8)
        )
        await rateLimitDelay()

        let first = try await bob.waitForMessage(timeout: 10)
        XCTAssertEqual(first.type, "APP_ENTRY")

        // Bob disconnects and reconnects
        bob.disconnectWebSocket()
        await rateLimitDelay()
        try await bob.connectWebSocket()
        await rateLimitDelay()

        try await alice.client.send(
            to: [bob.userId!], modelKey: "testModel", entryId: "after-reconnect",
            payload: Data("after reconnect".utf8)
        )
        await rateLimitDelay()

        let second = try await bob.waitForMessage(timeout: 10)
        XCTAssertEqual(second.type, "APP_ENTRY")
        XCTAssertEqual(second.sourceUserId, alice.userId!)

        alice.disconnectWebSocket()
        bob.disconnectWebSocket()
    }
}
