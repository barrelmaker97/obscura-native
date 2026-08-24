package com.obscura.kit.stores

import com.obscura.kit.db.ObscuraDatabase
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class DeviceIdentityData(
    val deviceId: String,
)

data class OwnDeviceData(
    val deviceId: String,
    val deviceName: String,
)

/**
 * DeviceStore - Confined coroutines. Device identity + own device list.
 */
class DeviceStore internal constructor(private val db: ObscuraDatabase) {
    private val dispatcher: CoroutineDispatcher = Dispatchers.Default.limitedParallelism(1)

    suspend fun storeIdentity(identity: DeviceIdentityData) = withContext(dispatcher) {
        db.deviceQueries.insertIdentity(identity.deviceId)
    }

    suspend fun getIdentity(): DeviceIdentityData? = withContext(dispatcher) {
        val row = db.deviceQueries.selectIdentity().executeAsOneOrNull() ?: return@withContext null
        DeviceIdentityData(deviceId = row.device_id)
    }

    suspend fun addOwnDevice(device: OwnDeviceData) = withContext(dispatcher) {
        db.deviceQueries.insertDevice(device.deviceId, device.deviceName)
    }

    suspend fun getOwnDevices(): List<OwnDeviceData> = withContext(dispatcher) {
        db.deviceQueries.selectOwnDevices().executeAsList().map { row ->
            OwnDeviceData(
                deviceId = row.device_id,
                deviceName = row.device_name,
            )
        }
    }

    suspend fun setOwnDevices(devices: List<FriendDeviceInfo>) = withContext(dispatcher) {
        db.deviceQueries.deleteAllDevices()
        for (d in devices) {
            db.deviceQueries.insertDevice(d.id, d.name)
        }
    }

    suspend fun getSelfSyncTargets(): List<String> = withContext(dispatcher) {
        db.deviceQueries.selectOwnDevices().executeAsList().map { it.device_id }
    }
}
