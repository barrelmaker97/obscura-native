package dev.barrelmaker.obscura.kit.crypto

import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * AES-256-GCM encryption for attachments.
 * Matches the web client's aes.js — encrypt before upload, decrypt after download.
 *
 * Flow:
 *   1. Generate random 32-byte content key + 12-byte nonce
 *   2. Encrypt plaintext with AES-256-GCM
 *   3. Upload ciphertext to server (server never sees plaintext)
 *   4. Embed contentKey + nonce in the application's encrypted APP_ENTRY payload
 *   5. Recipient downloads ciphertext and decrypts with authenticated AES-GCM
 */
object AttachmentCrypto {

    private const val KEY_SIZE = 32        // AES-256
    private const val NONCE_SIZE = 12      // GCM standard
    private const val GCM_TAG_BITS = 128   // 16-byte auth tag
    private val csprng = SecureRandom()

    data class EncryptedAttachment(
        val ciphertext: ByteArray,
        val contentKey: ByteArray,
        val nonce: ByteArray,
    )

    /**
     * Encrypt content with AES-256-GCM.
     * Returns ciphertext + key material for the recipient.
     */
    fun encrypt(plaintext: ByteArray): EncryptedAttachment {
        val contentKey = ByteArray(KEY_SIZE).also { csprng.nextBytes(it) }
        val nonce = ByteArray(NONCE_SIZE).also { csprng.nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(contentKey, "AES"), GCMParameterSpec(GCM_TAG_BITS, nonce))
        val ciphertext = cipher.doFinal(plaintext)

        return EncryptedAttachment(
            ciphertext = ciphertext,
            contentKey = contentKey,
            nonce = nonce,
        )
    }

    /**
     * Decrypt content with AES-256-GCM.
     * Throws on a wrong key or tampered ciphertext.
     */
    fun decrypt(ciphertext: ByteArray, contentKey: ByteArray, nonce: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(contentKey, "AES"), GCMParameterSpec(GCM_TAG_BITS, nonce))
        return cipher.doFinal(ciphertext)
    }
}
