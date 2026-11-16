package com.glassmail.data.mail

import android.database.sqlite.SQLiteException
import com.glassmail.core.database.AccountDao
import com.glassmail.core.database.AccountEntity
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MailDao
import com.glassmail.core.model.MailSyncError
import com.glassmail.core.model.MailSyncResult
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class RepositorySyncFailureTest {
    private val database = mockk<GlassMailDatabase>()
    private val accountDao = mockk<AccountDao>()
    private val mailDao = mockk<MailDao>()
    private val repository = ImapMailRepository(database, mockk(), mockk())

    @Test fun `cache invalidation failure is returned as a storage sync error`() = runTest {
        every { database.accountDao() } returns accountDao
        every { database.mailDao() } returns mailDao
        coEvery { accountDao.account("a") } returns AccountEntity("a", "a@example.test", 1, "READY")
        coEvery { accountDao.setSyncState("a", "SYNCING") } returns Unit
        coEvery { accountDao.setSyncState("a", "ERROR_Storage") } returns Unit
        coEvery { mailDao.invalidateTextStoredAsHtml() } throws SQLiteException("database unavailable")

        assertEquals(
            MailSyncResult.Failure(MailSyncError.Storage),
            repository.synchronize("a"),
        )
        coVerify(exactly = 1) { accountDao.setSyncState("a", "ERROR_Storage") }
    }
}
