package com.obscura.kit

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Regression tests for the push-wake drain acting on a contradicted connection state.
 *
 * The rule these pin, from both sides: a push arriving is proof the server had something this
 * device had not acked, so an empty drain on a live-looking socket means the socket is wrong — but
 * a drain that delivered, or one on a freshly established socket, must not reconnect.
 */
class PushDrainContradictionTest {

    private val window = 10_000L
    private val now = 1_000_000L

    @Test
    fun `empty drain on a socket that claimed CONNECTED forces a reconnect`() {
        // THE regression. Before the fix this path did nothing and the drain returned zero.
        assertTrue(
            shouldForceReconnectAfterPush(
                processed = 0L,
                startedConnected = true,
                lastProcessedAtMs = now - window - 1,
                nowMs = now,
                recentActivityWindowMs = window,
            ),
            "a push with nothing drained on a live socket must force a reconnect",
        )
    }

    @Test
    fun `a connection that has never received anything is treated as stale`() {
        assertTrue(
            shouldForceReconnectAfterPush(
                processed = 0L,
                startedConnected = true,
                lastProcessedAtMs = 0L,
                nowMs = now,
                recentActivityWindowMs = window,
            ),
            "a socket that has never delivered cannot be given the benefit of the doubt",
        )
    }

    @Test
    fun `a successful drain never reconnects`() {
        // The normal case, and the one that must stay free: no churn when delivery works.
        assertFalse(
            shouldForceReconnectAfterPush(
                processed = 3L,
                startedConnected = true,
                lastProcessedAtMs = now,
                nowMs = now,
                recentActivityWindowMs = window,
            ),
            "envelopes arrived, so the socket is fine",
        )
    }

    @Test
    fun `recent activity excuses an empty drain`() {
        // The benign race: the socket delivered the message moments before the scheduled push
        // fired, and our ack was still in flight. Reconnecting here would be pure churn.
        assertFalse(
            shouldForceReconnectAfterPush(
                processed = 0L,
                startedConnected = true,
                lastProcessedAtMs = now - 1_000,
                nowMs = now,
                recentActivityWindowMs = window,
            ),
            "a socket that delivered a second ago has not been contradicted",
        )
    }

    @Test
    fun `a drain that had to connect first does not reconnect again`() {
        // We already established a fresh socket for this drain; there is no stale one to blame,
        // and a second reconnect would change nothing.
        assertFalse(
            shouldForceReconnectAfterPush(
                processed = 0L,
                startedConnected = false,
                lastProcessedAtMs = 0L,
                nowMs = now,
                recentActivityWindowMs = window,
            ),
            "a freshly established connection must not be torn down again",
        )
    }

    @Test
    fun `the window boundary is not itself a contradiction`() {
        assertFalse(
            shouldForceReconnectAfterPush(
                processed = 0L,
                startedConnected = true,
                lastProcessedAtMs = now - window,
                nowMs = now,
                recentActivityWindowMs = window,
            ),
            "activity exactly at the window edge still counts as recent",
        )
    }
}
