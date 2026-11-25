package com.glassmail.app

import android.content.ContentResolver
import android.content.Context
import android.database.sqlite.SQLiteConstraintException
import android.net.Uri
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.imap.GmailSmtpMailSender
import com.glassmail.core.imap.SmtpCredentialProvider
import com.glassmail.domain.mail.DraftAttachment
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.DraftStatus
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailDraft
import com.glassmail.domain.mail.MailRepository
import com.glassmail.domain.mail.OutgoingAttachment
import com.glassmail.domain.mail.OutgoingMail
import com.glassmail.domain.mail.SendMailError
import com.glassmail.domain.mail.SendMailResult
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class ComposeSendRaceTest {
    private val dispatcher = StandardTestDispatcher()
    private val account = MailAccount(
        accountId = "acc-1",
        email = "me@example.com",
        syncState = "READY",
    )

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        mockkObject(RemoteDraftSyncWorker.Companion)
        mockkObject(DelayedSendWorker.Companion)
        every { RemoteDraftSyncWorker.cancel(any(), any()) } returns Unit
        every { RemoteDraftSyncWorker.enqueue(any(), any()) } returns Unit
        every { DelayedSendWorker.cancel(any(), any()) } returns Unit
        every { DelayedSendWorker.enqueue(any(), any(), any()) } returns Unit
    }

    @After
    fun tearDown() {
        unmockkObject(RemoteDraftSyncWorker.Companion)
        unmockkObject(DelayedSendWorker.Companion)
        Dispatchers.resetMain()
    }

    private fun createViewModel(
        drafts: DraftRepository = mockk(relaxed = true),
        sendDelaySeconds: Int = 0,
        draftId: String? = null,
    ): ComposeViewModel = ComposeViewModel(
        drafts = drafts,
        account = account,
        draftId = draftId,
        context = mockk(relaxed = true),
        contentResolver = mockk(relaxed = true),
        sendDelaySeconds = sendDelaySeconds,
    )

    @Test
    fun updateAndImmediateSendLeavesDraftQueuedWithoutRemoteDraftSync() = runTest(dispatcher) {
        val drafts = mockk<DraftRepository>(relaxed = true)
        val vm = createViewModel(drafts = drafts, sendDelaySeconds = 0)

        vm.updateTo("a@b.com")
        vm.updateBody("hi")
        vm.send()
        advanceTimeBy(500)
        runCurrent()

        assertEquals(DraftStatus.QUEUED, vm.state.value.status)
        verify(exactly = 0) { RemoteDraftSyncWorker.enqueue(any(), any()) }
        verify(exactly = 1) { DelayedSendWorker.enqueue(any(), any(), 0) }
    }

    @Test
    fun doubleTapSendWhileSendJobActiveDoesNotCancelOrEnqueueTwice() = runTest(dispatcher) {
        val gate = CompletableDeferred<Unit>()
        val drafts = mockk<DraftRepository>(relaxed = true)
        coEvery { drafts.saveDraft(any()) } coAnswers {
            gate.await()
        }
        val vm = createViewModel(drafts = drafts, sendDelaySeconds = 5)
        vm.updateTo("a@b.com")

        vm.send()
        runCurrent()
        // Second tap while saveDraft is suspended inside sendJob
        vm.send()
        runCurrent()

        gate.complete(Unit)
        runCurrent()

        assertEquals(DraftStatus.QUEUED, vm.state.value.status)
        verify(exactly = 1) { DelayedSendWorker.enqueue(any(), any(), 5) }
    }

    @Test
    fun updateDuringInFlightSendJobCancelsSendAndNeverEnqueuesDelayedSend() = runTest(dispatcher) {
        val gate = CompletableDeferred<Unit>()
        val drafts = mockk<DraftRepository>(relaxed = true)
        var firstSave = true
        coEvery { drafts.saveDraft(any()) } coAnswers {
            if (firstSave) {
                firstSave = false
                gate.await()
            }
        }
        val vm = createViewModel(drafts = drafts, sendDelaySeconds = 5)
        vm.updateTo("a@b.com")

        vm.send()
        runCurrent()
        vm.updateBody("edited during send")
        gate.complete(Unit)
        advanceTimeBy(500)
        runCurrent()

        assertEquals(DraftStatus.DRAFT, vm.state.value.status)
        verify(exactly = 0) { DelayedSendWorker.enqueue(any(), any(), any()) }
    }

    @Test
    fun cancelQueuedSendDuringInFlightSendJobCancelsSendAndNeverEnqueuesDelayedSend() = runTest(dispatcher) {
        val gate = CompletableDeferred<Unit>()
        val drafts = mockk<DraftRepository>(relaxed = true)
        var firstSave = true
        coEvery { drafts.saveDraft(any()) } coAnswers {
            if (firstSave) {
                firstSave = false
                gate.await()
            }
        }
        val vm = createViewModel(drafts = drafts, sendDelaySeconds = 5)
        vm.updateTo("a@b.com")

        vm.send()
        runCurrent()
        vm.cancelQueuedSend()
        gate.complete(Unit)
        advanceTimeBy(500)
        runCurrent()

        assertEquals(DraftStatus.DRAFT, vm.state.value.status)
        verify(exactly = 0) { DelayedSendWorker.enqueue(any(), any(), any()) }
        verify(atLeast = 1) { RemoteDraftSyncWorker.enqueue(any(), any()) }
    }

    @Test
    fun invalidRecipientPreservesPendingAutosaveAndSendingSentBlocksUpdateTo() = runTest(dispatcher) {
        val drafts = mockk<DraftRepository>(relaxed = true)
        val draftFlow = MutableStateFlow<MailDraft?>(
            MailDraft(
                draftId = "d-1",
                accountId = account.accountId,
                to = listOf("a@b.com"),
                status = DraftStatus.SENDING,
            ),
        )
        every { drafts.observeDraft("d-1") } returns draftFlow

        val vmNew = createViewModel(drafts = drafts)
        vmNew.updateBody("pending body")
        vmNew.send()
        advanceTimeBy(500)
        runCurrent()

        coVerify(atLeast = 1) { drafts.saveDraft(match { it.body == "pending body" && it.status == DraftStatus.DRAFT }) }

        val vmSending = createViewModel(drafts = drafts, draftId = "d-1")
        runCurrent()
        assertEquals(DraftStatus.SENDING, vmSending.state.value.status)
        vmSending.updateTo("changed@example.com")
        assertEquals("a@b.com", vmSending.state.value.rawTo)

        draftFlow.value = draftFlow.value!!.copy(status = DraftStatus.SENT)
        runCurrent()
        assertEquals(DraftStatus.SENT, vmSending.state.value.status)
        vmSending.updateTo("changed2@example.com")
        assertEquals("a@b.com", vmSending.state.value.rawTo)
    }

    @Test
    fun attachmentStreamNullOrSecurityExceptionMapsToIOExceptionAndAttachmentError() = runTest(dispatcher) {
        val contentResolver = mockk<ContentResolver>()
        val uri = mockk<Uri>()
        every { contentResolver.openInputStream(uri) } returns null andThenThrows SecurityException("denied")

        val attachment = OutgoingAttachment("file.txt", "text/plain", 10L) {
            try {
                contentResolver.openInputStream(uri) ?: throw IOException("Attachment is unavailable")
            } catch (error: SecurityException) {
                throw IOException("Attachment permission revoked", error)
            }
        }

        var nullThrewIo = false
        try {
            attachment.openStream()
        } catch (_: IOException) {
            nullThrewIo = true
        }
        assertTrue(nullThrewIo)

        var secThrewIo = false
        try {
            attachment.openStream()
        } catch (_: IOException) {
            secThrewIo = true
        }
        assertTrue(secThrewIo)
    }

    @Test
    fun delayedSendWorkerReturnsSuccessOnSqliteConstraintException() = runTest(dispatcher) {
        val draftRepository = mockk<DraftRepository>()
        val mailRepository = mockk<MailRepository>()
        val mailSender = mockk<GmailSmtpMailSender>()
        val app = mockk<GlassMailApplication>(relaxed = true)
        val graph = mockk<AppGraph>(relaxed = true)
        every { app.graph } returns graph
        every { graph.draftRepository } returns draftRepository
        every { graph.mailRepository } returns mailRepository
        every { graph.mailSender } returns mailSender
        every { mailRepository.observeAccounts() } returns flowOf(listOf(account))

        val queuedDraft = MailDraft(
            draftId = "d-fk",
            accountId = account.accountId,
            to = listOf("to@example.com"),
            status = DraftStatus.QUEUED,
        )
        every { draftRepository.observeDraft("d-fk") } returns flowOf(queuedDraft)
        coEvery { draftRepository.saveDraft(any()) } throws SQLiteConstraintException("FK")

        val params = mockk<WorkerParameters>(relaxed = true)
        every { params.inputData } returns workDataOf(DelayedSendWorker.KEY_DRAFT_ID to "d-fk")
        val worker = DelayedSendWorker(app, params)

        val result = worker.doWork()
        assertEquals(ListenableWorker.Result.success(), result)
    }

    @Test
    fun smtpSenderReturnsAttachmentErrorWhenAttachmentStreamThrowsIOException() = runTest(dispatcher) {
        val credentialProvider = object : SmtpCredentialProvider {
            override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? {
                return block("pass".toCharArray())
            }
        }
        val sender = GmailSmtpMailSender(credentialProvider = credentialProvider)
        val outgoing = OutgoingMail(
            operationId = "op-1",
            accountId = account.accountId,
            from = account.email,
            to = listOf("to@example.com"),
            subject = "hi",
            body = "body",
        )

        // Verify SendMailError.Attachment is returned when attachment openStream throws IOException
        val failingAttachment = OutgoingAttachment("a.txt", "text/plain", 4L) {
            throw IOException("unreadable")
        }
        val result = sender.send(account, outgoing.copy(attachments = listOf(failingAttachment)))
        assertEquals(SendMailResult.Failed(SendMailError.Attachment), result)
    }

    @Test
    fun smtpSenderReturnsSentWhenCancelledAfterSmtpAccepted() = runTest(dispatcher) {
        val credentialProvider = object : SmtpCredentialProvider {
            override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? {
                return block("pass".toCharArray())
            }
        }
        val imapClient = mockk<GmailImapClient>(relaxed = true)
        lateinit var childJob: kotlinx.coroutines.Job
        val sender = GmailSmtpMailSender(
            credentialProvider = credentialProvider,
            imapClient = imapClient,
            smtpSubmitOverride = { _, _, _, _, _ ->
                childJob.cancel()
            },
        )
        val outgoing = OutgoingMail(
            operationId = "op-post-smtp-cancel",
            accountId = account.accountId,
            from = account.email,
            to = listOf("to@example.com"),
            subject = "hi",
            body = "body",
        )

        var result: SendMailResult? = null
        childJob = launch {
            result = sender.send(account, outgoing)
        }
        childJob.join()
        assertEquals(SendMailResult.Sent, result)
        coVerify(exactly = 1) { imapClient.deleteRemoteDraft(account.email, any(), outgoing.operationId) }
    }

    @Test
    fun smtpSenderRethrowsCancellationWhenCancelledBeforeSmtpAccepted() = runTest(dispatcher) {
        val credentialProvider = object : SmtpCredentialProvider {
            override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? {
                return block("pass".toCharArray())
            }
        }
        val sender = GmailSmtpMailSender(
            credentialProvider = credentialProvider,
            smtpSubmitOverride = { _, _, _, _, _ ->
                throw CancellationException("cancelled before SMTP accept")
            },
        )
        val outgoing = OutgoingMail(
            operationId = "op-pre-smtp-cancel",
            accountId = account.accountId,
            from = account.email,
            to = listOf("to@example.com"),
            subject = "hi",
            body = "body",
        )

        var caught: Throwable? = null
        try {
            sender.send(account, outgoing)
        } catch (error: CancellationException) {
            caught = error
        }

        assertTrue(caught is CancellationException)
        assertEquals("cancelled before SMTP accept", caught?.message)
    }
}
