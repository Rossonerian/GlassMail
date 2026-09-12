package com.glassmail.sync

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.glassmail.core.model.MailSyncError
import com.glassmail.core.model.MailSyncResult
import com.glassmail.domain.mail.MailRepository
import kotlinx.coroutines.CancellationException
import java.util.concurrent.TimeUnit

object SyncRuntime {
    @Volatile private var repository: MailRepository? = null

    fun install(mailRepository: MailRepository) {
        repository = mailRepository
    }

    fun repository(): MailRepository? = repository
}

class AccountSyncWorker(
    appContext: Context,
    parameters: WorkerParameters,
) : CoroutineWorker(appContext, parameters) {
    override suspend fun doWork(): Result {
        val accountId = inputData.getString(KEY_ACCOUNT_ID) ?: return Result.failure()
        return when (val result = SyncRuntime.repository()?.synchronize(accountId) ?: return Result.retry()) {
            // A successful page is committed before this point. Retry is used only as a
            // bounded-background continuation for progressive mailbox enumeration; it does
            // not repeat an uncommitted operation and retains the configured backoff.
            is MailSyncResult.Success -> if (result.hasMore) Result.retry() else Result.success()
            is MailSyncResult.Failure -> when (result.error) {
                MailSyncError.Network -> Result.retry()
                MailSyncError.Authentication,
                MailSyncError.MissingCredential,
                MailSyncError.Protocol,
                -> Result.failure()
                // Do not turn cooperative cancellation into terminal work failure.
                MailSyncError.Cancelled -> throw CancellationException("Account sync cancelled")
            }
        }
    }

    companion object {
        const val KEY_ACCOUNT_ID = "account_id"
    }
}

class AccountSyncScheduler(context: Context) {
    private val workManager = WorkManager.getInstance(context.applicationContext)

    fun enqueueManual(accountId: String) = enqueueUnique(accountId, "manual")

    fun enqueueStartup(accountId: String) = enqueueUnique(accountId, "startup")

    fun schedulePeriodic(accountId: String) {
        val request = PeriodicWorkRequestBuilder<AccountSyncWorker>(24, TimeUnit.HOURS)
            .setConstraints(androidx.work.Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .setInputData(workDataOf(AccountSyncWorker.KEY_ACCOUNT_ID to accountId))
            .build()
        workManager.enqueueUniquePeriodicWork(periodicName(accountId), ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun cancel(accountId: String) {
        workManager.cancelUniqueWork(oneTimeName(accountId))
        workManager.cancelUniqueWork(periodicName(accountId))
    }

    private fun enqueueUnique(accountId: String, source: String) {
        val request = OneTimeWorkRequestBuilder<AccountSyncWorker>()
            .setConstraints(androidx.work.Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .setInputData(workDataOf(AccountSyncWorker.KEY_ACCOUNT_ID to accountId, "source" to source))
            .build()
        workManager.enqueueUniqueWork(oneTimeName(accountId), ExistingWorkPolicy.KEEP, request)
    }

    private fun oneTimeName(accountId: String) = "glassmail.account.$accountId.sync"
    private fun periodicName(accountId: String) = "glassmail.account.$accountId.periodic-sync"
}
