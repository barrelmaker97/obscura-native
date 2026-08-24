import XCTest
import LibSignalClient
@testable import ObscuraKit

/// Matches Kotlin's SignalEdgeCaseTests.kt
/// Signal protocol edge cases: PreKey address quirks and session persistence.
final class SignalEdgeCaseTests: XCTestCase {

    // MARK: - PreKey decrypt at (userId, 1) regardless of sender regId

    func testPreKeyDecryptWorksAtDefaultAddress() throws {
        // Alice encrypts at (bob, bobRegId) — the REAL registrationId
        // Bob decrypts at (alice, 1) — the DEFAULT registrationId
        // This must work because the server proxies messages without registration info

        let aliceStore = try PersistentSignalStore()
        let (aliceIdentity, _) = aliceStore.generateIdentity()

        let bobStore = try PersistentSignalStore()
        let (bobIdentity, bobRegId) = bobStore.generateIdentity()

        // Bob generates prekeys
        let bobPreKeyPrivate = PrivateKey.generate()
        try bobStore.storePreKey(
            PreKeyRecord(id: 1, publicKey: bobPreKeyPrivate.publicKey, privateKey: bobPreKeyPrivate),
            id: 1, context: NullContext()
        )

        let bobSignedPrivate = PrivateKey.generate()
        let bobSig = bobIdentity.privateKey.generateSignature(message: bobSignedPrivate.publicKey.serialize())
        try bobStore.storeSignedPreKey(
            SignedPreKeyRecord(id: 1, timestamp: UInt64(Date().timeIntervalSince1970), privateKey: bobSignedPrivate, signature: bobSig),
            id: 1, context: NullContext()
        )

        // Alice processes Bob's bundle at (bob, bobRegId)
        let bundle = try PreKeyBundle(
            registrationId: bobRegId, deviceId: bobRegId,
            prekeyId: 1, prekey: bobPreKeyPrivate.publicKey,
            signedPrekeyId: 1, signedPrekey: bobSignedPrivate.publicKey,
            signedPrekeySignature: Array(bobSig), identity: IdentityKey(publicKey: bobIdentity.publicKey)
        )
        let bobAddr = try ProtocolAddress(name: "bob", deviceId: bobRegId)
        try processPreKeyBundle(bundle, for: bobAddr, sessionStore: aliceStore, identityStore: aliceStore, context: NullContext())

        // Alice encrypts
        let cipher = try signalEncrypt(
            message: Array("test message".utf8), for: bobAddr,
            sessionStore: aliceStore, identityStore: aliceStore, context: NullContext()
        )

        // Bob decrypts at (alice, 1) — NOT alice's real regId
        let aliceAddr = try ProtocolAddress(name: "alice", deviceId: 1)
        let preKeyMsg = try PreKeySignalMessage(bytes: Array(cipher.serialize()))
        let decrypted = try signalDecryptPreKey(
            message: preKeyMsg, from: aliceAddr,
            sessionStore: bobStore, identityStore: bobStore,
            preKeyStore: bobStore, signedPreKeyStore: bobStore,
            kyberPreKeyStore: bobStore, context: NullContext()
        )
        XCTAssertEqual(String(bytes: decrypted, encoding: .utf8), "test message")
    }

    // MARK: - Signal sessions persist across store reload

    func testSignalSessionsPersistInStore() throws {
        // Create two stores, establish a session in store1, verify it's loadable
        let aliceStore = try PersistentSignalStore()
        let (aliceIdentity, _) = aliceStore.generateIdentity()

        let bobStore = try PersistentSignalStore()
        let (bobIdentity, bobRegId) = bobStore.generateIdentity()

        // Bob generates prekeys
        let bobPreKey = PrivateKey.generate()
        try bobStore.storePreKey(PreKeyRecord(id: 10, publicKey: bobPreKey.publicKey, privateKey: bobPreKey), id: 10, context: NullContext())
        let bobSpk = PrivateKey.generate()
        let bobSig = bobIdentity.privateKey.generateSignature(message: bobSpk.publicKey.serialize())
        try bobStore.storeSignedPreKey(SignedPreKeyRecord(id: 1, timestamp: UInt64(Date().timeIntervalSince1970), privateKey: bobSpk, signature: bobSig), id: 1, context: NullContext())

        // Alice processes bundle — this creates a session
        let bundle = try PreKeyBundle(
            registrationId: bobRegId, deviceId: bobRegId,
            prekeyId: 10, prekey: bobPreKey.publicKey,
            signedPrekeyId: 1, signedPrekey: bobSpk.publicKey,
            signedPrekeySignature: Array(bobSig), identity: IdentityKey(publicKey: bobIdentity.publicKey)
        )
        let addr = try ProtocolAddress(name: "bob", deviceId: bobRegId)
        try processPreKeyBundle(bundle, for: addr, sessionStore: aliceStore, identityStore: aliceStore, context: NullContext())

        // Session should be loadable
        let loaded = try aliceStore.loadSession(for: addr, context: NullContext())
        XCTAssertNotNil(loaded, "Session should persist in store")
    }
}
