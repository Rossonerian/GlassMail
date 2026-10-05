package com.glassmail.app

import android.content.Context
import androidx.lifecycle.ViewModelStore
import com.glassmail.core.model.MailSyncResult
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailListItem
import com.glassmail.domain.mail.MailMessage
import com.glassmail.domain.mail.MailMutation
import kotlinx.coroutines.flow.flowOf
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
        coEvery { repository.loadMessageBody(any()) } returns Result.failure(IllegalStateException("offline"))
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
    @Test fun `inbox archive submits every cached member once atomically with remote thread identity`() = runTest(testDispatcher) {
        advanceUntilIdle()
        val submitted = mutableListOf<List<MailMutation>>()
        coEvery { repository.applyMutations(any()) } coAnswers { submitted.add(firstArg()) }
        val item = MailListItem("gmail:account1:1", "123", "sender", "subject", "", 1, true, true, emptyList(), false,
            threadMessageIds = listOf("gmail:account1:1", "gmail:account1:2", "gmail:account1:1"))
        viewModel.mutation(item, "archive").join()
        assertEquals(1, submitted.size)
        assertEquals(listOf(
            MailMutation.Archive("account1", "gmail:account1:1", "account1:INBOX", "123"),
            MailMutation.Archive("account1", "gmail:account1:2", "account1:INBOX", "123"),
        ), submitted.single())
        assertEquals(listOf("gmail:account1:1", "gmail:account1:2"), viewModel.undoableArchive.value?.messageIds)
        coVerify(exactly = 0) { repository.applyMutation(any()) }
    }

    @Test fun `mixed starred reader conversation unstars all members using the displayed aggregate`() = runTest(testDispatcher) {
        val first = MailMessage("gmail:account1:1", "123", "s", "subject", "", "cached", false, 1, false, true, emptyList())
        val second = first.copy(messageId = "gmail:account1:2", starred = false)
        every { repository.observeMessage(first.messageId) } returns flowOf(first)
        every { repository.observeThread(first.messageId) } returns flowOf(listOf(first, second))
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.readerUiState.collect() }
        viewModel.selectReaderMessage(first.messageId)
        runCurrent()
        val submitted = mutableListOf<List<MailMutation>>()
        coEvery { repository.applyMutations(any()) } coAnswers { submitted.add(firstArg()) }
        viewModel.threadMutation(listOf(first.messageId, second.messageId), "star").join()
        assertEquals(listOf(
            MailMutation.Star("account1", first.messageId, "account1:INBOX", false, "123"),
            MailMutation.Star("account1", second.messageId, "account1:INBOX", false, "123"),
        ), submitted.single())
    }

    @Test fun `opening unread cached message enqueues offline read but background body fetch does not`() = runTest(testDispatcher) {
        advanceUntilIdle()
        val message = MailMessage("gmail:account1:1", "123", "s", "subject", "", "cached", false, 1, true, false, emptyList())
        val current = MutableStateFlow(message)
        every { repository.observeMessage(message.messageId) } returns current
        val sent = mutableListOf<MailMutation>()
        coEvery { repository.applyMutation(any()) } coAnswers {
            sent.add(firstArg())
            current.value = current.value.copy(unread = false)
        }
        viewModel.loadMessageBody(message.messageId).join()
        assertEquals(emptyList<MailMutation>(), sent)
        viewModel.selectReaderMessage(message.messageId)
        runCurrent()
        assertEquals(listOf(MailMutation.MarkRead("account1", message.messageId, null, true)), sent)
        viewModel.openReaderMessage(message.messageId)
        runCurrent()
        assertEquals(1, sent.size)
    }

    @Test fun `failed actions flow follows selected account and unified view`() = runTest(testDispatcher) {
        val a = MutableStateFlow(2)
        val b = MutableStateFlow(1)
        every { repository.observeFailedMutationCount("account1") } returns a
        every { repository.observeFailedMutationCount("account2") } returns b
        accountsFlow.value = accountsFlow.value + MailAccount("account2", "other@example.com", "READY")
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.failedMutations.collect() }
        runCurrent()
        assertEquals(mapOf("account1" to 2), viewModel.failedMutations.value)
        viewModel.selectAccount("account2")
        runCurrent()
        assertEquals(mapOf("account2" to 1), viewModel.failedMutations.value)
        viewModel.setUnifiedInbox(true)
        runCurrent()
        assertEquals(mapOf("account1" to 2, "account2" to 1), viewModel.failedMutations.value)
        a.value = 0
        runCurrent()
        assertEquals(mapOf("account2" to 1), viewModel.failedMutations.value)
    }

    @Test fun `system labels are skipped while user labels with spaces remain visible`() {
        val labels = listOf("\\Important", "\\Inbox", "\\Seen", "\\Flagged", "\\Sent", "\\Draft", "Project Alpha", "Work")
        assertEquals("Project Alpha", labels.firstOrNull(::isUserLabelChip))
    }

}
