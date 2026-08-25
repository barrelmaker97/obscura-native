package dev.barrelmaker.obscura.kit.managers

import dev.barrelmaker.obscura.kit.crypto.toBase64
import dev.barrelmaker.obscura.kit.managers.SignalKeyUtils.toApiJson
import dev.barrelmaker.obscura.kit.network.UploadDeviceKeysRequest
import obscura.client.v1.Client.ClientMessage

/** Device announcements, link approval, and takeover. */
internal class DeviceManager(
    private val ctx: ClientContext,
    private val announceDevicesCallback: suspend () -> Unit
) {
    private val session get() = ctx.session
    private val api get() = ctx.api
    private val signalStore get() = ctx.signalStore
    private val messenger get() = ctx.messenger
    private val friends get() = ctx.friends
    private val devices get() = ctx.devices
    private val messageSender get() = ctx.messageSender

    suspend fun announceDevices() {
        val ownDevices = devices.getOwnDevices()
        val msg = ClientMessage.newBuilder()
            .setTimestamp(System.currentTimeMillis())
            .setDeviceAnnounce(obscura.client.v1.deviceAnnounce {
                for (d in ownDevices) {
                    this.devices.add(obscura.client.v1.deviceInfo {
                        id = d.deviceId
                        name = d.deviceName
                    })
                }
            }).build()

        for (friend in friends.getAccepted()) {
            messageSender.sendToAllDevices(friend.userId, msg)
        }
    }

    suspend fun approveLink(newDeviceId: String, challengeResponse: ByteArray) {
        // Include the device being approved so the recipient can persist a complete own-device
        // registry. Resolve its human name from the server before shipping the list.
        val newDeviceName = try {
            val serverDevices = api.listDevices()
            (0 until serverDevices.length())
                .map { serverDevices.getJSONObject(it) }
                .firstOrNull { it.getString("deviceId") == newDeviceId }
                ?.optString("name", "Device")
        } catch (e: Exception) { null } ?: "Device"
        devices.addOwnDevice(dev.barrelmaker.obscura.kit.stores.OwnDeviceData(
            deviceId = newDeviceId,
            deviceName = newDeviceName
        ))

        val ownDeviceList = devices.getOwnDevices()
        val friendsExportStr = friends.exportAll()

        val msg = ClientMessage.newBuilder()
            .setTimestamp(System.currentTimeMillis())
            .setDeviceLinkApproval(obscura.client.v1.deviceLinkApproval {
                this.challengeResponse = com.google.protobuf.ByteString.copyFrom(challengeResponse)

                for (d in ownDeviceList) {
                    this.ownDevices.add(obscura.client.v1.deviceInfo {
                        id = d.deviceId
                        name = d.deviceName
                    })
                }

                friendsExport = com.google.protobuf.ByteString.copyFrom(friendsExportStr.toByteArray())
            }).build()

        // Ensure we can encrypt for the new device (fetch its prekey bundle)
        if (messenger.deviceMap(newDeviceId) == null) {
            messenger.fetchPreKeyBundles(requireNotNull(session.userId))
        }
        messenger.queueMessage(newDeviceId, msg, session.userId)
        messenger.flushMessages()

        announceDevicesCallback()
    }

    suspend fun takeoverDevice() {
        val (identityKeyPair, regId) = signalStore.generateIdentity()

        val signedPreKey = SignalKeyUtils.generateSignedPreKey(signalStore, identityKeyPair, 1)
        val oneTimePreKeys = SignalKeyUtils.generateOneTimePreKeys(signalStore, 1, 100)

        api.uploadDeviceKeys(UploadDeviceKeysRequest(
            identityKey = identityKeyPair.publicKey.serialize().toBase64(),
            registrationId = regId,
            signedPreKey = signedPreKey.toApiJson(),
            oneTimePreKeys = oneTimePreKeys.toApiJson()
        ))

        // The identity key changed, so clear every device-UUID session and force fresh prekey
        // exchanges on the next send.
        for (friend in friends.getAccepted()) {
            messenger.getDeviceIdsForUser(friend.userId).forEach { signalStore.deleteAllSessions(it) }
        }

        messenger.mapDevice(
            requireNotNull(session.deviceId) { "deviceId not set - call register/login first" },
            requireNotNull(session.userId) { "userId not set - call register/login first" },
        )
    }
}
