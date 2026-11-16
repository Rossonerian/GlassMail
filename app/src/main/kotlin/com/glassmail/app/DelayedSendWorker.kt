package com.glassmail.app

import android.content.Context
import android.net.Uri
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.NetworkType
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.glassmail.domain.mail.DraftStatus
import com.glassmail.domain.mail.OutgoingAttachment
import com.glassmail.domain.mail.OutgoingMail
import com.glassmail.domain.mail.SendMailError
import com.glassmail.domain.mail.SendMailResult
import com.glassmail.domain.mail.validateAddresses
import kotlinx.coroutines.flow.first
import java.util.concurrent.TimeUnit

class DelayedSendWorker(context: Context, parameters: WorkerParameters) : CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result {
        val draftId = inputData.getString(KEY_DRAFT_ID) ?: return Result.failure()
        val graph = (applicationContext as? GlassMailApplication)?.graph ?: return Result.retry()
        val draft = graph.draftRepository.observeDraft(draftId).first() ?: return Result.success()
        if (draft.status == DraftStatus.SENDING) {
            graph.draftRepository.saveDraft(draft.copy(status = DraftStatus.UNCERTAIN, updatedAtEpochMillis = System.currentTimeMillis()))
            return Result.failure()
        }
        if (draft.status != DraftStatus.QUEUED) return Result.success()
        val account = graph.mailRepository.observeAccounts().first().firstOrNull { it.accountId == draft.accountId }
            ?: return Result.failure()
        if (!validateAddresses(draft.to + draft.cc + draft.bcc)) {
            graph.draftRepository.saveDraft(draft.copy(status = DraftStatus.FAILED, updatedAtEpochMillis = System.currentTimeMillis()))
            return Result.failure()
        }
        val attachments = mutableListOf<OutgoingAttachment>()
        for (attachment in draft.attachments) {
            val uri = Uri.parse(attachment.uri)
            val available = runCatching { applicationContext.contentResolver.openInputStream(uri)?.use { true } ?: false }.getOrDefault(false)
            if (!available) {
                graph.draftRepository.saveDraft(draft.copy(status = DraftStatus.FAILED, updatedAtEpochMillis = System.currentTimeMillis()))
                return Result.failure()
            }
            attachments += OutgoingAttachment(attachment.fileName, attachment.mimeType, attachment.sizeBytes) {
                applicationContext.contentResolver.openInputStream(uri) ?: error("Attachment is unavailable")
            }
        }
        val sending = draft.copy(status = DraftStatus.SENDING, updatedAtEpochMillis = System.currentTimeMillis())
        graph.draftRepository.saveDraft(sending)
        val outgoing = OutgoingMail(
            operationId = draft.draftId,
            accountId = account.accountId,
            from = account.email,
            to = draft.to,
            cc = draft.cc,
            bcc = draft.bcc,
            subject = draft.subject,
            body = draft.body,
            inReplyTo = draft.inReplyTo,
            references = draft.references,
            attachments = attachments,
        )
        return when (val result = graph.mailSender.send(account, outgoing)) {
            SendMailResult.Sent -> {
                graph.draftRepository.saveDraft(sending.copy(status = DraftStatus.SENT, updatedAtEpochMillis = System.currentTimeMillis()))
                Result.success()
            }
            // The server may already have accepted it. Never retry automatically: the user checks Sent first.
            SendMailResult.Uncertain -> {
                graph.draftRepository.saveDraft(sending.copy(status = DraftStatus.UNCERTAIN, updatedAtEpochMillis = System.currentTimeMillis()))
                Result.failure()
            }
            is SendMailResult.Failed -> if (result.error == SendMailError.Network && runAttemptCount < MAX_NETWORK_ATTEMPTS) {
                // Nothing was submitted: keep the draft queued and let WorkManager retry when a network is available.
                graph.draftRepository.saveDraft(sending.copy(status = DraftStatus.QUEUED, updatedAtEpochMillis = System.currentTimeMillis()))
                Result.retry()
            } else {
                graph.draftRepository.saveDraft(sending.copy(status = DraftStatus.FAILED, updatedAtEpochMillis = System.currentTimeMillis()))
                Result.failure()
            }
        }
    }

    companion object {
        const val KEY_DRAFT_ID = "draft_id"
        private const val MAX_NETWORK_ATTEMPTS = 8
        fun uniqueName(draftId: String) = "glassmail.outgoing.$draftId"

        fun enqueue(context: Context, draftId: String, delaySeconds: Int) {
            val request = OneTimeWorkRequestBuilder<DelayedSendWorker>()
                .setInitialDelay(delaySeconds.toLong(), TimeUnit.SECONDS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .setInputData(workDataOf(KEY_DRAFT_ID to draftId))
                .build()
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniqueWork(uniqueName(draftId), ExistingWorkPolicy.REPLACE, request)
        }

        fun cancel(context: Context, draftId: String) {
            WorkManager.getInstance(context.applicationContext).cancelUniqueWork(uniqueName(draftId))
        }
    }
}
