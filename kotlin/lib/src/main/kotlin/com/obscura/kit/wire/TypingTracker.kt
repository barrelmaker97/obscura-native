package com.obscura.kit.wire

import com.obscura.kit.TypingState
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** In-memory, auto-expiring typing events carried by `TypingSignal`. */
internal class TypingTracker {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val activeByContext = MutableStateFlow<Map<String, Set<TypingEvent>>>(emptyMap())

    data class TypingEvent(
        val senderUserId: String,
        val senderDeviceId: String,
        val senderDisplayName: String,
        val expiresAt: Long,
    )

    private val lastSent = mutableMapOf<String, Long>()
    private val throttleMutex = Mutex()

    suspend fun shouldSend(contextId: String, state: TypingState, senderDeviceId: String): Boolean {
        val throttleKey = "$contextId:$state:$senderDeviceId"
        val now = System.currentTimeMillis()
        return throttleMutex.withLock {
            val last = lastSent[throttleKey] ?: 0L
            if (now - last < THROTTLE_MS) {
                false
            } else {
                lastSent[throttleKey] = now
                true
            }
        }
    }

    fun receive(
        contextId: String,
        senderUserId: String,
        senderDeviceId: String,
        senderDisplayName: String,
    ) {
        val expiresAt = System.currentTimeMillis() + EXPIRE_MS
        val event = TypingEvent(senderUserId, senderDeviceId, senderDisplayName, expiresAt)

        // `update {}`, not read-then-assign: two envelopes for the same conversation are routed
        // concurrently, and `value = value.toMutableMap().also { ... }` loses one of them outright.
        activeByContext.update { current ->
            val existing = current[contextId].orEmpty().filterNot {
                it.senderDeviceId == senderDeviceId
            }
            current + (contextId to (existing + event).toSet())
        }

        scope.launch {
            delay(EXPIRE_MS + 100) // small buffer
            val now = System.currentTimeMillis()
            val signals = activeByContext.value[contextId] ?: return@launch
            val entry = signals.find { it.senderDeviceId == senderDeviceId } ?: return@launch
            if (entry.expiresAt <= now) {
                clear(contextId, senderDeviceId)
            }
        }
    }

    fun clear(contextId: String, senderDeviceId: String) {
        activeByContext.update { current ->
            val existing = current[contextId]
                ?.filterNot { it.senderDeviceId == senderDeviceId }
                ?: return@update current
            if (existing.isEmpty()) current - contextId
            else current + (contextId to existing.toSet())
        }
    }

    fun observe(contextId: String): Flow<List<String>> {
        return activeByContext.map { contexts ->
            val now = System.currentTimeMillis()
            (contexts[contextId] ?: emptySet())
                .filter { it.expiresAt > now }
                .map { it.senderDisplayName }
        }
    }

    fun shutdown() {
        scope.cancel()
        activeByContext.value = emptyMap()
    }

    companion object {
        const val EXPIRE_MS = 3000L
        private const val THROTTLE_MS = 2000L
    }
}
