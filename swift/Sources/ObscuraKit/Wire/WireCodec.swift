import Foundation

/// Single source of truth for the wire <-> app-facing-form mappings.
///
/// The message kind is the `ClientMessage.payload` oneof arm; `SignalKind`
/// carries a `SIGNAL_KIND_` prefix. A kit that maps these inconsistently
/// silently breaks cross-platform interop, so the mappings are consolidated here
/// and pinned by `protocol/conformance/wire.json` (see NATIVE_CONTRACT §3).
/// Mirrors the Kotlin kit's `WireCodec`.
///
/// Internal on purpose: SwiftProtobuf generates the `Obscura_Client_V1_*` types with
/// `internal` visibility, so this codec (which references them) is internal too.
/// Tests reach it via `@testable import ObscuraKit`.
enum WireCodec {

    // MARK: SignalKind <-> app string ("typing" / "stoppedTyping")

    static func encodeSignalKind(_ app: String) -> Obscura_Client_V1_SignalKind {
        switch app {
        case "typing": return .typing
        case "stoppedTyping": return .stoppedTyping
        default: return .unspecified
        }
    }

    static func decodeSignalKind(_ kind: Obscura_Client_V1_SignalKind) -> String {
        switch kind {
        case .typing: return "typing"
        case .stoppedTyping: return "stoppedTyping"
        default: return ""
        }
    }

    // MARK: ClientMessage.payload oneof -> app string

    /// App-facing message-kind string: the set `payload` arm's field name,
    /// upper-snake. An unset payload (or `.none`) maps to "".
    static func decodeMessageType(_ payload: Obscura_Client_V1_ClientMessage.OneOf_Payload?) -> String {
        switch payload {
        case .friendRequest?: return "FRIEND_REQUEST"
        case .friendResponse?: return "FRIEND_RESPONSE"
        case .sessionReset?: return "SESSION_RESET"
        case .deviceLinkApproval?: return "DEVICE_LINK_APPROVAL"
        case .deviceAnnounce?: return "DEVICE_ANNOUNCE"
        case .appEntry?: return "APP_ENTRY"
        case .modelSignal?: return "MODEL_SIGNAL"
        case .none: return ""
        }
    }
}
