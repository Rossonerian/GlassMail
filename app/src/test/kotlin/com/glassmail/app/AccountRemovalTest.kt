package com.glassmail.app

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.os.Bundle
import android.service.notification.StatusBarNotification
import com.glassmail.core.database.AccountDao
import com.glassmail.core.database.DraftDao
import com.glassmail.core.database.DraftEntity
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.security.CredentialStore
import com.glassmail.data.mail.ImapMailRepository
import com.glassmail.sync.IdleRuntime
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.io.File
import java.nio.file.Files
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AccountRemovalTest {
    @Test fun `removal preserves draft IDs for cleanup and wipes only the account cache and credentials`() = runBlocking {
        val root = Files.createTempDirectory("glassmail-removal").toFile()
        try {
            val accountDir = File(root, "attachments/account-a").apply { mkdirs() }
            File(accountDir, ".unfinished.part").writeText("partial attachment")
            val otherCache = File(root, "attachments/account-b/keep.txt").apply { requireNotNull(parentFile).mkdirs(); writeText("keep") }
            val database = mockk<GlassMailDatabase>()
            val accounts = mockk<AccountDao>()
            val drafts = mockk<DraftDao>()
            val credentials = mockk<CredentialStore>()
            every { database.accountDao() } returns accounts
            every { database.draftDao() } returns drafts
            val draft = DraftEntity("draft-a", "account-a", "", "", "", "", "", null, "", "QUEUED", 0L)
            every { drafts.observeDrafts("account-a") } returns flowOf(listOf(draft))
            val events = mutableListOf<String>()
            coEvery { accounts.deleteWithAccountData("account-a") } coAnswers { events.add("database"); Unit }
            coEvery { credentials.delete("account-a") } coAnswers { events.add("credentials"); Unit }
            val repository = ImapMailRepository(
                database, credentials, GmailImapClient(), attachmentRoot = root,
                onBeforeAccountRemoval = { accountId, draftIds ->
                    assertEquals("account-a", accountId)
                    assertEquals(listOf("draft-a"), draftIds)
                    assertTrue(accountDir.exists())
                    events.add("workers-idle-notifications")
                },
                onAccountRemoved = { accountId ->
                    assertEquals("account-a", accountId)
                    assertFalse(accountDir.exists())
                    events.add("removed")
                },
            )
            repository.removeAccount("account-a")
            assertEquals(listOf("workers-idle-notifications", "database", "credentials", "removed"), events)
            assertTrue(otherCache.isFile)
            coVerify(exactly = 1) { credentials.delete("account-a") }
            coVerify(exactly = 1) { accounts.deleteWithAccountData("account-a") }
        } finally {
            root.deleteRecursively()
        }
    }

    @Test fun `removal without drafts or a cached directory still invokes cleanup`() = runBlocking {
        val database = mockk<GlassMailDatabase>()
        val accounts = mockk<AccountDao>(relaxed = true)
        val drafts = mockk<DraftDao>()
        val credentials = mockk<CredentialStore>(relaxed = true)
        every { database.accountDao() } returns accounts
        every { database.draftDao() } returns drafts
        every { drafts.observeDrafts("rollback") } returns flowOf(emptyList())
        var cleanupCalled = false
        val repository = ImapMailRepository(
            database, credentials, GmailImapClient(),
            onBeforeAccountRemoval = { id, draftIds ->
                assertEquals("rollback", id)
                assertTrue(draftIds.isEmpty())
                cleanupCalled = true
            },
        )
        repository.removeAccount("rollback")
        assertTrue(cleanupCalled)
        coVerify { credentials.delete("rollback") }
    }

    @Test(timeout = 5_000) fun `removal cancels only the account IDLE job and rejects stale refresh registration`() = runBlocking {
        val accountId = "idle-removal-test"
        val otherId = "idle-other-test"
        IdleRuntime.allowAccount(accountId)
        IdleRuntime.allowAccount(otherId)
        val closed = CompletableDeferred<Unit>()
        val job = launch(start = CoroutineStart.UNDISPATCHED) {
            try { awaitCancellation() } finally { closed.complete(Unit) }
        }
        val otherJob = launch { awaitCancellation() }
        IdleRuntime.register(accountId, job)
        IdleRuntime.register(otherId, otherJob)
        try {
            withTimeout(1_500) { IdleRuntime.cancelAccount(accountId) }
            assertTrue(job.isCompleted)
            assertTrue(closed.isCompleted)
            assertTrue(otherJob.isActive)
            val staleJob = launch(start = CoroutineStart.LAZY) { error("Removed account must not start IDLE") }
            IdleRuntime.register(accountId, staleJob)
            assertTrue(staleJob.isCancelled)
            staleJob.join()
        } finally {
            IdleRuntime.cancelAccount(otherId)
            IdleRuntime.allowAccount(accountId)
            IdleRuntime.allowAccount(otherId)
        }
    }

    @Test fun `notification tags and canonical message IDs isolate accounts`() {
        assertEquals("account-a", NotificationCoordinator.accountIdForMessage("gmail:account-a:123"))
        assertEquals("account-b", NotificationCoordinator.accountIdForMessage("imap:account-b:42:9"))
        assertEquals(null, NotificationCoordinator.accountIdForMessage("debug:1"))
        assertFalse(NotificationCoordinator.accountTag("account-a") == NotificationCoordinator.accountTag("account-b"))
    }

    @Test fun `cancel account notifications includes legacy untagged mail and preserves other accounts`() {
        val context = mockk<Context>()
        val manager = mockk<NotificationManager>(relaxed = true)
        every { context.getSystemService(NotificationManager::class.java) } returns manager
        fun posted(tag: String?, id: Int, group: String): StatusBarNotification {
            val notification = mockk<Notification>()
            notification.extras = mockk<Bundle>(relaxed = true)
            every { notification.group } returns group
            return mockk<StatusBarNotification>().also {
                every { it.tag } returns tag
                every { it.id } returns id
                every { it.notification } returns notification
            }
        }
        val legacyId = "gmail:account-a:old".hashCode() and 0x7fffffff
        val tagA = NotificationCoordinator.accountTag("account-a")
        val tagB = NotificationCoordinator.accountTag("account-b")
        every { manager.activeNotifications } returns arrayOf(
            posted(tagA, 10, tagA),
            posted(tagB, 20, tagB),
            posted(null, legacyId, NotificationCoordinator.GROUP_KEY),
            posted(null, 7301, "mailbox-service"),
        )
        NotificationCoordinator(context, mockk(relaxed = true)).cancelForAccount("account-a", listOf("gmail:account-a:old"))
        verify(exactly = 1) { manager.cancel(tagA, 10) }
        verify(exactly = 1) { manager.cancel(null, legacyId) }
        verify(exactly = 0) { manager.cancel(tagB, 20) }
        verify(exactly = 0) { manager.cancel(null, 7301) }
    }
}
