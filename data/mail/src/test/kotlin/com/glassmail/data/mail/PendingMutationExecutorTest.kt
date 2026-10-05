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
    private val executor = PendingMutationExecutor(database, credentials, imap)

    init {
        every { database.pendingMutationDao() } returns mutations
        every { database.mailDao() } returns mail
        every { database.syncDao() } returns sync
        coEvery { mutations.activeForAccount("a") } returns listOf(mutation)
        coEvery { sync.checkpoint("a:INBOX") } returns SyncCheckpointEntity("a:INBOX", "a", 11, 500, 0, null)
        coEvery { mutations.updateState(any(), any(), any(), any()) } returns Unit
        coEvery { mutations.delete(any()) } returns Unit
    }

    @Test fun `SELECT mismatch leaves mutation pending without incrementing retries`() = runTest {
        coEvery { imap.applyInboxMutations("me@example.com", any(), any(), 11) } throws
            ImapException.UidValidityChanged(11, 22)

        executor.flush("a", "me@example.com")

        coVerifyOrder {
            mutations.updateState("queued", MutationState.IN_FLIGHT, 3, null)
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
}
