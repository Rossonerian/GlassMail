package com.glassmail.data.mail

import com.glassmail.core.database.AccountDao
import com.glassmail.core.database.AccountEntity
import com.glassmail.core.database.AttachmentEntity
import com.glassmail.core.database.CacheConfigDao
import com.glassmail.core.database.CacheConfigEntity
import com.glassmail.core.database.DownloadState
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.PendingMutationDao
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.sanitizeAttachmentName
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.coVerifyOrder
import io.mockk.every
import io.mockk.mockk
import java.io.File
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class AttachmentDownloadTest {
    @get:Rule
    val tempFolder = TemporaryFolder()

    private val database = mockk<GlassMailDatabase>()
    private val accountDao = mockk<AccountDao>()
    private val mailDao = mockk<MailDao>()
    private val cacheConfigDao = mockk<CacheConfigDao>()
    private val pendingMutationDao = mockk<PendingMutationDao>()
    private val imapClient = mockk<GmailImapClient>()
    private val credentials = object : CredentialStore {
        override suspend fun store(accountId: String, credential: CharArray) = Unit
        override suspend fun delete(accountId: String) = Unit
        override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T =
            block(charArrayOf('p'))
    }

    init {
        every { database.accountDao() } returns accountDao
        every { database.mailDao() } returns mailDao
        every { database.cacheConfigDao() } returns cacheConfigDao
        every { database.pendingMutationDao() } returns pendingMutationDao
        coEvery { mailDao.setAttachmentState(any(), any()) } returns Unit
        coEvery { mailDao.setAttachmentStates(any(), any()) } returns Unit
        coEvery { mailDao.markAttachmentAccessed(any(), any()) } returns Unit
        coEvery { mailDao.evictExcessBodies(any(), any()) } returns Unit
        coEvery { mailDao.evictOldReadBodies(any(), any()) } returns Unit
        coEvery { mailDao.cachedAttachments(any()) } returns emptyList()
        coEvery { mailDao.mailboxUidValidity(any()) } returns null
        coEvery { cacheConfigDao.get(any()) } returns null
    }

    private fun newRepository(root: File = tempFolder.root, clock: () -> Long = { 5_000L }) =
        ImapMailRepository(
            database = database,
            credentialStore = credentials,
            imapClient = imapClient,
            attachmentRoot = root,
            clock = clock,
        )

    private fun expectedTarget(root: File, accountId: String, attachmentId: String, fileName: String): File {
        val safeName = sanitizeAttachmentName(fileName)
        return File(root, "attachments/$accountId/${attachmentId.hashCode().toUInt().toString(16)}-$safeName")
    }

    @Test
    fun `cached attachment returns without IMAP and keeps AVAILABLE`() = runTest {
        val root = tempFolder.newFolder("cache-hit")
        val accountId = "account1"
        val messageId = "gmail:$accountId:msg1"
        val attachmentId = "$messageId:1"
        val fileName = "report.pdf"
        val target = expectedTarget(root, accountId, attachmentId, fileName)
        target.parentFile.mkdirs()
        target.writeBytes("cached-pdf".encodeToByteArray())

        coEvery { accountDao.account(accountId) } returns AccountEntity(accountId, "me@example.com", 1_000L, "READY")
        coEvery { mailDao.attachment(attachmentId) } returns AttachmentEntity(
            attachmentId = attachmentId,
            messageId = messageId,
            partId = "1",
            fileName = fileName,
            mimeType = "application/pdf",
            sizeBytes = 10L,
            downloadState = DownloadState.AVAILABLE,
        )

        val result = newRepository(root).downloadAttachment(accountId, attachmentId)

        assertTrue(result.isSuccess)
        val downloaded = result.getOrThrow()
        assertEquals(target.canonicalPath, downloaded.filePath)
        assertEquals("report.pdf", downloaded.fileName)
        assertEquals("application/pdf", downloaded.mimeType)
        coVerify(exactly = 0) { imapClient.fetchAttachment(any(), any(), any(), any(), any(), any()) }
        coVerify(exactly = 0) { mailDao.setAttachmentState(any(), any()) }
        coVerify(exactly = 1) { mailDao.markAttachmentAccessed(attachmentId, 5_000L) }
    }

    @Test
    fun `traversal and cross-account accountId rejected without mkdirs or FAILED state`() = runTest {
        val root = tempFolder.newFolder("traversal")
        val traversalAccountId = "../evil"
        val traversalMessageId = "gmail:$traversalAccountId:msg1"
        val traversalAttachmentId = "$traversalMessageId:1"

        coEvery { accountDao.account(traversalAccountId) } returns AccountEntity(traversalAccountId, "evil@example.com", 1_000L, "READY")
        coEvery { mailDao.attachment(traversalAttachmentId) } returns AttachmentEntity(
            attachmentId = traversalAttachmentId,
            messageId = traversalMessageId,
            partId = "1",
            fileName = "secret.txt",
            mimeType = "text/plain",
            sizeBytes = 5L,
            downloadState = DownloadState.NOT_FETCHED,
        )

        val repository = newRepository(root)
        val traversalResult = repository.downloadAttachment(traversalAccountId, traversalAttachmentId)

        assertTrue(traversalResult.isFailure)
        assertFalse(File(root, "evil").exists())
        assertFalse(File(root, "attachments").exists())

        val otherAccountId = "account2"
        val crossMessageId = "gmail:account1:msg2"
        val crossAttachmentId = "$crossMessageId:1"
        coEvery { accountDao.account(otherAccountId) } returns AccountEntity(otherAccountId, "two@example.com", 1_000L, "READY")
        coEvery { mailDao.attachment(crossAttachmentId) } returns AttachmentEntity(
            attachmentId = crossAttachmentId,
            messageId = crossMessageId,
            partId = "1",
            fileName = "doc.pdf",
            mimeType = "application/pdf",
            sizeBytes = 10L,
            downloadState = DownloadState.NOT_FETCHED,
        )

        val crossResult = repository.downloadAttachment(otherAccountId, crossAttachmentId)

        assertTrue(crossResult.isFailure)
        assertFalse(File(root, "attachments/$otherAccountId").exists())
        coVerify(exactly = 0) { mailDao.setAttachmentState(any(), any()) }
        coVerify(exactly = 0) { imapClient.fetchAttachment(any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `cancellation resets FETCHING to NOT_FETCHED and cleans up part temp file`() = runTest {
        val root = tempFolder.newFolder("cancel")
        val accountId = "account1"
        val messageId = "gmail:$accountId:msg1"
        val attachmentId = "$messageId:1"
        val fileName = "invoice.pdf"
        val target = expectedTarget(root, accountId, attachmentId, fileName)
        target.parentFile.mkdirs()
        val partFile = File(target.parentFile, ".${target.name}.part")
        partFile.writeBytes("partial-bytes".encodeToByteArray())
        assertTrue(partFile.exists())

        coEvery { accountDao.account(accountId) } returns AccountEntity(accountId, "me@example.com", 1_000L, "READY")
        coEvery { mailDao.attachment(attachmentId) } returns AttachmentEntity(
            attachmentId = attachmentId,
            messageId = messageId,
            partId = "1",
            fileName = fileName,
            mimeType = "application/pdf",
            sizeBytes = 100L,
            downloadState = DownloadState.NOT_FETCHED,
        )
        coEvery { mailDao.membershipsForMessage(messageId) } returns listOf(
            MailboxMessageEntity("$accountId:INBOX", 42L, messageId, "", ""),
        )

        val fetchEntered = CompletableDeferred<Unit>()
        coEvery { imapClient.fetchAttachment("me@example.com", any(), "INBOX", 42L, "1", isNull()) } coAnswers {
            fetchEntered.complete(Unit)
            awaitCancellation()
        }

        val repository = newRepository(root)
        val job = launch {
            repository.downloadAttachment(accountId, attachmentId)
        }
        fetchEntered.await()
        job.cancelAndJoin()

        assertTrue(job.isCancelled)
        assertFalse(partFile.exists())
        assertFalse(target.exists())
        coVerifyOrder {
            mailDao.setAttachmentState(attachmentId, DownloadState.FETCHING)
            mailDao.setAttachmentState(attachmentId, DownloadState.NOT_FETCHED)
        }
        coVerify(exactly = 0) { mailDao.setAttachmentState(attachmentId, DownloadState.FAILED) }
    }

    @Test
    fun `enforceCacheLimits during downloadAttachment preserves just-downloaded attachment`() = runTest {
        val root = tempFolder.newFolder("evict")
        val accountId = "account1"
        val oldAttachment = AttachmentEntity(
            attachmentId = "gmail:$accountId:old:1",
            messageId = "gmail:$accountId:old",
            partId = "1",
            fileName = "old.bin",
            mimeType = "application/octet-stream",
            sizeBytes = 80L * 1024L * 1024L,
            downloadState = DownloadState.AVAILABLE,
            lastAccessedAtEpochMillis = 1_000L,
        )
        val newAttachment = AttachmentEntity(
            attachmentId = "gmail:$accountId:new:1",
            messageId = "gmail:$accountId:new",
            partId = "1",
            fileName = "new.bin",
            mimeType = "application/octet-stream",
            sizeBytes = 80L * 1024L * 1024L,
            downloadState = DownloadState.NOT_FETCHED,
            lastAccessedAtEpochMillis = 0L,
        )
        val oldTarget = expectedTarget(root, accountId, oldAttachment.attachmentId, "old.bin")
        oldTarget.parentFile.mkdirs()
        oldTarget.writeBytes("old-content".encodeToByteArray())
        val newTarget = expectedTarget(root, accountId, newAttachment.attachmentId, "new.bin")

        coEvery { accountDao.account(accountId) } returns AccountEntity(accountId, "me@example.com", 1_000L, "READY")
        coEvery { mailDao.attachment(newAttachment.attachmentId) } returns newAttachment
        coEvery { mailDao.membershipsForMessage(newAttachment.messageId) } returns listOf(
            MailboxMessageEntity("$accountId:INBOX", 99L, newAttachment.messageId, "", ""),
        )
        coEvery { imapClient.fetchAttachment("me@example.com", any(), "INBOX", 99L, "1", isNull()) } returns "new-content".encodeToByteArray()
        coEvery { cacheConfigDao.get(accountId) } returns CacheConfigEntity(
            accountId = accountId,
            offlineMessageCount = 100,
            attachmentCacheLimitMb = 100,
            autoEvictReadOlderThanDays = 30,
            prefetchUnreadBodies = true,
        )
        // Return the just-downloaded attachment first to verify preservation is ID-based, not order-dependent.
        coEvery { mailDao.cachedAttachments(accountId) } returns listOf(
            newAttachment.copy(downloadState = DownloadState.AVAILABLE, lastAccessedAtEpochMillis = 5_000L),
            oldAttachment,
        )

        val result = newRepository(root).downloadAttachment(accountId, newAttachment.attachmentId)

        assertTrue(result.isSuccess)
        assertTrue(newTarget.isFile)
        assertFalse(oldTarget.exists())
        coVerify(exactly = 1) { mailDao.setAttachmentStates(listOf(oldAttachment.attachmentId), DownloadState.NOT_FETCHED) }
        coVerify(exactly = 0) { mailDao.setAttachmentStates(match { newAttachment.attachmentId in it }, any()) }
    }
}
