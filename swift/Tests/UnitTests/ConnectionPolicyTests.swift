import Foundation
import XCTest
@testable import ObscuraKit

final class ConnectionPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)
    private let window: TimeInterval = 10

    func testEmptyDrainOnStaleConnectedSocketForcesReconnect() {
        XCTAssertTrue(shouldForceReconnectAfterPush(
            processed: 0,
            startedConnected: true,
            lastProcessedAt: now.addingTimeInterval(-window - 0.001),
            now: now,
            recentActivityWindow: window
        ))
    }

    func testSocketThatNeverProcessedAnEnvelopeForcesReconnect() {
        XCTAssertTrue(shouldForceReconnectAfterPush(
            processed: 0,
            startedConnected: true,
            lastProcessedAt: .distantPast,
            now: now,
            recentActivityWindow: window
        ))
    }

    func testRecentActivitySuppressesReconnect() {
        XCTAssertFalse(shouldForceReconnectAfterPush(
            processed: 0,
            startedConnected: true,
            lastProcessedAt: now.addingTimeInterval(-window),
            now: now,
            recentActivityWindow: window
        ))
    }

    func testProcessedEnvelopeSuppressesReconnect() {
        XCTAssertFalse(shouldForceReconnectAfterPush(
            processed: 1,
            startedConnected: true,
            lastProcessedAt: .distantPast,
            now: now,
            recentActivityWindow: window
        ))
    }

    func testDrainThatConnectedForItselfDoesNotReconnectAgain() {
        XCTAssertFalse(shouldForceReconnectAfterPush(
            processed: 0,
            startedConnected: false,
            lastProcessedAt: .distantPast,
            now: now,
            recentActivityWindow: window
        ))
    }
}
