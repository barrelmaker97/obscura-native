package dev.barrelmaker.obscura.kit.managers

import dev.barrelmaker.obscura.kit.crypto.SignalStore
import dev.barrelmaker.obscura.kit.db.ObscuraDatabase
import dev.barrelmaker.obscura.kit.messaging.Messenger
import dev.barrelmaker.obscura.kit.network.APIClient
import dev.barrelmaker.obscura.kit.stores.*

internal class ClientContext(
    val session: ClientSession,
    val api: APIClient,
    val signalStore: SignalStore,
    val messenger: Messenger,
    val friends: FriendStore,
    val devices: DeviceStore,
    val db: ObscuraDatabase
) {
    lateinit var messageSender: MessageSender
}
