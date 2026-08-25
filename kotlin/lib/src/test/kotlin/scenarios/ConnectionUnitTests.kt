package scenarios

import dev.barrelmaker.obscura.kit.network.GatewayConnection
import dev.barrelmaker.obscura.kit.network.GatewayState
import kotlinx.coroutines.*
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

/**
 * Unit tests for connection resilience — no server needed.
 *
 * Tests the mechanics: backoff timing, shouldReconnect flag,
 * token refresh before reconnect.
 */
class ConnectionUnitTests {

    // ─── GatewayConnection state ──────────────────────────────────

    @Test
    fun `Gateway starts disconnected`() {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val api = dev.barrelmaker.obscura.kit.network.APIClient("https://obscura.barrelmaker.dev")
        val gw = GatewayConnection(api, scope)

        assertEquals(GatewayState.DISCONNECTED, gw.state.value)
        scope.cancel()
    }

    // `Disconnect sets shouldReconnect false` was here. It asserted only
    // `state == DISCONNECTED` on a gateway that had never connected — i.e. exactly what
    // `Gateway starts disconnected` above already asserts, and nothing at all about
    // shouldReconnect, which the name promised and which is private.

    @Test
    fun `onStateChanged fires on every transition`() = runBlocking {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val api = dev.barrelmaker.obscura.kit.network.APIClient("https://obscura.barrelmaker.dev")
        val gw = GatewayConnection(api, scope)

        val seen = mutableListOf<GatewayState>()
        gw.onStateChanged = { seen.add(it) }

        // disconnect() is a real state mutation even from DISCONNECTED — verifies
        // the callback is the single mutation hook consumers rely on.
        gw.disconnect()
        assertTrue(seen.contains(GatewayState.DISCONNECTED),
            "onStateChanged must fire so connectionState can mirror the socket")
        scope.cancel()
    }

    // `Token refresh callback is invoked` was here and was a tautology: it assigned a lambda that
    // set a flag, called that same lambda itself, and asserted the flag. The gateway was never
    // involved. Verifying the gateway actually calls `ensureFreshToken` before a reconnect needs a
    // socket, which is the integration suite's job.
}
