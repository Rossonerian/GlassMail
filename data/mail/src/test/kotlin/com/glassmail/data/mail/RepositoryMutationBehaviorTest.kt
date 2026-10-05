package com.glassmail.data.mail

import androidx.room.withTransaction
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.MutationState
import com.glassmail.core.database.PendingMutationDao
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.database.SyncDao
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.MailMutation
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** A transaction double models rollback; assertions inspect mailbox and queue state. */
class RepositoryMutationBehaviorTest {
    private val database = mockk<GlassMailDatabase>()
    private val mail = mockk<MailDao>()
    private val dao = mockk<PendingMutationDao>()
    private val sync = mockk<SyncDao>()
    private val rows = linkedMapOf<String, PendingMutationEntity>()
    private val memberships = linkedMapOf<String, MailboxMessageEntity>()
    private val failedCount = MutableStateFlow(0)
    private val scheduled = mutableListOf<Pair<String, Long>>()
    private var now = 1_000L
    private var inTransaction = false
    private var commits = 0
    private var rejectInsertFor: String? = null
    private var checkpointDeleted = false
    private val repository = ImapMailRepository(
        database, mockk<CredentialStore>(), mockk<GmailImapClient>(), clock = { now },
        onMutationsQueued = { id, delay ->
            assertFalse(inTransaction)
            scheduled.add(id to delay)
        },
    )

    private fun updateCount() {
        failedCount.value = rows.values.filter { it.state == MutationState.FAILED_PERMANENT }
            .distinctBy { it.payload ?: it.mutationId }.size
    }

    @Before fun setup() {
        every { database.mailDao() } returns mail
        every { database.pendingMutationDao() } returns dao
        every { database.syncDao() } returns sync
        mockkStatic("androidx.room.RoomDatabaseKt")
        coEvery { database.withTransaction<Any?>(any()) } coAnswers {
            assertFalse(inTransaction)
            val oldRows = LinkedHashMap(rows)
            val oldMemberships = LinkedHashMap(memberships)
            inTransaction = true
            try {
                val result = secondArg<suspend () -> Any?>().invoke()
                commits++
                result
            } catch (error: Throwable) {
                rows.clear(); rows.putAll(oldRows)
                memberships.clear(); memberships.putAll(oldMemberships)
                throw error
            } finally { inTransaction = false; updateCount() }
        }
        coEvery { mail.membershipsForMessage(any()) } coAnswers { listOfNotNull(memberships[firstArg<String>()]) }
        coEvery { mail.upsertMailboxMessages(any()) } coAnswers {
            assertTrue(inTransaction)
            firstArg<List<MailboxMessageEntity>>().forEach { memberships[it.messageId] = it }
        }
        coEvery { mail.removeMailboxMembership(any(), any()) } coAnswers {
            assertTrue(inTransaction)
            memberships.remove(secondArg<String>())
            Unit
        }
        coEvery { dao.insert(any()) } coAnswers {
            assertTrue(inTransaction)
            val row = firstArg<PendingMutationEntity>()
            if (row.messageId == rejectInsertFor) error("simulated process/transaction failure")
            rows[row.mutationId] = row
        }
        coEvery { dao.activeForAccount("a") } coAnswers { rows.values.toList() }
        coEvery { dao.activeForMessage(any()) } coAnswers { rows.values.filter { it.messageId == firstArg<String>() } }
        coEvery { dao.failedForAccount("a") } coAnswers { rows.values.filter { it.state == MutationState.FAILED_PERMANENT } }
        every { dao.observeFailedCount("a") } returns failedCount
        coEvery { dao.retryFailed("a") } coAnswers {
            rows.values.filter { it.state == MutationState.FAILED_PERMANENT }.forEach { rows[it.mutationId] = it.copy(state = MutationState.PENDING, lastErrorCode = null) }
            updateCount()
        }
        coEvery { dao.deleteFailed("a") } coAnswers {
            assertTrue(inTransaction)
            rows.entries.removeAll { it.value.state == MutationState.FAILED_PERMANENT }
            updateCount()
        }
        coEvery { sync.deleteCheckpoint("a:INBOX") } coAnswers { checkpointDeleted = true }
        for (id in listOf("gmail:a:1", "gmail:a:2")) memberships[id] = MailboxMessageEntity("a:INBOX", id.substringAfterLast(':').toLong(), id, "\\Seen", "Project Alpha")
    }

    @After fun cleanup() { unmockkStatic("androidx.room.RoomDatabaseKt") }

    @Test fun `whole conversation enqueue commits once and wakes flush after Undo grace`() = runTest {
        repository.applyMutations(listOf(
            MailMutation.Archive("a", "gmail:a:1", "a:INBOX", "123"),
            MailMutation.Archive("a", "gmail:a:2", "a:INBOX", "123"),
        ))
        assertEquals(1, commits)
        assertTrue(memberships.isEmpty())
        assertEquals(2, rows.size)
        assertEquals(1, rows.values.map { it.payload }.distinct().size)
        assertTrue(rows.values.all { it.payload!!.startsWith("gmail-thread:123:") })
        assertEquals(listOf("a" to 6_000L), scheduled)
        // A later single-message flag action must not shorten the archive's Undo window.
        now += 500L
        repository.applyMutation(MailMutation.Star("a", "gmail:a:1", null, true))
        assertEquals("a" to 5_500L, scheduled.last())
    }

    @Test fun `failure while enqueuing second member rolls back every optimistic change and queued row`() = runTest {
        val original = memberships.toMap()
        rejectInsertFor = "gmail:a:2"
        var failed = false
        try {
            repository.applyMutations(listOf(
                MailMutation.Archive("a", "gmail:a:1", "a:INBOX", "123"),
                MailMutation.Archive("a", "gmail:a:2", "a:INBOX", "123"),
            ))
        } catch (_: IllegalStateException) { failed = true }
        assertTrue(failed)
        assertEquals(original, memberships)
        assertTrue(rows.isEmpty())
        assertEquals(0, commits)
        assertTrue(scheduled.isEmpty())
    }

    @Test fun `Retry clears failed count and requeues the whole rejected conversation`() = runTest {
        repository.applyMutations(listOf(
            MailMutation.Star("a", "gmail:a:1", "a:INBOX", true, "123"),
            MailMutation.Star("a", "gmail:a:2", "a:INBOX", true, "123"),
        ))
        rows.values.toList().forEach { rows[it.mutationId] = it.copy(state = MutationState.FAILED_PERMANENT, lastErrorCode = "SERVER_REJECTED") }
        updateCount()
        assertEquals(1, repository.observeFailedMutationCount("a").first())
        repository.retryFailedMutations("a")
        assertEquals(0, repository.observeFailedMutationCount("a").first())
        assertTrue(rows.values.all { it.state == MutationState.PENDING && it.lastErrorCode == null })
        assertEquals("a" to 500L, scheduled.last())
    }

    @Test fun `Dismiss removes rejected archive restores memberships and schedules server reconciliation`() = runTest {
        repository.applyMutations(listOf(
            MailMutation.Archive("a", "gmail:a:1", "a:INBOX", "123"),
            MailMutation.Archive("a", "gmail:a:2", "a:INBOX", "123"),
        ))
        rows.values.toList().forEach { rows[it.mutationId] = it.copy(state = MutationState.FAILED_PERMANENT, lastErrorCode = "SERVER_REJECTED") }
        updateCount()
        assertTrue(memberships.isEmpty())
        repository.dismissFailedMutations("a")
        assertEquals(setOf("gmail:a:1", "gmail:a:2"), memberships.keys)
        assertTrue(memberships.values.all { it.flags == "\\Seen" && it.labels == "Project Alpha" })
        assertTrue(rows.isEmpty())
        assertEquals(0, failedCount.value)
        assertTrue(checkpointDeleted)
        assertEquals("a" to 500L, scheduled.last())
    }
    @Test fun `Dismiss restores archive snapshot while newer pending unread intent still wins`() = runTest {
        repository.applyMutation(MailMutation.Archive("a", "gmail:a:1", "a:INBOX", "123"))
        val archive = rows.values.single()
        rows[archive.mutationId] = archive.copy(state = MutationState.FAILED_PERMANENT, lastErrorCode = "SERVER_REJECTED")
        now += 1_000
        repository.applyMutation(MailMutation.MarkRead("a", "gmail:a:1", null, false))
        repository.dismissFailedMutations("a")
        assertEquals("", memberships["gmail:a:1"]?.flags)
        assertEquals("MARK_UNREAD", rows.values.single().type)
        assertEquals(MutationState.PENDING, rows.values.single().state)
    }

    @Test fun `Undo refuses the entire conversation if any member was already claimed`() = runTest {
        repository.applyMutations(listOf(
            MailMutation.Archive("a", "gmail:a:1", "a:INBOX", "123"),
            MailMutation.Archive("a", "gmail:a:2", "a:INBOX", "123"),
        ))
        val first = rows.values.first()
        rows[first.mutationId] = first.copy(state = MutationState.IN_FLIGHT)
        coEvery { dao.undoableArchive(any()) } coAnswers {
            rows.values.firstOrNull { it.messageId == firstArg<String>() && it.type == "ARCHIVE" && it.state == MutationState.PENDING }
        }
        assertFalse(repository.undoPendingArchives(listOf("gmail:a:1", "gmail:a:2")))
        assertTrue(memberships.isEmpty())
        assertEquals(2, rows.size)
    }

}
