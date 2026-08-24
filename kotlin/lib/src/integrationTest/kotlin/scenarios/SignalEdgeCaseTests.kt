package scenarios

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.MethodOrderer
import org.junit.jupiter.api.Order
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestMethodOrder

/**
 * Signal edge cases tested via public API only.
 * Register, befriend, and exchange encrypted messages.
 * No direct SignalStore access.
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation::class)
class SignalEdgeCaseTests {

    companion object {
        private var serverUp = false

        @BeforeAll @JvmStatic fun check() {
            serverUp = checkServer()
        }
    }

    private fun need() = assumeTrue(serverUp)

    @Test @Order(1)
    fun `Basic Signal encrypt-decrypt works via public API`() = runBlocking {
        need()

        val alice = registerAndConnect("sig_alice")
        val bob = registerAndConnect("sig_bob")

        becomeFriends(alice, bob)
        sendAndVerify(alice, bob, "Signal test message 1")
        sendAndVerify(bob, alice, "Signal test reply 1")



        alice.disconnect(); bob.disconnect()
    }
}
