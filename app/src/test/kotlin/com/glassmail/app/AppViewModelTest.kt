package com.glassmail.app

import android.content.Context
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailRepository
import com.glassmail.sync.AccountSyncScheduler
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AppViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var context: Context
    private lateinit var repository: MailRepository
    private lateinit var syncScheduler: AccountSyncScheduler
    private lateinit var appearancePreferences: AppearancePreferences
    private lateinit var draftRepository: DraftRepository
    private lateinit var credentialStore: CredentialStore

    private lateinit var viewModel: AppViewModel

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)

        context = mockk(relaxed = true)
        repository = mockk(relaxed = true)
        syncScheduler = mockk(relaxed = true)
        appearancePreferences = mockk(relaxed = true)
        draftRepository = mockk(relaxed = true)
        credentialStore = mockk(relaxed = true)

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `clear invokes repository clearDebugMailbox`() = runTest {
        viewModel.clear()

        // Wait for coroutines to complete
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify(exactly = 1) { repository.clearDebugMailbox() }
    }
}
