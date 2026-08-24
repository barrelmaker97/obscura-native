import Foundation
import CryptoKit

public struct EncryptedAttachment: Sendable {
    public let ciphertext: Data
    public let contentKey: Data
    public let nonce: Data
}

/// AES-256-GCM encryption for attachments.
/// Matches the web client's aes.js and Kotlin's AttachmentCrypto.kt.
///
/// Flow:
///   1. Generate random 32-byte content key + 12-byte nonce
///   2. Encrypt plaintext with AES-256-GCM
///   3. Upload ciphertext to server (server never sees plaintext)
///   4. Embed contentKey + nonce in the application's encrypted APP_ENTRY payload
///   5. Recipient downloads ciphertext and decrypts with authenticated AES-GCM
public enum AttachmentCrypto {

    private static let gcmTagSize = 16

    public static func encrypt(_ plaintext: Data) throws -> EncryptedAttachment {
        let contentKey = SymmetricKey(size: .bits256)
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintext, using: contentKey, nonce: nonce)

        // combined = nonce (12) + ciphertext + tag (16), but we store nonce separately
        // so output is just ciphertext + tag to match Kotlin's Cipher.doFinal() output
        return EncryptedAttachment(
            ciphertext: sealed.ciphertext + sealed.tag,
            contentKey: contentKey.withUnsafeBytes { Data($0) },
            nonce: Data(nonce)
        )
    }

    public static func decrypt(_ ciphertext: Data, contentKey: Data, nonce: Data) throws -> Data {
        let key = SymmetricKey(data: contentKey)
        // Reconstruct combined representation: nonce + ciphertext + tag
        var combined = Data(nonce)
        combined.append(ciphertext)
        let sealed = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealed, using: key)
    }
}
