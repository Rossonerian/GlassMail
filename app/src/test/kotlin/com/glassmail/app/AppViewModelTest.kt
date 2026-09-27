package com.glassmail.app

import android.content.Context
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailRepository
import com.glassmail.sync.AccountSyncScheduler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher

@OptIn(ExperimentalCoroutinesApi::class)
class AppViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testSetSearchQuery() = runTest {
        val context = mock(Context::class.java)
        val mailRepository = mock(MailRepository::class.java)
        val syncScheduler = mock(AccountSyncScheduler::class.java)
        val appearancePreferences = mock(AppearancePreferences::class.java)
        val draftRepository = mock(DraftRepository::class.java)
        val credentialStore = mock(CredentialStore::class.java)

        `when`(appearancePreferences.read()).thenReturn(AppearanceSettings())
        `when`(mailRepository.observeAccounts()).thenReturn(emptyFlow())

        val viewModel = AppViewModel(
            context,
            mailRepository,
            syncScheduler,
            appearancePreferences,
            draftRepository,
            credentialStore
        )

        val collectJob = launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.searchUiState.collect { }
        }

        viewModel.setSearchQuery("test query")

        // Wait for coroutines
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals("test query", viewModel.searchUiState.value.query)
        collectJob.cancel()
    }
}
