package com.glassmail.data.mail

import com.glassmail.core.database.AccountDao
import com.glassmail.core.database.AttachmentEntity
import com.glassmail.core.database.CacheConfigDao
import com.glassmail.core.database.DownloadState
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MessageDetailRow
import com.glassmail.core.database.PendingMutationDao
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.MailAttachment
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ThreadAttachmentsTest {
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
    }

    private fun newRepository() = ImapMailRepository(
        database = database,
        credentialStore = credentials,
        imapClient = imapClient,
    )

    @Test
    fun `observeThread attaches each message's attachments and leaves messages without attachments empty`() = runTest {
        val m1 = MessageDetailRow(
            messageId = "m1",
            gmailThreadId = "thread-1",
            sender = "alice@example.com",
            subject = "Project specs",
            preview = "Initial spec",
            body = "Initial spec body",
            contentKind = "PLAIN",
            sentAtEpochMillis = 1_000L,
            flags = "\\Seen",
            labels = "INBOX",
            listUnsubscribe = null,
            listUnsubscribePost = null,
        )
        val m2 = MessageDetailRow(
            messageId = "m2",
            gmailThreadId = "thread-1",
            sender = "bob@example.com",
            subject = "Re: Project specs",
            preview = "Attached updated PDF",
            body = "Attached updated PDF body",
            contentKind = "PLAIN",
            sentAtEpochMillis = 2_000L,
            flags = "",
            labels = "INBOX",
            listUnsubscribe = null,
            listUnsubscribePost = null,
        )
        val m2Attachment = AttachmentEntity(
            attachmentId = "m2:1",
            messageId = "m2",
            partId = "1",
            fileName = "specs-v2.pdf",
            mimeType = "application/pdf",
            sizeBytes = 4_096L,
            downloadState = DownloadState.NOT_FETCHED,
        )

        every { mailDao.observeThread("m1") } returns flowOf(listOf(m1, m2))
        every { mailDao.observeAttachmentsForMessages(listOf("m1", "m2")) } returns flowOf(listOf(m2Attachment))

        val messages = newRepository().observeThread("m1").first()

        assertEquals(2, messages.size)
        assertEquals("m1", messages[0].messageId)
        assertTrue(messages[0].attachments.isEmpty())
        assertEquals("m2", messages[1].messageId)
        assertEquals(
            listOf(
                MailAttachment(
                    attachmentId = "m2:1",
                    fileName = "specs-v2.pdf",
                    mimeType = "application/pdf",
                    sizeBytes = 4_096L,
                    downloadState = DownloadState.NOT_FETCHED,
                ),
            ),
            messages[1].attachments,
        )
        verify(exactly = 1) { mailDao.observeAttachmentsForMessages(listOf("m1", "m2")) }
    }

    @Test
    fun `observeThread returns empty list without querying attachments when thread has no rows`() = runTest {
        every { mailDao.observeThread("missing") } returns flowOf(emptyList())

        val messages = newRepository().observeThread("missing").first()

        assertTrue(messages.isEmpty())
        verify(exactly = 0) { mailDao.observeAttachmentsForMessages(any()) }
    }
}
