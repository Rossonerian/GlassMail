package com.glassmail.data.mail

import com.glassmail.core.database.AccountDao
import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.MessageEntity
import com.glassmail.core.database.MessageLabelEntity
import com.glassmail.core.database.PendingMutationDao
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.database.SyncCheckpointEntity
import com.glassmail.core.database.SyncDao
import com.glassmail.core.imap.OlderInboxPage
import com.glassmail.core.model.GmailInboxSnapshot
import com.glassmail.core.model.ImapMailbox
import com.glassmail.core.model.ImapMessageMetadata
import com.glassmail.core.model.ImapSelectedMailbox
import com.glassmail.domain.mail.OlderMailResult
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Stateful DAO doubles: assertions inspect persisted state, not mirrored method calls. */
class InboxCacheTest {
    private val mail = mockk<MailDao>()
    private val mutations = mockk<PendingMutationDao>()
    private val sync = mockk<SyncDao>()
    private val account = mockk<AccountDao>()
    private val memberships = linkedMapOf<Long, MailboxMessageEntity>()
    private val labels = mutableMapOf<String, Set<String>>()
    private val messages = mutableMapOf<String, MessageEntity>()
    private val pending = mutableMapOf<String, List<PendingMutationEntity>>()
    private var checkpoint = SyncCheckpointEntity("a:INBOX", "a", 11, 1000, 3, 1234)
    private var transactionActive = false
    private var commits = 0
    private var enforced = false
    private val transaction: suspend (suspend () -> Unit) -> Unit = { block ->
        assertFalse(transactionActive)
        transactionActive = true
        try {
            block()
            commits++
        } finally {
            transactionActive = false
        }
    }

    init {
        coEvery { mail.mailboxMembershipPage(any(), any(), any(), any()) } coAnswers {
            val after = secondArg<Long>()
            val through = thirdArg<Long>()
            memberships.values.filter { it.mailboxId == firstArg<String>() && it.uid > after && it.uid <= through }.sortedBy { it.uid }.take(arg(3))
        }
        coEvery { mail.mailboxUidValidity(any()) } returns 11
        coEvery { mail.lowestMailboxUid(any()) } coAnswers { memberships.values.filter { it.mailboxId == firstArg<String>() }.minOfOrNull { it.uid } }
        coEvery { mail.countMailboxMessages(any()) } coAnswers { memberships.values.count { it.mailboxId == firstArg<String>() } }
        coEvery { mail.membershipsForMessage(any()) } coAnswers { memberships.values.filter { it.messageId == firstArg<String>() } }
        coEvery { mutations.activeForThread(any(), any()) } returns emptyList()
        coEvery { mutations.activeForMessage(any()) } coAnswers { pending[firstArg<String>()].orEmpty() }
        coEvery { mail.removeMailboxMembership(any(), any()) } coAnswers {
            assertTrue(transactionActive)
            val id = secondArg<String>()
            val mailboxId = firstArg<String>()
            memberships.entries.removeAll { it.value.messageId == id && it.value.mailboxId == mailboxId }
            Unit
        }
        coEvery { mail.upsertMailboxMessages(any()) } coAnswers {
            assertTrue(transactionActive)
            firstArg<List<MailboxMessageEntity>>().forEach { memberships[it.uid] = it }
        }
        coEvery { mail.clearMessageLabels(any()) } coAnswers {
            assertTrue(transactionActive)
            labels.remove(firstArg<String>())
            Unit
        }
        coEvery { mail.upsertLabels(any()) } coAnswers {
            assertTrue(transactionActive)
            firstArg<List<MessageLabelEntity>>().forEach { labels[it.messageId] = labels[it.messageId].orEmpty() + it.label }
        }
        coEvery { mail.updateCategory(any(), any()) } returns Unit
        coEvery { mail.upsertMailboxes(any()) } returns Unit
        coEvery { mail.existingBodyStates(any()) } returns emptyList()
        coEvery { mail.upsertMessages(any()) } coAnswers {
            assertTrue(transactionActive)
            firstArg<List<MessageEntity>>().forEach { messages[it.messageId] = it }
        }
        coEvery { sync.checkpoint(any()) } coAnswers { checkpoint }
        coEvery { sync.upsertCheckpoint(any()) } coAnswers { checkpoint = firstArg() }
        coEvery { account.markSyncSuccess(any(), any(), any(), any()) } returns Unit
    }

    @Test fun `reconciliation replaces flags and labels without fetching metadata bodies`() = runTest {
        add(10, flags = "", localLabels = setOf("Old"))
        reconcile { uids ->
            assertFalse(transactionActive)
            assertEquals(listOf(10L), uids)
            listOf(remote(10, setOf("\\Seen", "\\Flagged"), setOf("New label")))
        }
        assertEquals("\\Flagged \\Seen", memberships[10]?.flags)
        assertEquals("New label", memberships[10]?.labels)
        assertEquals(setOf("New label"), labels["gmail:a:10"])
        assertEquals(1, commits)
        assertTrue(messages.isEmpty())
    }

    @Test fun `absent UID removes Inbox membership and labels but retains canonical message`() = runTest {
        add(10, localLabels = setOf("\\Inbox", "Old"))
        messages["gmail:a:10"] = MessageEntity("gmail:a:10", "a", "10", null, "Subject", "Sender", 0, 1)
        reconcile { emptyList() }
        assertTrue(memberships.isEmpty())
        assertFalse(labels.containsKey("gmail:a:10"))
        assertTrue(messages.containsKey("gmail:a:10"))
    }

    @Test fun `absent Inbox UID retains other membership and rebuilds labels`() = runTest {
        add(10, localLabels = setOf("\\Inbox", "Old"))
        memberships[20] = MailboxMessageEntity("a:Other", 20, "gmail:a:10", "", "Keep label")
        reconcile { emptyList() }
        assertEquals("a:Other", memberships[20]?.mailboxId)
        assertFalse(memberships.containsKey(10))
        assertEquals(setOf("Keep label"), labels["gmail:a:10"])
    }

    @Test fun `pending read star and label intents are untouched by stale or absent server UID`() = runTest {
        add(10, "\\Seen \\Flagged", setOf("Local"))
        add(20, "\\Seen", setOf("Keep"))
        pending["gmail:a:10"] = listOf(mutation(10, "ADD_LABEL", "Local"))
        pending["gmail:a:20"] = listOf(mutation(20, "MARK_READ"))
        val before = memberships.toMap()
        val beforeLabels = labels.toMap()
        reconcile { listOf(remote(10)) }
        assertEquals(before, memberships)
        assertEquals(beforeLabels, labels)
    }

    @Test fun `intent queued during network read protects membership in transaction`() = runTest {
        add(10, "\\Seen")
        reconcile {
            pending["gmail:a:10"] = listOf(mutation(10, "MARK_READ"))
            emptyList()
        }
        assertEquals("\\Seen", memberships[10]?.flags)
    }

    @Test fun `removed membership during fetch is never recreated`() = runTest {
        add(10)
        reconcile {
            memberships.clear()
            listOf(remote(10))
        }
        assertTrue(memberships.isEmpty())
    }

    @Test fun `large cached window reconciles in bounded atomic chunks`() = runTest {
        (1L..501).forEach { add(it) }
        val sizes = mutableListOf<Int>()
        reconcile { uids -> sizes.add(uids.size); uids.map { remote(it, setOf("\\Seen")) } }
        assertEquals(listOf(500, 1), sizes)
        assertEquals(2, commits)
        assertTrue(memberships.values.all { it.flags == "\\Seen" })
    }

    @Test fun `cancelled flags fetch leaves cache unchanged`() = runTest {
        add(10)
        val before = memberships.toMap()
        try {
            reconcile { throw CancellationException("cancel") }
            throw AssertionError("Expected cancellation")
        } catch (_: CancellationException) {
            assertEquals(before, memberships)
            assertEquals(0, commits)
        }
    }

    @Test fun `older page persists content membership and labels without moving checkpoint`() = runTest {
        add(100)
        val before = checkpoint
        val result = older(200) { low, limit ->
            assertEquals(100L, low)
            assertEquals(50, limit)
            page(listOf(remote(3, setOf("\\Seen"), setOf("Older")), remote(42)))
        }
        assertEquals(before, checkpoint)
        assertEquals(setOf(3L, 42L, 100L), memberships.keys)
        assertEquals("Subject", messages["gmail:a:3"]?.subject)
        assertEquals(setOf("Older"), labels["gmail:a:3"])
        assertTrue(enforced)
        assertEquals(OlderMailResult.Success(2, true), result)
    }

    @Test fun `backfill stops at configured Inbox cap without network fetch`() = runTest {
        (100L..149).forEach { add(it) }
        val result = older(50) { _, _ -> error("Must not fetch at cap") }
        assertEquals(OlderMailResult.Success(0, false, true), result)
        assertEquals(0, commits)
    }

    @Test fun `backfill limits last page to cache capacity and reports limit reached`() = runTest {
        (100L..147).forEach { add(it) }
        val result = older(50) { _, limit ->
            assertEquals(2, limit)
            page(listOf(remote(3), remote(42)))
        }
        assertEquals(50, memberships.size)
        assertEquals(OlderMailResult.Success(2, false, true), result)
    }

    @Test fun `capacity is rechecked inside persistence if local undo adds a membership during fetch`() = runTest {
        (100L..147).forEach { add(it) }
        val result = older(50) { _, _ ->
            add(200)
            page(listOf(remote(3), remote(42)))
        }
        assertEquals(50, memberships.size)
        assertTrue(memberships.containsKey(42))
        assertFalse(memberships.containsKey(3))
        assertEquals(OlderMailResult.Success(1, false, true), result)
    }

    @Test fun `lowest UID one is exhausted without network fetch`() = runTest {
        add(1)
        assertEquals(OlderMailResult.Success(0, false), older(200) { _, _ -> error("UID 1 is exhausted") })
    }

    @Test fun `empty sparse older search is exhausted and checkpoint remains unchanged`() = runTest {
        add(500)
        val before = checkpoint
        assertEquals(OlderMailResult.Success(0, false), older(200) { _, _ -> page(emptyList(), more = false) })
        assertEquals(before, checkpoint)
    }

    @Test fun `snapshot overlays pending flags and labels while acquiring fresh UID`() = runTest {
        pending["gmail:a:10"] = listOf(mutation(10, "MARK_READ"), mutation(10, "ADD_LABEL", "Local"), mutation(10, "REMOVE_LABEL", "Remove"))
        persist(page(listOf(remote(10, labels = setOf("Remove")))))
        assertEquals("\\Seen", memberships[10]?.flags)
        assertEquals("Local", memberships[10]?.labels)
        assertEquals(setOf("Local"), labels["gmail:a:10"])
    }

    @Test fun `snapshot cannot recreate optimistic pending archive or delete`() = runTest {
        pending["gmail:a:10"] = listOf(mutation(10, "ARCHIVE"))
        pending["gmail:a:20"] = listOf(mutation(20, "DELETE"))
        persist(page(listOf(remote(10), remote(20))))
        assertTrue(memberships.isEmpty())
        assertTrue(messages.isEmpty())
    }


    @Test fun `newly fetched uncached member cannot resurrect a pending archived conversation`() = runTest {
        coEvery { mutations.activeForThread("a", "123") } returns listOf(mutation(10, "ARCHIVE", "gmail-thread:123"))
        persist(page(listOf(remote(99).copy(gmailThreadId = "123"))))
        assertTrue(memberships.isEmpty())
        assertTrue(messages.isEmpty())
    }

    @Test fun `newly fetched thread member overlays pending unread and unstar intent`() = runTest {
        coEvery { mutations.activeForThread("a", "123") } returns listOf(
            mutation(10, "MARK_UNREAD", "gmail-thread:123"), mutation(10, "UNSTAR", "gmail-thread:123"),
        )
        persist(page(listOf(remote(99, setOf("\\Seen", "\\Flagged"), setOf("Project Alpha", "Work")).copy(gmailThreadId = "123"))))
        assertEquals("", memberships[99]?.flags)
        assertEquals(listOf("Project Alpha", "Work"), memberships[99]!!.labels.toLabels())
        assertEquals(setOf("Project Alpha", "Work"), labels["gmail:a:99"])
    }

    private suspend fun reconcile(fetch: suspend (List<Long>) -> List<ImapMessageMetadata>) =
        reconcileCachedInbox("a", 11, 1000, mail, mutations, transaction, fetch)

    private suspend fun older(cap: Int, fetch: suspend (Long, Int) -> OlderInboxPage) =
        loadOlderInbox("a:INBOX", cap, mail, fetch, { persist(it, cap) }, { enforced = true })

    private suspend fun persist(page: OlderInboxPage, cap: Int? = null) = persistInboxBatch(
        mail, sync, mutations, account, transaction, { 9999L }, advanceCheckpoint = false, cacheCap = cap,
        accountId = "a", inboxId = "a:INBOX", snapshot = page.snapshot,
        batch = page.snapshot.messages, isFinalBatch = true,
    )

    private fun add(uid: Long, flags: String = "", localLabels: Set<String> = emptySet()) {
        val id = "gmail:a:$uid"
        memberships[uid] = MailboxMessageEntity("a:INBOX", uid, id, flags, localLabels.joinToString("\u001F"))
        labels[id] = localLabels
    }

    private fun mutation(uid: Long, type: String, payload: String? = null) = PendingMutationEntity(
        "pending-$uid-$type", "a", "a:INBOX", "gmail:a:$uid", uid, type, payload, createdAtEpochMillis = 0,
    )

    private fun remote(uid: Long, flags: Set<String> = emptySet(), labels: Set<String> = emptySet()) =
        ImapMessageMetadata(uid, flags, "$uid", null, labels, "Subject", "Sender", 0, 1)

    private fun page(messages: List<ImapMessageMetadata>, more: Boolean = true) = OlderInboxPage(
        GmailInboxSnapshot(setOf("X-GM-EXT-1"), listOf(ImapMailbox("INBOX", emptySet())), ImapSelectedMailbox(11, 1001, 1000), messages, requestedThroughUid = 5000),
        more,
    )
}
