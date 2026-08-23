import XCTest
import LibSignalClient
@testable import ObscuraKit

/// Device link code + approval flow
/// New device generates challenge → existing device approves with DEVICE_LINK_APPROVAL
final class DeviceLinkFlowTests: XCTestCase {

    // MARK: - Link code generation

    func testLinkCodeGeneration() {
        // Link code is a random challenge the new device generates
        let challenge = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        XCTAssertEqual(challenge.count, 32)

        // In the web client, this is encoded as base58 for display
        // The existing device echoes it back in DEVICE_LINK_APPROVAL.challengeResponse
    }

    // MARK: - DEVICE_LINK_APPROVAL delivery

    func testDeviceLinkApprovalDelivery() async throws {
        let existingDevice = try await ObscuraTestClient.register()
        await rateLimitDelay()
        let newDevice = try await ObscuraTestClient.register()
        await rateLimitDelay()

        // New device connects to receive approval
        try await newDevice.connectWebSocket()
        await rateLimitDelay()

        // Existing device sends DEVICE_LINK_APPROVAL
        // Build approval message with p2p keys and device list
        var approval = Obscura_Client_V1_DeviceLinkApproval()
        approval.p2PPublicKey = Data(repeating: 0x05, count: 33)   // p2p identity
        approval.p2PPrivateKey = Data(repeating: 0xBB, count: 32)  // p2p private (encrypted transfer)
        approval.recoveryPublicKey = Data(repeating: 0xCC, count: 32)
        approval.challengeResponse = Data(repeating: 0xDD, count: 32)  // echo back challenge

        var device1Info = Obscura_Client_V1_DeviceInfo()
        device1Info.deviceID = existingDevice.deviceId ?? ""
        device1Info.deviceName = "Existing Phone"
        approval.ownDevices = [device1Info]

        approval.friendsExport = Data("[]".utf8)

        var msg = Obscura_Client_V1_ClientMessage()
        msg.deviceLinkApproval = approval
        msg.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        try await existingDevice.sendRaw(to: newDevice.userId!, try msg.serializedData())
        await rateLimitDelay()

        // New device receives DEVICE_LINK_APPROVAL
        let received = try await newDevice.waitForMessage(timeout: 10)
        XCTAssertEqual(received.type, "DEVICE_LINK_APPROVAL", "Should be DEVICE_LINK_APPROVAL (11)")
        XCTAssertEqual(received.sourceUserId, existingDevice.userId!)

        newDevice.disconnectWebSocket()
    }

}
