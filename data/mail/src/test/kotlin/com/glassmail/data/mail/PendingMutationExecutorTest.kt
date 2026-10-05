package com.glassmail.data.mail

import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.MutationState
import com.glassmail.core.database.PendingMutationDao
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.database.SyncCheckpointEntity
import com.glassmail.core.database.SyncDao
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.imap.ImapException
import com.glassmail.core.imap.ImapMutation
import com.glassmail.core.security.CredentialStore
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.coVerifyOrder
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue

class PendingMutationExecutorTest {
    private val database = mockk<GlassMailDatabase>()
    private val mutations = mockk<PendingMutationDao>()
    private val mail = mockk<MailDao>()
    private val sync = mockk<SyncDao>()
    private val imap = mockk<GmailImapClient>()
    private val credentials = object : CredentialStore {
        override suspend fun store(accountId: String, credential: CharArray) = Unit
        override suspend fun delete(accountId: String) = Unit
        override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T =
            block(charArrayOf('p'))
    }
    private val mutation = PendingMutationEntity(
        mutationId = "queued", accountId = "a", mailboxId = "a:INBOX", messageId = "gmail:a:canonical",
        targetUid = 7, type = "ARCHIVE", payload = null, retryCount = 3, createdAtEpochMillis = 0,
    )
    private val executor = PendingMutationExecutor(database, credentials, imap) { 10_000L }

    init {
        every { database.pendingMutationDao() } returns mutations
        every { database.mailDao() } returns mail
        every { database.syncDao() } returns sync
        coEvery { mutations.activeForAccount("a") } returns listOf(mutation)
        coEvery { sync.checkpoint("a:INBOX") } returns SyncCheckpointEntity("a:INBOX", "a", 11, 500, 0, null)
        coEvery { mutations.updateState(any(), any(), any(), any()) } returns Unit
        coEvery { mutations.delete(any()) } returns Unit
        coEvery { mutations.claim(any()) } returns 1
        coEvery { mutations.recoverInFlight(any()) } returns Unit
    }

    @Test fun `SELECT mismatch leaves mutation pending without incrementing retries`() = runTest {
        coEvery { imap.applyInboxMutations("me@example.com", any(), any(), 11) } throws
            ImapException.UidValidityChanged(11, 22)

        executor.flush("a", "me@example.com")

        coVerifyOrder {
            mutations.claim("queued")
            imap.applyInboxMutations("me@example.com", any(), listOf(ImapMutation(7, "ARCHIVE")), 11)
            mutations.updateState("queued", MutationState.PENDING, 3, "UIDVALIDITY_CHANGED")
        }
        coVerify(exactly = 0) { mutations.delete(any()) }
        coVerify(exactly = 0) { mutations.updateState(any(), MutationState.FAILED_PERMANENT, any(), any()) }
    }

    @Test fun `matching namespace sends captured UID with checkpoint validity and acknowledges`() = runTest {
        coEvery { imap.applyInboxMutations(any(), any(), any(), 11) } returns Unit

        executor.flush("a", "me@example.com")

        coVerify(exactly = 1) {
            imap.applyInboxMutations("me@example.com", any(), listOf(ImapMutation(7, "ARCHIVE")), 11)
            mutations.delete("queued")
        }
    }

    @Test fun `missing checkpoint never sends a captured UID`() = runTest {
        coEvery { sync.checkpoint("a:INBOX") } returns null

        executor.flush("a", "me@example.com")

        coVerify(exactly = 1) { mutations.updateState("queued", MutationState.PENDING, 3, "UIDVALIDITY_CHANGED") }
        coVerify(exactly = 0) { imap.applyInboxMutations(any(), any(), any(), any()) }
    }

    @Test fun `missing checkpoint also defers membership UIDs until sync`() = runTest {
        coEvery { mutations.activeForAccount("a") } returns listOf(mutation.copy(targetUid = null))
        coEvery { sync.checkpoint("a:INBOX") } returns null

        executor.flush("a", "me@example.com")

        coVerify(exactly = 1) { mutations.updateState("queued", MutationState.PENDING, 3, "UIDVALIDITY_CHANGED") }
        coVerify(exactly = 0) { imap.applyInboxMutations(any(), any(), any(), any()) }
    }

    @Test fun `reset target is re-resolved through fresh canonical inbox membership`() = runTest {
        coEvery { mutations.activeForAccount("a") } returns listOf(mutation.copy(targetUid = null))
        coEvery { sync.checkpoint("a:INBOX") } returns SyncCheckpointEntity("a:INBOX", "a", 22, 1000, 0, null)
        coEvery { mail.membershipsForMessage(mutation.messageId) } returns listOf(
            MailboxMessageEntity("a:Other", 7, mutation.messageId, "", ""),
            MailboxMessageEntity("a:INBOX", 42, mutation.messageId, "", ""),
        )
        coEvery { imap.applyInboxMutations(any(), any(), any(), 22) } returns Unit

        executor.flush("a", "me@example.com")

        coVerify(exactly = 1) {
            imap.applyInboxMutations("me@example.com", any(), listOf(ImapMutation(42, "ARCHIVE")), 22)
        }
    }

    @Test fun `missing reset message remains unresolved and sends no UID`() = runTest {
        coEvery { mutations.activeForAccount("a") } returns listOf(mutation.copy(targetUid = null))
        coEvery { mail.membershipsForMessage(mutation.messageId) } returns emptyList()

        executor.flush("a", "me@example.com")

        coVerify(exactly = 1) { mutations.updateState("queued", MutationState.FAILED_PERMANENT, 3, "MISSING_UID") }
        coVerify(exactly = 0) { mutations.delete(any()) }
        coVerify(exactly = 0) { imap.applyInboxMutations(any(), any(), any(), any()) }
    }
    @Test fun `transport failure stops newer intent and retry finishes read then unread in order`() = runTest {
        val rows = linkedMapOf(
            "read" to mutation.copy(mutationId = "read", type = "MARK_READ", retryCount = 0),
            "unread" to mutation.copy(mutationId = "unread", type = "MARK_UNREAD", retryCount = 0),
        )
        useRows(rows)
        var fail = true
        var serverRead = false
        val sent = mutableListOf<String>()
        coEvery { imap.applyInboxMutations(any(), any(), any(), any()) } coAnswers {
            val type = thirdArg<List<ImapMutation>>().single().type
            sent.add(type)
            if (fail) throw ImapException.Transport(java.io.IOException("offline"))
            serverRead = type == "MARK_READ"
        }
        executor.flush("a", "me@example.com")
        assertEquals(listOf("MARK_READ"), sent)
        assertEquals(MutationState.PENDING, rows["read"]?.state)
        assertEquals("NETWORK", rows["read"]?.lastErrorCode)
        assertEquals(1, rows["read"]?.retryCount)
        assertEquals(0, rows["unread"]?.retryCount)
        fail = false
        executor.flush("a", "me@example.com")
        assertEquals(listOf("MARK_READ", "MARK_READ", "MARK_UNREAD"), sent)
        assertFalse(serverRead)
        assertTrue(rows.isEmpty())
    }

    @Test fun `authentication failure remains pending and corrected password can flush it`() = runTest {
        val rows = linkedMapOf("queued" to mutation)
        useRows(rows)
        coEvery { imap.applyInboxMutations(any(), any(), any(), any()) } throws ImapException.Authentication()
        executor.flush("a", "me@example.com")
        assertEquals(MutationState.PENDING, rows["queued"]?.state)
        assertEquals("AUTHENTICATION", rows["queued"]?.lastErrorCode)
        coEvery { imap.applyInboxMutations(any(), any(), any(), any()) } returns Unit
        executor.flush("a", "me@example.com")
        assertTrue(rows.isEmpty())
    }

    @Test fun `Undo deletion after enumeration prevents server archive`() = runTest {
        val rows = linkedMapOf("queued" to mutation)
        useRows(rows)
        coEvery { mutations.activeForAccount("a") } coAnswers {
            val detached = rows.values.toList()
            rows.clear() // Undo commits after the SELECT, before the claim.
            detached
        }
        executor.flush("a", "me@example.com")
        coVerify(exactly = 0) { imap.applyInboxMutations(any(), any(), any(), any()) }
        assertTrue(rows.isEmpty())
    }

    @Test fun `archive grace blocks later actions in that thread until Undo expires`() = runTest {
        var now = 3_000L
        val rows = linkedMapOf(
            "queued" to mutation.copy(payload = "gmail-thread:123:archive:ARCHIVE"),
            "newer" to mutation.copy(mutationId = "newer", messageId = "gmail:a:second", type = "STAR", payload = "gmail-thread:123:star:STAR"),
        )
        useRows(rows)
        val sent = mutableListOf<String>()
        coEvery { imap.applyThreadMutation(any(), any(), any(), any()) } coAnswers { sent.add(arg(3)); Unit }
        val timed = PendingMutationExecutor(database, credentials, imap) { now }
        timed.flush("a", "me@example.com")
        assertTrue(sent.isEmpty())
        assertEquals(2, rows.size)
        now = 6_000L
        timed.flush("a", "me@example.com")
        assertEquals(listOf("ARCHIVE", "STAR"), sent)
        assertTrue(rows.isEmpty())
        coVerify(exactly = 0) { imap.applyInboxMutations(any(), any(), any(), any()) }
    }

    @Test fun `server rejection blocks newer target intent across flushes until retry`() = runTest {
        val rows = linkedMapOf(
            "old" to mutation.copy(mutationId = "old", type = "MARK_READ"),
            "new" to mutation.copy(mutationId = "new", type = "MARK_UNREAD"),
        )
        useRows(rows)
        val sent = mutableListOf<String>()
        var reject = true
        coEvery { imap.applyInboxMutations(any(), any(), any(), any()) } coAnswers {
            sent.add(thirdArg<List<ImapMutation>>().single().type)
            if (reject) throw ImapException.Protocol("NO")
        }
        executor.flush("a", "me@example.com")
        assertEquals(MutationState.FAILED_PERMANENT, rows["old"]?.state)
        assertEquals("SERVER_REJECTED", rows["old"]?.lastErrorCode)
        executor.flush("a", "me@example.com")
        assertEquals(listOf("MARK_READ"), sent)
        rows["old"] = rows.getValue("old").copy(state = MutationState.PENDING)
        reject = false
        executor.flush("a", "me@example.com")
        assertEquals(listOf("MARK_READ", "MARK_READ", "MARK_UNREAD"), sent)
        assertTrue(rows.isEmpty())
    }


    @Test fun `conversation batch claims executes and acknowledges every local member together`() = runTest {
        val rows = linkedMapOf(
            "queued" to mutation.copy(payload = "gmail-thread:123:batch:ARCHIVE", targetUid = null),
            "second" to mutation.copy(mutationId = "second", messageId = "gmail:a:2", payload = "gmail-thread:123:batch:ARCHIVE", targetUid = null),
        )
        useRows(rows)
        coEvery { sync.checkpoint(any()) } returns null
        var applied = 0
        coEvery { imap.applyThreadMutation(any(), any(), "123", "ARCHIVE") } coAnswers {
            assertEquals(listOf(MutationState.IN_FLIGHT, MutationState.IN_FLIGHT), rows.values.map { it.state })
            applied++
        }
        executor.flush("a", "me@example.com")
        assertEquals(1, applied)
        assertTrue(rows.isEmpty())
        coVerify(exactly = 0) { imap.applyInboxMutations(any(), any(), any(), any()) }
    }

    @Test fun `rejected conversation marks the entire action failed for Retry or Dismiss`() = runTest {
        val rows = linkedMapOf(
            "queued" to mutation.copy(payload = "gmail-thread:123:batch:ARCHIVE"),
            "second" to mutation.copy(mutationId = "second", messageId = "gmail:a:2", payload = "gmail-thread:123:batch:ARCHIVE"),
        )
        useRows(rows)
        coEvery { imap.applyThreadMutation(any(), any(), any(), any()) } throws ImapException.Protocol("NO")
        executor.flush("a", "me@example.com")
        assertEquals(listOf(MutationState.FAILED_PERMANENT, MutationState.FAILED_PERMANENT), rows.values.map { it.state })
        assertTrue(rows.values.all { it.lastErrorCode == "SERVER_REJECTED" })
        coVerify(exactly = 1) { imap.applyThreadMutation(any(), any(), any(), any()) }
    }


    @Test fun `Undo removes a detached conversation batch before its atomic claim`() = runTest {
        val rows = linkedMapOf(
            "queued" to mutation.copy(payload = "gmail-thread:123:batch:ARCHIVE"),
            "second" to mutation.copy(mutationId = "second", messageId = "gmail:a:2", payload = "gmail-thread:123:batch:ARCHIVE"),
        )
        useRows(rows)
        coEvery { mutations.activeForAccount("a") } coAnswers {
            val detached = rows.values.toList()
            rows.clear()
            detached
        }
        executor.flush("a", "me@example.com")
        coVerify(exactly = 0) { imap.applyThreadMutation(any(), any(), any(), any()) }
        assertTrue(rows.isEmpty())
    }

    private fun useRows(rows: LinkedHashMap<String, PendingMutationEntity>) {
        coEvery { mutations.activeForAccount("a") } coAnswers { rows.values.toList() }
        coEvery { mutations.claim(any()) } coAnswers {
            val id = firstArg<String>()
            val row = rows[id]
            if (row?.state != MutationState.PENDING) 0 else {
                rows[id] = row.copy(state = MutationState.IN_FLIGHT)
                1
            }
        }
        coEvery { mutations.updateState(any(), any(), any(), any()) } coAnswers {
            val id = firstArg<String>()
            rows[id]?.let { rows[id] = it.copy(state = arg(1), retryCount = arg(2), lastErrorCode = arg(3)) }
            Unit
        }
        coEvery { mutations.delete(any()) } coAnswers { rows.remove(firstArg<String>()); Unit }
        coEvery { mutations.claimThreadAction(any()) } coAnswers {
            val payload = firstArg<String>()
            val claimed = rows.values.filter { it.payload == payload && it.state == MutationState.PENDING }
            claimed.forEach { rows[it.mutationId] = it.copy(state = MutationState.IN_FLIGHT) }
            claimed.size
        }
        coEvery { mutations.updateThreadActionState(any(), any(), any(), any()) } coAnswers {
            val payload = firstArg<String>()
            rows.values.filter { it.payload == payload && it.state == MutationState.IN_FLIGHT }.forEach {
                rows[it.mutationId] = it.copy(state = arg(1), retryCount = arg(2), lastErrorCode = arg(3))
            }
            Unit
        }
        coEvery { mutations.deleteThreadAction(any()) } coAnswers {
            val payload = firstArg<String>()
            rows.entries.removeAll { it.value.payload == payload && it.value.state == MutationState.IN_FLIGHT }
            Unit
        }

    }

}
