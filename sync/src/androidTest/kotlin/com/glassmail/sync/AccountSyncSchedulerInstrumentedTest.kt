package com.glassmail.sync

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.testing.TestListenableWorkerBuilder
import com.glassmail.core.model.MailSyncError
import com.glassmail.core.model.MailSyncResult
import com.glassmail.domain.mail.AccountSyncSummary
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailListItem
import com.glassmail.domain.mail.MailMessage
import com.glassmail.domain.mail.MailMutation
import com.glassmail.domain.mail.MailRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.runBlocking
import androidx.work.testing.WorkManagerTestInitHelper
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AccountSyncSchedulerInstrumentedTest {
    @Before fun init() { WorkManagerTestInitHelper.initializeTestWorkManager(ApplicationProvider.getApplicationContext()) }

    @Test fun manualSyncUsesOneUniqueAccountWorkName() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val scheduler = AccountSyncScheduler(context)
        scheduler.enqueueManual("account")
        scheduler.enqueueManual("account")
        val work = WorkManager.getInstance(context).getWorkInfosForUniqueWork("glassmail.account.account.sync").get()
        assertEquals(1, work.size)
        assertEquals(WorkInfo.State.ENQUEUED, work.single().state)
    }

    @Test fun periodicSyncUsesSeparateUniqueName() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        AccountSyncScheduler(context).schedulePeriodic("account")
        assertEquals(1, WorkManager.getInstance(context).getWorkInfosForUniqueWork("glassmail.account.account.periodic-sync").get().size)
    }

    @Test fun removingAccountWorkCancelsBothUniqueNames() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val scheduler = AccountSyncScheduler(context)
        scheduler.enqueueManual("account")
        scheduler.schedulePeriodic("account")
        scheduler.cancel("account")
        val manager = WorkManager.getInstance(context)
        assertEquals(WorkInfo.State.CANCELLED, manager.getWorkInfosForUniqueWork("glassmail.account.account.sync").get().single().state)
        assertEquals(WorkInfo.State.CANCELLED, manager.getWorkInfosForUniqueWork("glassmail.account.account.periodic-sync").get().single().state)
    }

    @Test fun workerRetriesTransportAndFailsAuthentication() = runBlocking {
        SyncRuntime.install(FakeRepository(MailSyncResult.Failure(MailSyncError.Network)))
        val retry = TestListenableWorkerBuilder<AccountSyncWorker>(ApplicationProvider.getApplicationContext())
            .setInputData(androidx.work.workDataOf(AccountSyncWorker.KEY_ACCOUNT_ID to "account"))
            .build()
        assertEquals(androidx.work.ListenableWorker.Result.retry(), retry.doWork())

        SyncRuntime.install(FakeRepository(MailSyncResult.Failure(MailSyncError.Authentication)))
        val failure = TestListenableWorkerBuilder<AccountSyncWorker>(ApplicationProvider.getApplicationContext())
            .setInputData(androidx.work.workDataOf(AccountSyncWorker.KEY_ACCOUNT_ID to "account"))
            .build()
        assertEquals(androidx.work.ListenableWorker.Result.failure(), failure.doWork())
    }

    @Test(expected = CancellationException::class)
    fun workerPropagatesCancellation() = runBlocking {
        SyncRuntime.install(FakeRepository(MailSyncResult.Failure(MailSyncError.Cancelled)))
        TestListenableWorkerBuilder<AccountSyncWorker>(ApplicationProvider.getApplicationContext())
            .setInputData(androidx.work.workDataOf(AccountSyncWorker.KEY_ACCOUNT_ID to "account"))
            .build()
            .doWork()
    }

    private class FakeRepository(private val result: MailSyncResult) : MailRepository {
        override fun observeAccounts(): Flow<List<MailAccount>> = emptyFlow()
        override fun observeAccount(accountId: String): Flow<AccountSyncSummary?> = emptyFlow()
        override fun observeInbox(accountId: String): Flow<List<MailListItem>> = emptyFlow()
        override fun search(accountId: String, query: String): Flow<List<MailListItem>> = emptyFlow()
        override fun observeMessage(messageId: String): Flow<MailMessage?> = emptyFlow()
        override suspend fun createAccount(accountId: String, email: String) = Unit
        override suspend fun removeAccount(accountId: String) = Unit
        override suspend fun synchronize(accountId: String): MailSyncResult = result
        override suspend fun applyMutation(mutation: MailMutation) = Unit
        override suspend fun seedDebugMailbox(count: Int) = Unit
        override suspend fun clearDebugMailbox() = Unit
    }
}
