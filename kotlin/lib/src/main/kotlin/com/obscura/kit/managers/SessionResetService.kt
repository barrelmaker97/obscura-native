package com.obscura.kit.managers

import obscura.client.v1.Client.ClientMessage

/** Signal session resets. */
internal class SessionResetService(
    private val ctx: ClientContext
) {
    private val signalStore get() = ctx.signalStore
    private val messenger get() = ctx.messenger
    private val friends get() = ctx.friends
    private val messageSender get() = ctx.messageSender

    suspend fun resetSessionWith(targetUserId: String, reason: String = "manual") {
        // Sessions are keyed on device UUID, so clear every session for the user.
        clearSessionsWithUser(targetUserId)

        val msg = ClientMessage.newBuilder()
            .setSessionReset(obscura.client.v1.sessionReset { this.reason = reason })
            .setTimestamp(System.currentTimeMillis()).build()

        messageSender.sendToAllDevices(targetUserId, msg)

        // Delete the session that was just built to send the reset message.
        // This forces the next send to use a fresh PreKey exchange,
        // which the receiver can handle after they also cleared their session.
        clearSessionsWithUser(targetUserId)
    }

    private fun clearSessionsWithUser(targetUserId: String) {
        messenger.getDeviceIdsForUser(targetUserId).forEach { signalStore.deleteAllSessions(it) }
    }

    suspend fun resetAllSessions(reason: String = "manual") {
        val allFriends = friends.getAccepted()
        for (friend in allFriends) {
            try { resetSessionWith(friend.userId, reason) } catch (e: Exception) {
                // Best-effort: one friend's session reset must not abort resetting the rest.
            }
        }
    }
}
