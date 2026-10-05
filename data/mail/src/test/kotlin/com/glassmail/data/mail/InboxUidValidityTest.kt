package com.glassmail.data.mail

import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.PendingMutationDao
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.database.SyncCheckpointEntity
import com.glassmail.core.database.SyncDao
import com.glassmail.core.imap.ImapException
import com.glassmail.core.model.GmailInboxSnapshot
import com.glassmail.core.model.ImapSelectedMailbox
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import java.io.IOException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class InboxUidValidityTest {
    private val mail = mockk<MailDao>()
    private val sync = mockk<SyncDao>()
    private val mutations = mockk<PendingMutationDao>()
    private val events = mutableListOf<String>()
    private var transactionActive = false
    private val transaction: suspend (suspend () -> Unit) -> Unit = { block ->
        assertFalse(transactionActive)
        transactionActive = true
        events.add("begin")
        try {
            block()
            events.add("commit")
        } finally {
            transactionActive = false
        }
    }

    init {
        coEvery { mail.clearMailboxMembership("a:INBOX") } coAnswers {
            assertTrue(transactionActive)
            events.add("clear memberships")
            Unit
        }
        coEvery { sync.deleteCheckpoint("a:INBOX") } coAnswers {
            assertTrue(transactionActive)
            events.add("delete checkpoint")
            Unit
        }
        coEvery { mutations.clearActiveTargetUids("a") } coAnswers {
            assertTrue(transactionActive)
            events.add("null target UIDs")
            Unit
        }
    }

    @Test fun `changed validity invalidates active UIDs atomically and discards stale page for latest`() = runTest {
        // Old checkpoint boundary 500 caused the obsolete page to request through 700.
        val stalePage = snapshot(validity = 22, throughUid = 700)
        val latest = snapshot(validity = 22, throughUid = 1000)
        val result = recoverInboxSnapshot("a", 11, stalePage, mail, sync, mutations, transaction) {
            assertFalse(transactionActive)
            events.add("fetch latest")
            latest
        }

        assertSame(latest, result)
        assertEquals(1000L, result.requestedThroughUid)
        assertEquals(
            listOf("begin", "clear memberships", "delete checkpoint", "null target UIDs", "commit", "fetch latest"),
            events,
        )
        coVerify(exactly = 1) { mutations.clearActiveTargetUids("a") }
    }

    @Test fun `mailbox validity detects reset when checkpoint is absent`() = runTest {
        coEvery { sync.checkpoint("a:INBOX") } returns null
        coEvery { mail.mailboxUidValidity("a:INBOX") } returns 11
        val storedValidity = sync.checkpoint("a:INBOX")?.uidValidity ?: mail.mailboxUidValidity("a:INBOX")
        val latest = snapshot(22)

        val result = recoverInboxSnapshot("a", storedValidity, snapshot(22, 700), mail, sync, mutations, transaction) {
            latest
        }

        assertSame(latest, result)
        coVerify(exactly = 1) {
            mail.clearMailboxMembership("a:INBOX")
            sync.deleteCheckpoint("a:INBOX")
            mutations.clearActiveTargetUids("a")
        }
    }

    @Test fun `unchanged validity preserves incremental snapshot without resetting`() = runTest {
        val incremental = snapshot(11, 700)
        val result = recoverInboxSnapshot("a", 11, incremental, mail, sync, mutations, transaction) {
            error("Must not restart unchanged namespace")
        }

        assertSame(incremental, result)
        assertTrue(events.isEmpty())
        coVerify(exactly = 0) { mutations.clearActiveTargetUids(any()) }
    }

    @Test fun `first sync without stored validity preserves latest snapshot`() = runTest {
        val latest = snapshot(22)
        val result = recoverInboxSnapshot("a", null, latest, mail, sync, mutations, transaction) {
            error("Must not repeat first sync")
        }

        assertSame(latest, result)
        assertTrue(events.isEmpty())
    }

    @Test fun `failed latest fetch leaves obsolete UIDs invalidated and checkpoint deleted`() = runTest {
        val failure = ImapException.Transport(IOException("connection lost"))
        try {
            recoverInboxSnapshot("a", 11, snapshot(22, 700), mail, sync, mutations, transaction) { throw failure }
            throw AssertionError("Expected transport failure")
        } catch (actual: ImapException.Transport) {
            assertSame(failure, actual)
        }

        assertEquals(listOf("begin", "clear memberships", "delete checkpoint", "null target UIDs", "commit"), events)
    }

    private fun snapshot(validity: Long, throughUid: Long = 1000) = GmailInboxSnapshot(
        capabilities = setOf("X-GM-EXT-1"), mailboxes = emptyList(),
        inbox = ImapSelectedMailbox(validity, uidNext = 1001, messageCount = 1000),
        messages = emptyList(), requestedThroughUid = throughUid,
    )
}

class ArchiveUndoUidValidityTest {
    private val mail = mockk<MailDao>()
    private val sync = mockk<SyncDao>()
    private val mutations = mockk<PendingMutationDao>()
    private val archive = PendingMutationEntity(
        mutationId = "archive", accountId = "a", mailboxId = "a:INBOX", messageId = "gmail:a:canonical",
        targetUid = 7, type = "ARCHIVE", payload = null, createdAtEpochMillis = 0,
        previousFlags = "\\Seen", previousLabels = "\\Inbox",
    )

    init {
        coEvery { mutations.undoableArchive(archive.messageId) } returns archive
        coEvery { sync.checkpoint("a:INBOX") } returns SyncCheckpointEntity("a:INBOX", "a", 11, 500, 0, null)
        coEvery { mail.mailboxUidValidity("a:INBOX") } returns 11
        coEvery { mail.upsertMailboxMessages(any()) } returns Unit
        coEvery { mutations.delete("archive") } returns Unit
    }

    @Test fun `matching local namespace restores captured archive membership`() = runTest {
        assertTrue(undoArchiveInCurrentNamespace(archive.messageId, mail, sync, mutations))
        coVerify(exactly = 1) {
            mail.upsertMailboxMessages(listOf(MailboxMessageEntity("a:INBOX", 7, archive.messageId, "\\Seen", "\\Inbox")))
            mutations.delete("archive")
        }
    }

    @Test fun `reset invalidated target never restores old membership`() = runTest {
        coEvery { mutations.undoableArchive(archive.messageId) } returns archive.copy(targetUid = null)
        assertFalse(undoArchiveInCurrentNamespace(archive.messageId, mail, sync, mutations))
        verifyNoRestore()
    }

    @Test fun `different mailbox and checkpoint validity prevents restore`() = runTest {
        coEvery { mail.mailboxUidValidity("a:INBOX") } returns 22
        assertFalse(undoArchiveInCurrentNamespace(archive.messageId, mail, sync, mutations))
        verifyNoRestore()
    }

    @Test fun `missing checkpoint prevents restore`() = runTest {
        coEvery { sync.checkpoint("a:INBOX") } returns null
        assertFalse(undoArchiveInCurrentNamespace(archive.messageId, mail, sync, mutations))
        verifyNoRestore()
    }

    @Test fun `known server mismatch prevents restore before reset is persisted`() = runTest {
        coEvery { mutations.undoableArchive(archive.messageId) } returns archive.copy(lastErrorCode = "UIDVALIDITY_CHANGED")
        assertFalse(undoArchiveInCurrentNamespace(archive.messageId, mail, sync, mutations))
        verifyNoRestore()
    }

    private fun verifyNoRestore() {
        coVerify(exactly = 0) { mail.upsertMailboxMessages(any()) }
        coVerify(exactly = 0) { mutations.delete(any()) }
    }
}
