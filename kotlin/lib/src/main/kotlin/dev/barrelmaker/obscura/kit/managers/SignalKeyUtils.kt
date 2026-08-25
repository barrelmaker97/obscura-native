package dev.barrelmaker.obscura.kit.managers

import dev.barrelmaker.obscura.kit.crypto.SignalStore
import dev.barrelmaker.obscura.kit.crypto.toBase64
import dev.barrelmaker.obscura.kit.network.OneTimePreKeyJson
import dev.barrelmaker.obscura.kit.network.SignedPreKeyJson
import org.signal.libsignal.protocol.IdentityKeyPair
import org.signal.libsignal.protocol.ecc.Curve
import org.signal.libsignal.protocol.state.PreKeyRecord
import org.signal.libsignal.protocol.state.SignedPreKeyRecord

/**
 * Shared Signal key generation helpers used by auth and device takeover.
 */
internal object SignalKeyUtils {

    fun generateSignedPreKey(signalStore: SignalStore, identityKeyPair: IdentityKeyPair, id: Int): SignedPreKeyRecord {
        val keyPair = Curve.generateKeyPair()
        val signature = Curve.calculateSignature(identityKeyPair.privateKey, keyPair.publicKey.serialize())
        val record = SignedPreKeyRecord(id, System.currentTimeMillis(), keyPair, signature)
        signalStore.storeSignedPreKey(id, record)
        return record
    }

    fun generateOneTimePreKeys(signalStore: SignalStore, startId: Int, count: Int): List<PreKeyRecord> {
        return (startId until startId + count).map { id ->
            val keyPair = Curve.generateKeyPair()
            val record = PreKeyRecord(id, keyPair)
            signalStore.storePreKey(id, record)
            record
        }
    }

    fun SignedPreKeyRecord.toApiJson() = SignedPreKeyJson(
        keyId = id,
        publicKey = keyPair.publicKey.serialize().toBase64(),
        signature = signature.toBase64()
    )

    fun List<PreKeyRecord>.toApiJson() = map { pk ->
        OneTimePreKeyJson(keyId = pk.id, publicKey = pk.keyPair.publicKey.serialize().toBase64())
    }
}
