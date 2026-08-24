import Foundation
import XCTest
import SwiftProtobuf
@testable import ObscuraKit

/// Vector-driven client-wire conformance, consuming the shared
/// `../protocol/conformance/wire.json` (NATIVE_CONTRACT §3). Both platforms run the
/// same file.
///
/// Pins the signal enum <-> app-facing-form mapping via the production
/// `WireCodec`, and that a `AppEntry` round-trips through the wire by VALUE.
/// Byte-canonicity is intentionally NOT asserted (SPEC §3.3).
///
/// The `wire`-name → generated-enum-case maps below are a test harness:
/// SwiftProtobuf does not expose the proto enum names, so we bind them once here.
/// The production mapping under test is `WireCodec`.
final class WireConformanceTests: XCTestCase {

    private let payloadByWire: [String: Obscura_Client_V1_ClientMessage.OneOf_Payload] = [
        "friend_request": .friendRequest(Obscura_Client_V1_FriendRequest()),
        "app_entry": .appEntry(Obscura_Client_V1_AppEntry()),
        "model_signal": .modelSignal(Obscura_Client_V1_ModelSignal()),
    ]
    private let kindByWire: [String: Obscura_Client_V1_SignalKind] = [
        "SIGNAL_KIND_TYPING": .typing,
        "SIGNAL_KIND_STOPPED_TYPING": .stoppedTyping,
    ]

    func testWireConformance() throws {
        let v = try ConformanceVectors.load("wire.json")

        for m in (v["messageTypes"] as? [[String: Any]] ?? []) {
            let wire = m["wire"] as? String ?? "", app = m["app"] as? String ?? ""
            guard let p = payloadByWire[wire] else { XCTFail("unmapped wire messageType \(wire)"); continue }
            XCTAssertEqual(WireCodec.decodeMessageType(p), app, "messageType \(wire) -> \(app)")
        }

        for m in (v["signalKinds"] as? [[String: Any]] ?? []) {
            let wire = m["wire"] as? String ?? "", app = m["app"] as? String ?? ""
            guard let k = kindByWire[wire] else { XCTFail("unmapped wire signalKind \(wire)"); continue }
            XCTAssertEqual(WireCodec.decodeSignalKind(k), app, "decode \(wire)")
            XCTAssertEqual(WireCodec.encodeSignalKind(app), k, "encode \(app)")
        }

        for rt in (v["roundTrip"] as? [[String: Any]] ?? []) {
            try roundTrip(rt["appEntry"] as? [String: Any] ?? [:], name: rt["name"] as? String ?? "?")
        }
    }

    /// Serialize to protobuf bytes and parse back — a true wire round-trip.
    private func roundTrip(_ ms: [String: Any], name: String) throws {
        let model = ms["model"] as? String ?? ""
        let id = ms["id"] as? String ?? ""
        let ts = conformanceUInt64(ms["timestamp"])
        let dataMap = ms["data"] as? [String: Any] ?? [:]

        var proto = Obscura_Client_V1_AppEntry()
        proto.model = model
        proto.id = id
        proto.timestamp = ts
        proto.data = try JSONSerialization.data(withJSONObject: dataMap)

        let decoded = try Obscura_Client_V1_AppEntry(serializedData: proto.serializedData())

        XCTAssertEqual(decoded.model, model, "[\(name)] model")
        XCTAssertEqual(decoded.id, id, "[\(name)] id")
        XCTAssertEqual(decoded.timestamp, ts, "[\(name)] timestamp")
        // data round-trips by VALUE (parsed map), not bytes — key order is irrelevant.
        let decodedData = (try JSONSerialization.jsonObject(with: decoded.data) as? [String: Any]) ?? [:]
        XCTAssertEqual(
            NSDictionary(dictionary: decodedData),
            NSDictionary(dictionary: dataMap),
            "[\(name)] data value"
        )
    }
}
