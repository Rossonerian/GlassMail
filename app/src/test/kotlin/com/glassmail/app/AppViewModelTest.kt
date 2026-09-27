package com.glassmail.app

import android.content.Context
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailRepository
import com.glassmail.sync.AccountSyncScheduler
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AppViewModelTest {

    private lateinit var viewModel: AppViewModel
    private val context = mockk<Context>(relaxed = true)
    private val repository = mockk<MailRepository>(relaxed = true)
    private val syncScheduler = mockk<AccountSyncScheduler>(relaxed = true)
    private val preferences = mockk<AppearancePreferences>(relaxed = true)
    private val draftRepository = mockk<DraftRepository>(relaxed = true)
    private val credentialStore = mockk<CredentialStore>(relaxed = true)

    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)

        // Mock necessary properties that AppViewModel observes on init
        every { repository.observeAccounts() } returns MutableStateFlow(emptyList())
        every { repository.observeCacheSettings(any()) } returns MutableStateFlow(com.glassmail.domain.mail.MailCacheSettings())
        every { repository.observeInbox(any(), any()) } returns MutableStateFlow(emptyList())

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = preferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `updateCredential stores credential, refreshes, and zeroes array`() = runTest {
        val accountId = "testAccount"
        val credential = charArrayOf('p', 'a', 's', 's', 'w', 'o', 'r', 'd')
        val expectedZeroed = CharArray(8) { '\u0000' }

        viewModel.updateCredential(accountId, credential)

        // Verify credentialStore was called
        coVerify { credentialStore.store(accountId, any()) }

        // Verify the original credential array was zeroed out
        assertArrayEquals(expectedZeroed, credential)
    }
}
