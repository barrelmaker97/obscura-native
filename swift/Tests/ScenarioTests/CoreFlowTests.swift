import XCTest
@testable import ObscuraKit

/// Register, friend, deliver an opaque entry, persist it through restart, then receive a queued
/// entry after reconnect. This is the shortest scenario that crosses every live kit layer.
final class CoreFlowTests: XCTestCase {
    private func tempDir(_ label: String) -> String {
        let dir = NSTemporaryDirectory() + "obscura_core_\(label)_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dirs: String...) {
        for dir in dirs { try? FileManager.default.removeItem(atPath: dir) }
    }

    func testFullCoreFlow() async throws {
        let aliceDir = tempDir("alice")
        let bobDir = tempDir("bob")
        defer { cleanup(aliceDir, bobDir) }

        let apiURL = TestServer.apiURL
        let password = "testpass123456"
        let aliceUsername = "test_\(Int.random(in: 100000...999999))"
        let bobUsername = "test_\(Int.random(in: 100000...999999))"

        let alice = try ObscuraClient(apiURL: apiURL, dataDirectory: aliceDir)
        try await alice.register(aliceUsername, password)
        await rateLimitDelay()
        let bob = try ObscuraClient(apiURL: apiURL, dataDirectory: bobDir)
        try await bob.register(bobUsername, password)
        await rateLimitDelay()

        let aliceUserId = try XCTUnwrap(alice.userId)
        let bobUserId = try XCTUnwrap(bob.userId)
        let aliceToken = try XCTUnwrap(alice.token)
        let bobToken = try XCTUnwrap(bob.token)
        let aliceDeviceId = try XCTUnwrap(alice.deviceId)
        let bobDeviceId = try XCTUnwrap(bob.deviceId)
        let aliceRefreshToken = alice.refreshToken
        let bobRefreshToken = bob.refreshToken

        try await alice.connect()
        try await bob.connect()
        try await alice.befriend(bobUserId, username: bobUsername)
        _ = try await bob.waitForMessage(timeout: 10)
        try await bob.acceptFriend(aliceUserId, username: aliceUsername)
        _ = try await alice.waitForMessage(timeout: 10)

        let aliceFriend = await alice.friends.getFriend(bobUserId)
        let bobFriend = await bob.friends.getFriend(aliceUserId)
        XCTAssertEqual(aliceFriend?.status, .accepted)
        XCTAssertEqual(bobFriend?.status, .accepted)

        let firstPayload = Data(#"{"content":"opaque and current"}"#.utf8)
        try await alice.send(
            to: [bobUserId],
            modelKey: "testModel",
            entryId: "entry-online",
            payload: firstPayload
        )
        let firstWake = try await bob.waitForMessage(timeout: 10)
        XCTAssertEqual(firstWake.type, "MODEL_SYNC")

        let firstRows = try await bob.inbox.peek()
        let firstRow = try XCTUnwrap(firstRows.first { $0.entryId == "entry-online" })
        XCTAssertEqual(firstRow.payload, firstPayload)
        try await bob.entries.put(
            model: "testModel",
            entry: StoredEntry(
                id: "entry-online",
                data: String(decoding: firstPayload, as: UTF8.self),
                sentAt: firstRow.sentAt ?? 0,
                authorDeviceId: firstRow.senderDeviceId ?? ""
            )
        )
        try await bob.inbox.consume([firstRow.id])

        alice.disconnect()
        bob.disconnect()

        let alice2 = try ObscuraClient(apiURL: apiURL, dataDirectory: aliceDir)
        let bob2 = try ObscuraClient(apiURL: apiURL, dataDirectory: bobDir)
        XCTAssertTrue(alice2.persistentSignalStore?.hasPersistedIdentity ?? false)
        XCTAssertTrue(bob2.persistentSignalStore?.hasPersistedIdentity ?? false)
        let persistedAliceFriend = await alice2.friends.getFriend(bobUserId)
        let persistedBobFriend = await bob2.friends.getFriend(aliceUserId)
        XCTAssertEqual(persistedAliceFriend?.status, .accepted)
        XCTAssertEqual(persistedBobFriend?.status, .accepted)
        let persisted = try await bob2.entries.all(model: "testModel")
        XCTAssertEqual(persisted.map(\.id), ["entry-online"])

        await alice2.restoreSession(
            token: aliceToken,
            refreshToken: aliceRefreshToken,
            userId: aliceUserId,
            deviceId: aliceDeviceId,
            username: aliceUsername
        )
        try await alice2.connect()
        try await alice2.send(
            to: [bobUserId],
            modelKey: "testModel",
            entryId: "entry-queued",
            payload: Data("queued".utf8)
        )

        await bob2.restoreSession(
            token: bobToken,
            refreshToken: bobRefreshToken,
            userId: bobUserId,
            deviceId: bobDeviceId,
            username: bobUsername
        )
        try await bob2.connect()
        let queuedWake = try await bob2.waitForMessage(timeout: 15)
        XCTAssertEqual(queuedWake.type, "MODEL_SYNC")
        let queuedRows = try await bob2.inbox.peek()
        XCTAssertTrue(queuedRows.contains { $0.entryId == "entry-queued" })

        alice2.disconnect()
        bob2.disconnect()
    }
}
