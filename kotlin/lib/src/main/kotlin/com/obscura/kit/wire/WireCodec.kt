package com.obscura.kit.wire

import obscura.client.v1.Client

/**
 * Internal operation kind for a [ModelSyncData], decoupled from the wire enum
 * so the rest of the kit never touches proto `OP_*` constants directly.
 */
enum class ModelOp {
    CREATE,
    UPDATE;

    companion object {
        /** Parse an app-facing op string without inventing semantics for invalid input. */
        fun fromApp(value: String): ModelOp = when (value.uppercase()) {
            "CREATE" -> CREATE
            "UPDATE" -> UPDATE
            else -> throw com.obscura.kit.ObscuraError.InvalidArgument(
                "Unsupported model op: $value",
            )
        }
    }
}

/**
 * Single source of truth for translating between the `client.proto` wire
 * enums and the kit's app-facing forms.
 *
 * Keeping every mapping here prevents call-site drift. The shared
 * `protocol/conformance/wire.json` vectors pin cross-platform behavior
 * (SPEC §3).
 */
object WireCodec {

    // ─── ModelSync.Op ↔ ModelOp ──────────────────────────────────────────────

    fun encodeOp(op: ModelOp): Client.ModelSync.Op = when (op) {
        ModelOp.CREATE -> Client.ModelSync.Op.OP_CREATE
        ModelOp.UPDATE -> Client.ModelSync.Op.OP_UPDATE
    }

    /** `OP_UNSPECIFIED` and any unrecognized value decode to the safe default, CREATE. */
    fun decodeOp(op: Client.ModelSync.Op): ModelOp = when (op) {
        Client.ModelSync.Op.OP_UPDATE -> ModelOp.UPDATE
        else -> ModelOp.CREATE
    }

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
