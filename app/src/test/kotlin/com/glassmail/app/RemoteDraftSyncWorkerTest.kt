package com.glassmail.app

import android.content.Context
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.glassmail.core.imap.ImapException
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.DraftStatus
import com.glassmail.domain.mail.MailDraft
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

class RemoteDraftSyncWorkerTest {
    @Test
    fun classifyRemoteDraftFailureRetriesTransportUnderMaxAttempts() {
        val error = ImapException.Transport(IOException("connection reset"))

        assertEquals(
            ListenableWorker.Result.retry(),
            RemoteDraftSyncWorker.classifyRemoteDraftFailure(error, runAttemptCount = 0),
        )
        assertEquals(
            ListenableWorker.Result.retry(),
            RemoteDraftSyncWorker.classifyRemoteDraftFailure(error, runAttemptCount = 4),
        )
    }

    @Test
    fun classifyRemoteDraftFailureStopsRetryingTransportAtMaxAttempts() {
        val error = ImapException.Transport(IOException("connection reset"))

        assertEquals(
            ListenableWorker.Result.failure(),
            RemoteDraftSyncWorker.classifyRemoteDraftFailure(error, runAttemptCount = 5),
        )
    }

    @Test
    fun classifyRemoteDraftFailureFailsImmediatelyForPermanentErrors() {
        val permanentErrors = listOf(
            ImapException.Authentication(),
            ImapException.Protocol("Server did not advertise a Drafts mailbox"),
            IOException("Draft attachment is unavailable"),
            IllegalArgumentException("Draft exceeds the message size limit"),
        )

        permanentErrors.forEach { error ->
            assertEquals(
                "Expected failure for ${error::class.simpleName}",
                ListenableWorker.Result.failure(),
                RemoteDraftSyncWorker.classifyRemoteDraftFailure(error, runAttemptCount = 0),
            )
        }
    }

    @Test
    fun doWorkBoundsMissingGraphRetriesAtMaxAttempts() = runTest {
        val context = mockk<Context>(relaxed = true)
        val draftId = "draft-missing-graph"

        val paramsAttempt0 = mockk<WorkerParameters>(relaxed = true)
        every { paramsAttempt0.inputData } returns workDataOf(RemoteDraftSyncWorker.KEY_DRAFT_ID to draftId)
        every { paramsAttempt0.runAttemptCount } returns 0
        assertEquals(ListenableWorker.Result.retry(), RemoteDraftSyncWorker(context, paramsAttempt0).doWork())

        val paramsAttempt5 = mockk<WorkerParameters>(relaxed = true)
        every { paramsAttempt5.inputData } returns workDataOf(RemoteDraftSyncWorker.KEY_DRAFT_ID to draftId)
        every { paramsAttempt5.runAttemptCount } returns 5
        assertEquals(ListenableWorker.Result.failure(), RemoteDraftSyncWorker(context, paramsAttempt5).doWork())
    }

    @Test
    fun doWorkUsesFailureClassificationAndPropagatesCancellation() = runTest {
        val draft = MailDraft(
            draftId = "draft-1",
            accountId = "acc-1",
            subject = "Subject",
            body = "Body",
            status = DraftStatus.DRAFT,
        )
        val draftRepository = mockk<DraftRepository>()
        every { draftRepository.observeDraft("draft-1") } returns flowOf(draft)

        val graph = mockk<AppGraph>(relaxed = true)
        every { graph.draftRepository } returns draftRepository

        val app = mockk<GlassMailApplication>(relaxed = true)
        every { app.graph } returns graph

        val params = mockk<WorkerParameters>(relaxed = true)
        every { params.inputData } returns workDataOf(RemoteDraftSyncWorker.KEY_DRAFT_ID to "draft-1")
        every { params.runAttemptCount } returns 0

        coEvery { graph.syncRemoteDraft(draft) } returns Result.failure(ImapException.Authentication())
        assertEquals(ListenableWorker.Result.failure(), RemoteDraftSyncWorker(app, params).doWork())

        coEvery { graph.syncRemoteDraft(draft) } returns Result.failure(ImapException.Transport(IOException("timeout")))
        assertEquals(ListenableWorker.Result.retry(), RemoteDraftSyncWorker(app, params).doWork())

        coEvery { graph.syncRemoteDraft(draft) } throws CancellationException("cancelled")
        var caught: Throwable? = null
        try {
            RemoteDraftSyncWorker(app, params).doWork()
        } catch (error: CancellationException) {
            caught = error
        }
        assertTrue(caught is CancellationException)
    }
}
