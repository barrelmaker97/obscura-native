package scenarios

import com.obscura.kit.AuthState
import com.obscura.kit.ConnectionState
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.Test

class AttachmentTests {
    @Test
    fun `upload and download attachment content matches`() = runBlocking {
        assumeTrue(checkServer())

        val alice = registerAndConnect("a6")
        assertEquals(AuthState.AUTHENTICATED, alice.authState.value)
        assertEquals(ConnectionState.CONNECTED, alice.connectionState.value)

        val payload = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte()) + ByteArray(200)
        val (attachmentId, expiresAt) = alice.uploadAttachment(payload)
        assertTrue(attachmentId.isNotEmpty())
        assertTrue(expiresAt > 0)

        val downloaded = alice.downloadAttachment(attachmentId)
        assertArrayEquals(payload, downloaded)

        alice.disconnect()
        assertEquals(ConnectionState.DISCONNECTED, alice.connectionState.value)
    }
}
