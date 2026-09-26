package com.glassmail.sync

import android.content.Context
import android.content.Intent
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.os.Build
import android.os.IBinder
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
import com.glassmail.domain.mail.MailAccount
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

object SyncRuntime {
    @Volatile private var repository: MailRepository? = null

    fun install(mailRepository: MailRepository) {
        repository = mailRepository
    }

    fun repository(): MailRepository? = repository
}

interface IdleSessionProvider {
    suspend fun accounts(): List<MailAccount>
    suspend fun idle(accountId: String)
    fun enqueueSync(accountId: String)
}

object IdleRuntime {
    @Volatile private var provider: IdleSessionProvider? = null
    fun install(value: IdleSessionProvider) { provider = value }
    fun provider(): IdleSessionProvider? = provider
}

class ImapIdleService : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val accountJobs = ConcurrentHashMap<String, Job>()

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(NOTIFICATION_ID, foregroundNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        serviceScope.launch { refreshAccountJobs(startId) }
        return START_STICKY
    }

    private suspend fun refreshAccountJobs(startId: Int) {
        val provider = IdleRuntime.provider()
        val accounts = runCatching { provider?.accounts().orEmpty() }.getOrDefault(emptyList())
        if (provider == null || accounts.isEmpty()) {
            accountJobs.values.forEach { it.cancel() }
            accountJobs.clear()
            stopSelf(startId)
            return
        }
        val ids = accounts.map { it.accountId }.toSet()
        (accountJobs.keys - ids).forEach { accountId -> accountJobs.remove(accountId)?.cancel() }
        accounts.forEach { account ->
            accountJobs.computeIfAbsent(account.accountId) { id ->
                serviceScope.launch { maintainIdle(provider, id) }
            }
        }
    }

    private suspend fun maintainIdle(provider: IdleSessionProvider, accountId: String) {
        var retryDelay = 2_000L
        while (serviceScope.isActive) {
            try {
                if (provider.accounts().none { it.accountId == accountId }) return
                provider.idle(accountId)
                retryDelay = 2_000L
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                delay(retryDelay)
                retryDelay = (retryDelay * 2).coerceAtMost(5 * 60_000L)
            }
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL_ID, "Mailbox connection", NotificationManager.IMPORTANCE_MIN)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun foregroundNotification(): Notification =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
            .setContentTitle("GlassMail is keeping mail up to date")
            .setContentText("Secure mailbox connection is active")
            .setOngoing(true)
            .build()
        else @Suppress("DEPRECATION") Notification.Builder(this)
            .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
            .setContentTitle("GlassMail is keeping mail up to date")
            .setOngoing(true)
            .build()

    override fun onDestroy() {
        accountJobs.values.forEach { it.cancel() }
        accountJobs.clear()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "glassmail_mailbox_idle"
        private const val NOTIFICATION_ID = 7301
    }
}

object IdleServiceController {
    fun start(context: Context) {
        val intent = Intent(context.applicationContext, ImapIdleService::class.java)
        if (Build.VERSION.SDK_INT >= 26) context.applicationContext.startForegroundService(intent)
        else context.applicationContext.startService(intent)
    }
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

class CacheEvictionWorker(appContext: Context, parameters: WorkerParameters) : CoroutineWorker(appContext, parameters) {
    override suspend fun doWork(): Result {
        val accountId = inputData.getString(AccountSyncWorker.KEY_ACCOUNT_ID) ?: return Result.failure()
        val repository = SyncRuntime.repository() ?: return Result.retry()
        repository.enforceCacheLimits(accountId)
        return Result.success()
    }
}

class AccountSyncScheduler(context: Context) {
    private val workManager = WorkManager.getInstance(context.applicationContext)

    fun enqueueManual(accountId: String) = enqueueUnique(accountId, "manual")

    fun enqueueStartup(accountId: String) = enqueueUnique(accountId, "startup")

    fun schedulePeriodic(accountId: String) {
        val request = PeriodicWorkRequestBuilder<AccountSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(androidx.work.Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .setInputData(workDataOf(AccountSyncWorker.KEY_ACCOUNT_ID to accountId))
            .build()
        workManager.enqueueUniquePeriodicWork(periodicName(accountId), ExistingPeriodicWorkPolicy.KEEP, request)
        val eviction = PeriodicWorkRequestBuilder<CacheEvictionWorker>(24, TimeUnit.HOURS)
            .setConstraints(androidx.work.Constraints.Builder().setRequiredNetworkType(NetworkType.NOT_REQUIRED).build())
            .setInputData(workDataOf(AccountSyncWorker.KEY_ACCOUNT_ID to accountId))
            .build()
        workManager.enqueueUniquePeriodicWork(cacheName(accountId), ExistingPeriodicWorkPolicy.KEEP, eviction)
    }

    fun cancel(accountId: String) {
        workManager.cancelUniqueWork(oneTimeName(accountId))
        workManager.cancelUniqueWork(periodicName(accountId))
        workManager.cancelUniqueWork(cacheName(accountId))
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
    private fun cacheName(accountId: String) = "glassmail.account.$accountId.cache-eviction"
}
