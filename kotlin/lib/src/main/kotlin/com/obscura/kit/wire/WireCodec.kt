package com.obscura.kit.wire

import obscura.client.v1.Client

/**
 * Single source of truth for translating the `client.proto` wire enum to the
 * kit's app-facing signal names.
 *
 * Keeping every mapping here prevents call-site drift. The shared
 * `protocol/conformance/wire.json` vectors pin cross-platform behavior
 * (SPEC §3).
 */
object WireCodec {

    // ─── ClientMessage.payload oneof → app string ────────────────────────────

    /**
     * The app-facing message-type string: the set `payload` oneof arm's field
     * name, upper-snake (which the generated [Client.ClientMessage.PayloadCase]
     * already is). An unset payload maps to "".
     */
    fun decodeType(case: Client.ClientMessage.PayloadCase): String =
        if (case == Client.ClientMessage.PayloadCase.PAYLOAD_NOT_SET) "" else case.name

    // ─── SignalKind ↔ app signal name ─────────────────────────────────────────

    fun encodeSignalKind(name: String): Client.SignalKind = when (name) {
        "typing" -> Client.SignalKind.SIGNAL_KIND_TYPING
        "stoppedTyping" -> Client.SignalKind.SIGNAL_KIND_STOPPED_TYPING
        else -> Client.SignalKind.SIGNAL_KIND_UNSPECIFIED
    }

    /** @return the internal signal name, or null for UNSPECIFIED/unrecognized (caller ignores). */
    fun decodeSignalKind(kind: Client.SignalKind): String? = when (kind) {
        Client.SignalKind.SIGNAL_KIND_TYPING -> "typing"
        Client.SignalKind.SIGNAL_KIND_STOPPED_TYPING -> "stoppedTyping"
        else -> null
    }
}
