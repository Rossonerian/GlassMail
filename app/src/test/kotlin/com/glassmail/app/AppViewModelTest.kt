package com.glassmail.app

import android.content.Context
import androidx.lifecycle.ViewModelStore
import com.glassmail.core.model.MailSyncResult
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailListItem
import com.glassmail.domain.mail.OlderMailResult
import com.glassmail.domain.mail.MailRepository
import com.glassmail.sync.AccountSyncScheduler
import com.glassmail.sync.IdleServiceController
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.coVerifyOrder
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AppViewModelTest {
    private lateinit var viewModel: AppViewModel
    private val viewModelStore = ViewModelStore()
    private val context: Context = mockk(relaxed = true)
    private val repository: MailRepository = mockk(relaxed = true)
    private val syncScheduler: AccountSyncScheduler = mockk(relaxed = true)
    private val appearancePreferences: AppearancePreferences = mockk(relaxed = true)
    private val draftRepository: DraftRepository = mockk(relaxed = true)
    private val credentialStore: CredentialStore = mockk(relaxed = true)
    private val testDispatcher = StandardTestDispatcher()
    private val accountsFlow = MutableStateFlow(listOf(MailAccount("account1", "test@test.com", "READY")))

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockkObject(IdleServiceController)
        every { IdleServiceController.start(any()) } returns Unit
        every { appearancePreferences.read() } returns AppearanceSettings(selectedAccountId = "account1")
        every { repository.observeAccounts() } returns accountsFlow
        viewModel = AppViewModel(
            context = context,
            repository = repository,
            syncScheduler = syncScheduler,
            appearancePreferences = appearancePreferences,
            draftRepository = draftRepository,
            credentialStore = credentialStore,
        )
        viewModelStore.put("test", viewModel)
    }

    @After
    fun tearDown() {
        viewModelStore.clear()
        Dispatchers.resetMain()
        unmockkObject(IdleServiceController)
    }

    @Test
    fun `older mail exposes loading suppresses duplicate request and becomes exhausted`() = runTest(testDispatcher) {
        val response = CompletableDeferred<OlderMailResult>()
        var requests = 0
        coEvery { repository.loadOlder("account1") } coAnswers { requests++; response.await() }
        val first = viewModel.loadOlder("account1")
        runCurrent()
        assertEquals(true, viewModel.olderMail.value["account1"]?.isLoading)
        viewModel.loadOlder("account1")
        runCurrent()
        assertEquals(1, requests)
        response.complete(OlderMailResult.Success(2, hasMoreOlder = false))
        first.join()
        assertEquals(OlderMailUiState(hasMoreOlder = false), viewModel.olderMail.value["account1"])
    }

    @Test
    fun `cache setting change during older request clears stale exhausted result`() = runTest(testDispatcher) {
        val response = CompletableDeferred<OlderMailResult>()
        coEvery { repository.loadOlder("account1") } coAnswers { response.await() }
        val request = viewModel.loadOlder("account1")
        runCurrent()
        viewModel.updateCacheSettings { it.copy(offlineMessageCount = 500) }.join()
        response.complete(OlderMailResult.Success(0, hasMoreOlder = false, cacheLimitReached = true))
        request.join()
        assertEquals(OlderMailUiState(), viewModel.olderMail.value["account1"])
    }

    @Test
    fun `failed older mail remains retryable and cancellation clears loading`() = runTest(testDispatcher) {
        coEvery { repository.loadOlder("account1") } returns OlderMailResult.Failure(com.glassmail.core.model.MailSyncError.Network)
        viewModel.loadOlder("account1").join()
        assertEquals(OlderMailUiState(failed = true), viewModel.olderMail.value["account1"])
        val response = CompletableDeferred<OlderMailResult>()
        coEvery { repository.loadOlder("account1") } coAnswers { response.await() }
        val request = viewModel.loadOlder("account1")
        runCurrent()
        assertEquals(true, viewModel.olderMail.value["account1"]?.isLoading)
        request.cancel()
        request.join()
        assertEquals(OlderMailUiState(failed = true), viewModel.olderMail.value["account1"])
    }

    @Test
    fun `removeAccount delegates all cleanup to repository entry point`() = runTest(testDispatcher) {
        advanceUntilIdle()

        viewModel.removeAccount()
        advanceUntilIdle()

        verify(exactly = 0) { syncScheduler.cancel(any()) }
        coVerify(exactly = 1) { repository.removeAccount("account1") }
        verify(exactly = 0) { IdleServiceController.start(any()) }
    }

    @Test
    fun `clear invokes repository clearDebugMailbox`() = runTest(testDispatcher) {
        advanceUntilIdle()

        viewModel.clear()
        advanceUntilIdle()

        coVerify(exactly = 1) { repository.clearDebugMailbox() }
    }

    @Test
    fun `setSearchQuery exposes loading then debounced results and clears blank query`() = runTest(testDispatcher) {
        val result = MailListItem(
            messageId = "message1",
            threadId = null,
            sender = "sender@test.com",
            subject = "hello",
            preview = "matching message",
            sentAtEpochMillis = 1L,
            unread = true,
            starred = false,
            labels = emptyList(),
            hasAttachment = false,
        )
        every { repository.search("account1", "hello") } returns MutableStateFlow(listOf(result))
        // These states use WhileSubscribed; keep a collector alive for the test.
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            viewModel.searchUiState.collect()
        }
        runCurrent()
        assertEquals(SearchUiState(), viewModel.searchUiState.value)

        viewModel.setSearchQuery("hello")
        runCurrent()
        assertEquals(SearchUiState(query = "hello", isLoading = true), viewModel.searchUiState.value)
        advanceTimeBy(249)
        runCurrent()
        verify(exactly = 0) { repository.search(any(), any()) }

        advanceTimeBy(1)
        runCurrent()
        verify(exactly = 1) { repository.search("account1", "hello") }
        assertEquals(SearchUiState(query = "hello", messages = listOf(result)), viewModel.searchUiState.value)

        viewModel.setSearchQuery("")
        runCurrent()
        assertEquals(SearchUiState(), viewModel.searchUiState.value)
        advanceTimeBy(250)
        runCurrent()
        verify(exactly = 1) { repository.search(any(), any()) }
    }

    @Test
    fun `updateCredential stores original credential before refresh and wipes input`() = runTest(testDispatcher) {
        var storedCredential: CharArray? = null
        coEvery { credentialStore.store("account1", any()) } coAnswers {
            // Copy at call time because production wipes the caller's array afterward.
            storedCredential = secondArg<CharArray>().copyOf()
        }
        coEvery { repository.synchronize("account1") } returns MailSyncResult.Success(0, false)
        advanceUntilIdle()
        val password = charArrayOf('p', 'a', 's', 's')

        viewModel.updateCredential("account1", password)
        advanceUntilIdle()

        coVerify(exactly = 1) { credentialStore.store("account1", any()) }
        coVerify(exactly = 1) { repository.synchronize("account1") }
        coVerifyOrder {
            credentialStore.store("account1", any())
            repository.synchronize("account1")
        }
        assertArrayEquals(charArrayOf('p', 'a', 's', 's'), storedCredential)
        assertArrayEquals(CharArray(4), password)
    }
}
