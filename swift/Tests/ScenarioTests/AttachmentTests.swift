import XCTest
@testable import ObscuraKit

/// Scenario 6: Attachments — against actual server
/// Upload, download, integrity check
final class AttachmentTests: XCTestCase {

    // MARK: - 6.1: Upload attachment

    func testScenario6_1_UploadAttachment() async throws {
        let alice = try await ObscuraTestClient.register()
        await rateLimitDelay()

        // Create a small JPEG-like blob (just header bytes for testing)
        var blob = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG magic bytes
        blob.append(Data(repeating: 0xAA, count: 1000))

        let result = try await alice.api.uploadAttachment(blob)
        let attachmentId = result.id
        XCTAssertFalse(attachmentId.isEmpty, "Server should return attachment ID")
    }

    // MARK: - 6.3: Download + integrity check

    func testScenario6_3_DownloadAndVerify() async throws {
        let alice = try await ObscuraTestClient.register()
        await rateLimitDelay()

        // Upload
        let originalData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
        let result = try await alice.api.uploadAttachment(originalData)
        let attachmentId = result.id
        await rateLimitDelay()

        // Download
        let downloaded = try await alice.api.fetchAttachment(attachmentId)

        // Verify integrity
        XCTAssertEqual(downloaded, originalData, "Downloaded data should match uploaded")

        // Verify JPEG header
        XCTAssertEqual(downloaded[0], 0xFF)
        XCTAssertEqual(downloaded[1], 0xD8)
    }

}
