import XCTest
@testable import ObscuraKit

/// Device API and two-way messaging scenarios against the actual server.
///
/// Supported multi-device messaging and local device-state operations.
final class DeviceApiTests: XCTestCase {

    // MARK: - 7.1: Two-way entry exchange

    func testTwoWayEntryExchange() async throws {
        let (alice, bob) = try await ObscuraTestClient.registerPairAndBecomeFriends()

        try await alice.client.send(
            to: [bob.userId!], modelKey: "testModel", entryId: "alice-to-bob",
            payload: Data("hi bob".utf8)
        )
        let bobWake = try await bob.waitForMessage(timeout: 10)
        XCTAssertEqual(bobWake.type, "APP_ENTRY")

        try await bob.client.send(
            to: [alice.userId!], modelKey: "testModel", entryId: "bob-to-alice",
            payload: Data("hi alice".utf8)
        )
        let aliceWake = try await alice.waitForMessage(timeout: 10)
        XCTAssertEqual(aliceWake.type, "APP_ENTRY")

        alice.disconnectWebSocket()
        bob.disconnectWebSocket()
    }

    // MARK: - 7.2: Delete device via server API

    func testListRegisteredDevices() async throws {
        let bob = try await ObscuraTestClient.register()
        await rateLimitDelay()

        // List devices — should have our device
        let devicesList = try await bob.api.listDevices()
        XCTAssertFalse(devicesList.isEmpty, "Should have at least one device")
    }
}
