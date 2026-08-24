package com.obscura.kit.wire

import obscura.client.v1.Client.ClientMessage.PayloadCase

/**
 * What a payload arm is allowed to do on receipt (`KIT_API.md` §4).
 *
 * Every arm MUST be classified, because **the classification is what makes SPEC §0.9 checkable
 * rather than aspirational**. "Never ack before persisting" is not a rule the code can follow until
 * something says, per arm, *what persisting means for this one*.
 */
internal enum class PayloadDisposition {
    /** Application content. Goes in the inbox; the app drains it. Ack only after the row commits. */
    INBOXED,

    /** Mutates kit-owned state (friend graph or devices). Ack only after the kit's write. */
    KIT_INTERNAL,

    /** Ephemeral by design, no durable delivery guarantee. MAY be acked without persistence. */
    DROPPABLE,
}

/**
 * The §4 classification table, as code.
 *
 * An arm this kit has never heard of is **inboxed unparsed** (§4.1). Leaving it
 * unacked would turn an unsupported sender into an unbounded retry:
 *
 * > any authenticated user may send to any device → a never-acked message is never deleted and
 * > redelivers forever → the server's queue caps at 1000 per device and evicts **oldest-first,
 * > silently** → a stranger looping unknown arms pushes the recipient's real undelivered mail off
 * > the back of the queue.
 *
 * Refusing to ack is reserved for transient local failures that can succeed on a later attempt.
 */
internal fun payloadDisposition(arm: PayloadCase): PayloadDisposition = when (arm) {
    // The app's entire data path.
    PayloadCase.APP_ENTRY -> PayloadDisposition.INBOXED

    // Kit-owned state, all with live handlers in ObscuraClient.routeMessage.
    PayloadCase.FRIEND_REQUEST,
    PayloadCase.FRIEND_ACCEPT,
    PayloadCase.DEVICE_ANNOUNCE,
    PayloadCase.DEVICE_LINK_APPROVAL -> PayloadDisposition.KIT_INTERNAL

    // Typing indicators. The contract makes them in-memory only, and §4 permits acking without
    // persistence — the ONLY class for which that is allowed.
    PayloadCase.TYPING_SIGNAL -> PayloadDisposition.DROPPABLE

    // Unknown or future arm, and PAYLOAD_NOT_SET. Inbox it unparsed rather than destroy it.
    else -> PayloadDisposition.INBOXED
}
