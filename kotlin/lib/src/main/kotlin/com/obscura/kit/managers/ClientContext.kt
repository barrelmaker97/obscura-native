package com.obscura.kit.managers

import com.obscura.kit.crypto.SignalStore
import com.obscura.kit.db.ObscuraDatabase
import com.obscura.kit.messaging.Messenger
import com.obscura.kit.network.APIClient
import com.obscura.kit.stores.*

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
