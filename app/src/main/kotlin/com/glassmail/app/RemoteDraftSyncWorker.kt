package com.glassmail.app

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.glassmail.domain.mail.DraftStatus
import kotlinx.coroutines.flow.first
import java.util.concurrent.TimeUnit

class RemoteDraftSyncWorker(context: Context, parameters: WorkerParameters) : CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result {
        val draftId = inputData.getString(KEY_DRAFT_ID) ?: return Result.failure()
        val graph = (applicationContext as? GlassMailApplication)?.graph ?: return Result.retry()
        val draft = graph.draftRepository.observeDraft(draftId).first() ?: return Result.success()
        if (draft.status != DraftStatus.DRAFT) return Result.success()
        return if (graph.syncRemoteDraft(draft).isSuccess) Result.success() else Result.retry()
    }

    companion object {
        const val KEY_DRAFT_ID = "draft_id"
        private fun uniqueName(draftId: String) = "glassmail.remote-draft.$draftId"

        fun enqueue(context: Context, draftId: String) {
            val request = OneTimeWorkRequestBuilder<RemoteDraftSyncWorker>()
                .setInitialDelay(2, TimeUnit.SECONDS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .setInputData(workDataOf(KEY_DRAFT_ID to draftId))
                .build()
            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(uniqueName(draftId), ExistingWorkPolicy.REPLACE, request)
        }

        fun cancel(context: Context, draftId: String) {
            WorkManager.getInstance(context.applicationContext).cancelUniqueWork(uniqueName(draftId))
        }
    }
}
