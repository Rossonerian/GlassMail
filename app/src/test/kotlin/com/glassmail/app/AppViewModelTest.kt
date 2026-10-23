package com.glassmail.app

import android.content.Context
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailRepository
import com.glassmail.sync.AccountSyncScheduler
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import com.glassmail.domain.mail.MailCacheSettings
import com.glassmail.domain.mail.StorageQuota
import kotlinx.coroutines.flow.flowOf
import com.glassmail.sync.IdleServiceController
import io.mockk.mockkObject
import io.mockk.unmockkObject
import kotlinx.coroutines.launch

@OptIn(ExperimentalCoroutinesApi::class)
class AppViewModelTest {

    private lateinit var viewModel: AppViewModel
    private val context: Context = mockk(relaxed = true)
    private val repository: MailRepository = mockk(relaxed = true)
    private val syncScheduler: AccountSyncScheduler = mockk(relaxed = true)
    private val appearancePreferences: AppearancePreferences = mockk(relaxed = true)
    private val draftRepository: DraftRepository = mockk(relaxed = true)
    private val credentialStore: CredentialStore = mockk(relaxed = true)
    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockkObject(IdleServiceController)
        every { IdleServiceController.start(any()) } returns Unit
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkObject(IdleServiceController)
    }

    @Test
    fun `searchUiState emits default state when query is blank`() = runTest(testDispatcher) {
        val initialAppearance = AppearanceSettings(selectedAccountId = "account1")
        val accountsFlow = MutableStateFlow(listOf(MailAccount("account1", "test@test.com", "READY")))

        every { appearancePreferences.read() } returns initialAppearance
        every { repository.observeAccounts() } returns accountsFlow
        every { repository.observeStorageQuota(any()) } returns flowOf(null)
        every { repository.observeCacheSettings(any()) } returns flowOf(MailCacheSettings())
        every { repository.search(any(), any()) } returns flowOf(emptyList())

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )

        advanceUntilIdle()

        val job = kotlinx.coroutines.CoroutineScope(testDispatcher).launch {
            viewModel.searchUiState.collect {}
        }

        viewModel.setSearchQuery("  ")
        advanceUntilIdle()

        assertEquals(false, viewModel.searchUiState.value.isLoading)
        assertEquals("", viewModel.searchUiState.value.query)
        assertEquals(emptyList<com.glassmail.domain.mail.MailListItem>(), viewModel.searchUiState.value.messages)

        job.cancel()
    }

    @Test
    fun `searchUiState emits loading state when query changes and is not blank`() = runTest(testDispatcher) {
        val initialAppearance = AppearanceSettings(selectedAccountId = "account1")
        val accountsFlow = MutableStateFlow(listOf(MailAccount("account1", "test@test.com", "READY")))

        every { appearancePreferences.read() } returns initialAppearance
        every { repository.observeAccounts() } returns accountsFlow
        every { repository.observeStorageQuota(any()) } returns flowOf(null)
        every { repository.observeCacheSettings(any()) } returns flowOf(MailCacheSettings())

        // Mock search to delay or just never return so we can observe the intermediate loading state
        val searchFlow = MutableStateFlow<List<com.glassmail.domain.mail.MailListItem>>(emptyList())
        every { repository.search(any(), any()) } returns searchFlow

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )

        advanceUntilIdle()

        val job = kotlinx.coroutines.CoroutineScope(testDispatcher).launch {
            viewModel.searchUiState.collect {}
        }

        viewModel.setSearchQuery("query")

        // Advance exactly 100ms. Less than the 250ms debounce time.
        // Because of the flow combine, searchUiState reacts immediately to searchQuery changing.
        // The searchResults will still have result.query == ""
        // So query ("query") != result.query (""), therefore isLoading = true
        testDispatcher.scheduler.advanceTimeBy(100)
        testDispatcher.scheduler.runCurrent()

        assertEquals(true, viewModel.searchUiState.value.isLoading)
        assertEquals("query", viewModel.searchUiState.value.query)

        job.cancel()
    }

    @Test
    fun `searchUiState emits loaded state when result matches query`() = runTest(testDispatcher) {
        val initialAppearance = AppearanceSettings(selectedAccountId = "account1")
        val accountsFlow = MutableStateFlow(listOf(MailAccount("account1", "test@test.com", "READY")))

        every { appearancePreferences.read() } returns initialAppearance
        every { repository.observeAccounts() } returns accountsFlow
        every { repository.observeStorageQuota(any()) } returns flowOf(null)
        every { repository.observeCacheSettings(any()) } returns flowOf(MailCacheSettings())

        val mockItems = listOf(mockk<com.glassmail.domain.mail.MailListItem>(relaxed = true))
        every { repository.search(any(), "query") } returns flowOf(mockItems)

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )

        advanceUntilIdle()

        val job = kotlinx.coroutines.CoroutineScope(testDispatcher).launch {
            viewModel.searchUiState.collect {}
        }

        viewModel.setSearchQuery("query")

        // Advance time to allow debounce, combine and flatMapLatest to execute and finish
        advanceUntilIdle()

        assertEquals(false, viewModel.searchUiState.value.isLoading)
        assertEquals("query", viewModel.searchUiState.value.query)
        assertEquals(mockItems, viewModel.searchUiState.value.messages)

        job.cancel()
    }

    @Test
    fun `removeAccount removes current account and selects empty account`() = runTest(testDispatcher) {
        val initialAppearance = AppearanceSettings(selectedAccountId = "account1")
        val accountsFlow = MutableStateFlow(listOf(MailAccount("account1", "test@test.com", "READY")))

        every { appearancePreferences.read() } returns initialAppearance
        every { appearancePreferences.write(any()) } returns Unit
        every { repository.observeAccounts() } returns accountsFlow
        every { draftRepository.observeDrafts(any()) } returns flowOf(emptyList())
        every { repository.observeCacheSettings(any()) } returns flowOf(MailCacheSettings())
        every { repository.observeStorageQuota(any()) } returns flowOf(null as StorageQuota?)
        every { repository.observeInbox(any(), any()) } returns flowOf(emptyList())
        every { repository.observeCategoryUnreadCounts(any()) } returns flowOf(emptyMap())

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )

        advanceUntilIdle()

        viewModel.removeAccount()
        advanceUntilIdle()

        verify { syncScheduler.cancel("account1") }
        coVerify { repository.removeAccount("account1") }
        verify { IdleServiceController.start(context) }
    }

    @Test
    fun `clear invokes repository clearDebugMailbox`() = runTest(testDispatcher) {
        val initialAppearance = AppearanceSettings(selectedAccountId = "account1")
        val accountsFlow = MutableStateFlow(listOf(MailAccount("account1", "test@test.com", "READY")))

        every { appearancePreferences.read() } returns initialAppearance
        every { appearancePreferences.write(any()) } returns Unit
        every { repository.observeAccounts() } returns accountsFlow
        every { draftRepository.observeDrafts(any()) } returns flowOf(emptyList())
        every { repository.observeCacheSettings(any()) } returns flowOf(MailCacheSettings())
        every { repository.observeStorageQuota(any()) } returns flowOf(null as StorageQuota?)
        every { repository.observeInbox(any(), any()) } returns flowOf(emptyList())
        every { repository.observeCategoryUnreadCounts(any()) } returns flowOf(emptyMap())

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )

        advanceUntilIdle()

        viewModel.clear()
        advanceUntilIdle()

        coVerify(exactly = 1) { repository.clearDebugMailbox() }
    }

    @Test
    fun `setSearchQuery updates state`() = runTest(testDispatcher) {
        val initialAppearance = AppearanceSettings(selectedAccountId = "account1")
        val accountsFlow = MutableStateFlow(listOf(MailAccount("account1", "test@test.com", "READY")))

        every { appearancePreferences.read() } returns initialAppearance
        every { appearancePreferences.write(any()) } returns Unit
        every { repository.observeAccounts() } returns accountsFlow
        every { draftRepository.observeDrafts(any()) } returns flowOf(emptyList())
        every { repository.observeCacheSettings(any()) } returns flowOf(MailCacheSettings())
        every { repository.observeStorageQuota(any()) } returns flowOf(null as StorageQuota?)
        every { repository.observeInbox(any(), any()) } returns flowOf(emptyList())
        every { repository.observeCategoryUnreadCounts(any()) } returns flowOf(emptyMap())
        every { repository.search(any(), any()) } returns flowOf(emptyList())

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )

        advanceUntilIdle()

        val job = kotlinx.coroutines.CoroutineScope(testDispatcher).launch {
            viewModel.searchUiState.collect {}
        }

        viewModel.setSearchQuery("hello")
        // advance coroutines and debounce delay (250ms)
        advanceUntilIdle()

        assertEquals("hello", viewModel.searchUiState.value.query)
        job.cancel()
    }

    @Test
    fun `updateCredential updates credential store and syncs`() = runTest(testDispatcher) {
        val initialAppearance = AppearanceSettings(selectedAccountId = "account1")
        val accountsFlow = MutableStateFlow(listOf(MailAccount("account1", "test@test.com", "READY")))

        every { appearancePreferences.read() } returns initialAppearance
        every { appearancePreferences.write(any()) } returns Unit
        every { repository.observeAccounts() } returns accountsFlow
        every { draftRepository.observeDrafts(any()) } returns flowOf(emptyList())
        every { repository.observeCacheSettings(any()) } returns flowOf(MailCacheSettings())
        every { repository.observeStorageQuota(any()) } returns flowOf(null as StorageQuota?)
        every { repository.observeInbox(any(), any()) } returns flowOf(emptyList())
        every { repository.observeCategoryUnreadCounts(any()) } returns flowOf(emptyMap())

        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore
        )

        advanceUntilIdle()

        val password = charArrayOf('p', 'a', 's', 's')
        
        viewModel.updateCredential("account1", password)
        advanceUntilIdle()
        
        coVerify(exactly = 1) { credentialStore.store("account1", password) }
        coVerify(exactly = 1) { repository.synchronize("account1") }
    }

}
