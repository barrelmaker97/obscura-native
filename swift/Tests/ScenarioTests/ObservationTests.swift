import XCTest
@testable import ObscuraKit

/// Test reactive observation — GRDB ValueObservation pushes changes to AsyncStream.
/// These prove that SwiftUI views will re-render automatically on data changes.
final class ObservationTests: XCTestCase {

    // MARK: - Friends observation

    func testFriendsObservationEmitsOnAdd() async throws {
        let actor = try FriendStore()

        var emitted: [[Friend]] = []
        let expectation = XCTestExpectation(description: "stream emits")

        let task = Task {
            for await friends in actor.observeAccepted().values {
                emitted.append(friends)
                if emitted.count >= 2 { // initial + after add
                    expectation.fulfill()
                    break
                }
            }
        }

        // Wait for initial emission (empty)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Add a friend — should trigger second emission
        try await actor.add("alice-id", "alice", status: .accepted)

        await fulfillment(of: [expectation], timeout: 5)
        task.cancel()

        // First emission: empty (initial state)
        XCTAssertEqual(emitted[0].count, 0)
        // Second emission: 1 friend (after add)
        XCTAssertEqual(emitted[1].count, 1)
        XCTAssertEqual(emitted[1][0].username, "alice")
    }

    func testFriendsObservationEmitsOnStatusChange() async throws {
        let actor = try FriendStore()

        // Add a pending friend first
        try await actor.add("bob-id", "bob", status: .pendingReceived)

        var emitted: [[Friend]] = []
        let expectation = XCTestExpectation(description: "accepted emits")

        let task = Task {
            for await friends in actor.observeAccepted().values {
                emitted.append(friends)
                if emitted.count >= 2 {
                    expectation.fulfill()
                    break
                }
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        // Update status to accepted — should trigger emission
        try await actor.updateStatus("bob-id", .accepted)

        await fulfillment(of: [expectation], timeout: 5)
        task.cancel()

        XCTAssertEqual(emitted[0].count, 0, "Initially no accepted friends")
        XCTAssertEqual(emitted[1].count, 1, "After accept, one friend")
    }

    // MARK: - Devices observation

    func testDevicesObservationEmitsOnAdd() async throws {
        let actor = try DeviceStore()

        var emitted: [[OwnDevice]] = []
        let expectation = XCTestExpectation(description: "devices emit")

        let task = Task {
            for await devices in actor.observeOwnDevices().values {
                emitted.append(devices)
                if emitted.count >= 2 {
                    expectation.fulfill()
                    break
                }
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        await actor.addOwnDevice(OwnDevice(deviceUUID: "uuid1", deviceId: "dev1", deviceName: "iPhone"))

        await fulfillment(of: [expectation], timeout: 5)
        task.cancel()

        XCTAssertEqual(emitted[0].count, 0)
        XCTAssertEqual(emitted[1].count, 1)
        XCTAssertEqual(emitted[1][0].deviceName, "iPhone")
    }

}
