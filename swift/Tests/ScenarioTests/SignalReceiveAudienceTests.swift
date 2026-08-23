import XCTest
@testable import ObscuraKit

final class SignalReceiveAudienceTests: XCTestCase {
    private let selfUserId = "self-user"
    private let peerUserId = "peer-user"
    private let peerDeviceId = "peer-device"

    private func makeClient(acceptPeer: Bool = true) async throws -> ObscuraClient {
        let client = try ObscuraClient(apiURL: "http://localhost")
        await client.restoreSession(
            token: "test-token",
            refreshToken: nil,
            userId: selfUserId,
            deviceId: "self-device",
            username: "self"
        )
        if acceptPeer {
            try await client.friends.add(peerUserId, "alice", status: .accepted)
        }
        return client
    }

    private func typing(_ contextId: String) -> Obscura_Client_V1_ClientMessage {
        var signal = Obscura_Client_V1_ModelSignal()
        signal.model = "directMessage"
        signal.kind = .typing
        signal.contextID = contextId

        var message = Obscura_Client_V1_ClientMessage()
        message.modelSignal = signal
        message.timestamp = UInt64(Date().timeIntervalSince1970 * 1_000)
        return message
    }

    private func activeTypers(_ contextId: String) async -> [String] {
        await SignalStoreRegistry.shared.store.getActive(
            model: "directMessage",
            signal: "typing",
            data: ["conversationId": contextId]
        )
    }

    func testSignalForConversationWithoutSenderIsDropped() async throws {
        await SignalStoreRegistry.shared.store.clearAll()
        let client = try await makeClient()
        let strangersConversation = ["other-a", selfUserId].sorted().joined(separator: "_")

        await client.handleModelSignal(
            typing(strangersConversation),
            sourceUserId: peerUserId,
            senderDeviceId: peerDeviceId
        )

        let active = await activeTypers(strangersConversation)
        XCTAssertTrue(active.isEmpty)
    }

    func testSignalForConversationWithoutLocalUserIsDropped() async throws {
        await SignalStoreRegistry.shared.store.clearAll()
        let client = try await makeClient()
        let unrelatedConversation = ["other-user", peerUserId].sorted().joined(separator: "_")

        await client.handleModelSignal(
            typing(unrelatedConversation),
            sourceUserId: peerUserId,
            senderDeviceId: peerDeviceId
        )

        let active = await activeTypers(unrelatedConversation)
        XCTAssertTrue(active.isEmpty)
    }

    func testMalformedAndNonCanonicalContextsAreDropped() async throws {
        await SignalStoreRegistry.shared.store.clearAll()
        let client = try await makeClient()
        let reversed = [selfUserId, peerUserId].sorted(by: >).joined(separator: "_")

        for contextId in [selfUserId, "_\(peerUserId)", reversed] {
            await client.handleModelSignal(
                typing(contextId),
                sourceUserId: peerUserId,
                senderDeviceId: peerDeviceId
            )
            let active = await activeTypers(contextId)
            XCTAssertTrue(active.isEmpty, "\(contextId) must be refused")
        }
    }

    func testSignalFromUnacceptedSenderIsDropped() async throws {
        await SignalStoreRegistry.shared.store.clearAll()
        let client = try await makeClient(acceptPeer: false)
        let conversation = [selfUserId, peerUserId].sorted().joined(separator: "_")

        await client.handleModelSignal(
            typing(conversation),
            sourceUserId: peerUserId,
            senderDeviceId: peerDeviceId
        )

        let active = await activeTypers(conversation)
        XCTAssertTrue(active.isEmpty)
    }

    func testCanonicalAcceptedConversationIsApplied() async throws {
        await SignalStoreRegistry.shared.store.clearAll()
        let client = try await makeClient()
        let conversation = [selfUserId, peerUserId].sorted().joined(separator: "_")

        await client.handleModelSignal(
            typing(conversation),
            sourceUserId: peerUserId,
            senderDeviceId: peerDeviceId
        )

        let active = await activeTypers(conversation)
        XCTAssertEqual(active, ["alice"])
    }
}
