import XCTest
@testable import ObscuraKit

/// Typing delivery follows the explicit caller-supplied audience.
final class SignalAudienceTests: XCTestCase {

    func testTypingReachesNamedPeerAndNotUnnamedFriend() async throws {
        let alice = try await ObscuraTestClient.register()
        await rateLimitDelay()
        let bob = try await ObscuraTestClient.register()
        await rateLimitDelay()
        let carol = try await ObscuraTestClient.register()
        await rateLimitDelay()

        try await alice.connectWebSocket()
        try await bob.connectWebSocket()
        try await carol.connectWebSocket()
        await rateLimitDelay()
        try await ObscuraTestClient.becomeFriends(alice, bob)
        try await ObscuraTestClient.becomeFriends(alice, carol)

        await alice.client.sendTyping(
            to: [try XCTUnwrap(bob.userId)],
            contextId: "opaque-context",
            state: .started
        )

        let bobGot = try await bob.waitForMessage(timeout: 10)
        XCTAssertEqual(bobGot.type, "TYPING_SIGNAL")
        do {
            let leaked = try await carol.waitForMessage(timeout: 5)
            XCTFail("unnamed friend received \(leaked.type)")
        } catch {
            // Expected.
        }

        alice.disconnectWebSocket()
        bob.disconnectWebSocket()
        carol.disconnectWebSocket()
    }

    func testTypingContextIsOpaque() async throws {
        let alice = try await ObscuraTestClient.register()
        await rateLimitDelay()
        let bob = try await ObscuraTestClient.register()
        await rateLimitDelay()
        try await alice.connectWebSocket()
        try await bob.connectWebSocket()
        await rateLimitDelay()
        try await ObscuraTestClient.becomeFriends(alice, bob)

        await alice.client.sendTyping(
            to: [try XCTUnwrap(bob.userId)],
            contextId: "not-a-conversation-id",
            state: .started
        )
        let received = try await bob.waitForMessage(timeout: 10)
        XCTAssertEqual(received.type, "TYPING_SIGNAL")

        alice.disconnectWebSocket()
        bob.disconnectWebSocket()
    }

    func testTypingCanNameMultipleRecipients() async throws {
        let alice = try await ObscuraTestClient.register()
        await rateLimitDelay()
        let bob = try await ObscuraTestClient.register()
        await rateLimitDelay()
        let carol = try await ObscuraTestClient.register()
        await rateLimitDelay()
        try await alice.connectWebSocket()
        try await bob.connectWebSocket()
        try await carol.connectWebSocket()
        await rateLimitDelay()
        try await ObscuraTestClient.becomeFriends(alice, bob)
        try await ObscuraTestClient.becomeFriends(alice, carol)

        await alice.client.sendTyping(
            to: [try XCTUnwrap(bob.userId), try XCTUnwrap(carol.userId)],
            contextId: "shared-context",
            state: .started
        )
        let bobReceived = try await bob.waitForMessage(timeout: 10)
        let carolReceived = try await carol.waitForMessage(timeout: 10)
        XCTAssertEqual(bobReceived.type, "TYPING_SIGNAL")
        XCTAssertEqual(carolReceived.type, "TYPING_SIGNAL")

        alice.disconnectWebSocket()
        bob.disconnectWebSocket()
        carol.disconnectWebSocket()
    }
}
