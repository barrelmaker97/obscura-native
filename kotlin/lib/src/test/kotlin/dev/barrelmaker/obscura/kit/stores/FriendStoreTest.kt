package dev.barrelmaker.obscura.kit.stores

import dev.barrelmaker.obscura.kit.newInMemoryDatabase
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/**
 * FriendStore is the source of truth for the friend list and for a friend's devices. Tests
 * exercise the JSON-encoded `devices` blob through the public API to catch silent parse failures
 * (`parseDevices` swallows errors and returns emptyList — the kind of failure that breaks message
 * delivery without throwing).
 */
class FriendStoreTest {

    private fun newDomain() = FriendStore(newInMemoryDatabase())

    @Test
    fun `add then get returns the friend`() = runTest {
        val d = newDomain()
        d.add("u1", "alice", FriendStatus.ACCEPTED)
        val f = d.get("u1")!!
        assertEquals("alice", f.username)
        assertEquals(FriendStatus.ACCEPTED, f.status)
    }

    @Test
    fun `get returns null for a user who was never added`() = runTest {
        assertNull(newDomain().get("nope"))
    }

    @Test
    fun `getAccepted filters out pending friends`() = runTest {
        val d = newDomain()
        d.add("u1", "alice", FriendStatus.ACCEPTED)
        d.add("u2", "bob", FriendStatus.PENDING_SENT)
        d.add("u3", "carol", FriendStatus.PENDING_RECEIVED)

        val accepted = d.getAccepted()
        assertEquals(setOf("alice"), accepted.map { it.username }.toSet())
    }

    @Test
    fun `add with devices round-trips the device list`() = runTest {
        val d = newDomain()
        val devices = listOf(
            FriendDeviceInfo(id = "dev-1", name = "Pixel"),
            FriendDeviceInfo(id = "dev-2", name = "iPhone")
        )
        d.add("u1", "alice", FriendStatus.ACCEPTED, devices)

        val loaded = d.get("u1")!!
        assertEquals(2, loaded.devices.size)
        val byId = loaded.devices.associateBy { it.id }
        assertEquals("Pixel", byId["dev-1"]?.name)
        assertEquals("iPhone", byId["dev-2"]?.name)
    }

    @Test
    fun `updateDevices replaces the device list while preserving username and status`() = runTest {
        val d = newDomain()
        d.add("u1", "alice", FriendStatus.ACCEPTED, listOf(
            FriendDeviceInfo("dev-x", "Old")
        ))
        d.updateDevices("u1", listOf(
            FriendDeviceInfo("dev-y", "New")
        ))

        val loaded = d.get("u1")!!
        assertEquals("alice", loaded.username, "Username must survive device update")
        assertEquals(FriendStatus.ACCEPTED, loaded.status)
        assertEquals(setOf("dev-y"), loaded.devices.map { it.id }.toSet())
    }

    @Test
    fun `updateDevices on unknown user is a no-op`() = runTest {
        val d = newDomain()
        d.updateDevices("never-added", listOf(
            FriendDeviceInfo("dev", "X")
        ))
        assertNull(d.get("never-added"), "Update on unknown user must NOT create a phantom friend row")
    }

    @Test
    fun `updateStatus promotes in place without touching the name or devices`() = runTest {
        val d = newDomain()
        d.add("u1", "alice", FriendStatus.PENDING_SENT, listOf(FriendDeviceInfo("dev", "P")))

        d.updateStatus("u1", FriendStatus.ACCEPTED)

        val loaded = d.get("u1")!!
        assertEquals(FriendStatus.ACCEPTED, loaded.status)
        assertEquals("alice", loaded.username)
        assertEquals(listOf("dev"), loaded.devices.map { it.id })
    }

    @Test
    fun `remove deletes the friend`() = runTest {
        val d = newDomain()
        d.add("u1", "alice", FriendStatus.ACCEPTED)
        d.add("u2", "bob", FriendStatus.ACCEPTED)
        d.remove("u1")

        assertNull(d.get("u1"))
        assertEquals("bob", d.get("u2")!!.username)
    }

    @Test
    fun `exportAll and importAll round-trip`() = runTest {
        val d1 = newDomain()
        d1.add("u1", "alice", FriendStatus.ACCEPTED, listOf(
            FriendDeviceInfo("dev", "Phone")
        ))
        d1.add("u2", "bob", FriendStatus.PENDING_SENT)
        val exported = d1.exportAll()

        val d2 = newDomain()
        d2.importAll(exported)

        assertEquals(FriendStatus.ACCEPTED, d2.get("u1")?.status)
        assertEquals(FriendStatus.PENDING_SENT, d2.get("u2")?.status)
    }

    @Test
    fun `a friend stored with no devices loads as an empty list, not a throw`() = runTest {
        // parseDevices swallows malformed JSON and returns emptyList; the observable contract is
        // that a friend always loads, with devices = [] in the worst case.
        val d = newDomain()
        d.add("u1", "alice", FriendStatus.ACCEPTED, emptyList())
        assertEquals(0, d.get("u1")!!.devices.size)
    }
}
