package com.glassmail.domain.mail

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MailboxSyncReducerTest {
    @Test
    fun `same server batch is idempotent and advances checkpoint once`() {
        val initial = MailboxLocalState(uidValidity = 11, highestKnownUid = 5)
        val batch = ServerMailboxBatch(
            uidValidity = 11,
            messages = listOf(ServerMessage(uid = 6, canonicalId = "gmail:1", flags = setOf("\\Seen"))),
        )

        val once = MailboxSyncReducer.apply(initial, batch)
        val twice = MailboxSyncReducer.apply(once, batch)

        assertEquals(6, twice.highestKnownUid)
        assertEquals(1, twice.messages.size)
        assertEquals(setOf("\\Seen"), twice.messages.getValue(6).flags)
    }

    @Test
    fun `pending read intent wins over stale unread server flags`() {
        val initial = MailboxLocalState(
            uidValidity = 11,
            highestKnownUid = 4,
            messages = mapOf(4L to LocalMessage("gmail:4", emptySet())),
            pendingMutations = listOf(LocalMutation.Read(messageUid = 4, read = true)),
        )

        val result = MailboxSyncReducer.apply(
            initial,
            ServerMailboxBatch(11, listOf(ServerMessage(4, "gmail:4", emptySet()))),
        )

        assertTrue("\\Seen" in result.messages.getValue(4).flags)
    }

    @Test
    fun `uid validity reset removes uid mapping but preserves canonical Gmail message`() {
        val initial = MailboxLocalState(
            uidValidity = 11,
            highestKnownUid = 80,
            messages = mapOf(80L to LocalMessage("gmail:preserve", setOf("\\Seen"))),
        )

        val result = MailboxSyncReducer.apply(
            initial,
            ServerMailboxBatch(22, listOf(ServerMessage(1, "gmail:preserve", emptySet()))),
        )

        assertEquals(22, result.uidValidity)
        assertFalse(80L in result.messages)
        assertEquals("gmail:preserve", result.messages.getValue(1).canonicalId)
        assertEquals(1, result.highestKnownUid)
    }

    @Test
    fun `ten thousand server messages retain one canonical mailbox mapping each`() {
        val batch = ServerMailboxBatch(
            uidValidity = 11,
            messages = (1L..10_000L).map { uid ->
                ServerMessage(uid = uid, canonicalId = "gmail:$uid", flags = emptySet())
            },
        )

        val result = MailboxSyncReducer.apply(MailboxLocalState(uidValidity = 11, highestKnownUid = 0), batch)

        assertEquals(10_000, result.messages.size)
        assertEquals(10_000L, result.highestKnownUid)
        assertEquals(10_000, result.messages.values.map(LocalMessage::canonicalId).toSet().size)
    }
}
