package com.glassmail.app

import androidx.lifecycle.ViewModelStore
import com.glassmail.core.model.MailSyncError
import com.glassmail.core.model.MailSyncResult
import com.glassmail.core.security.AndroidKeystoreCredentialStore
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailRepository
import com.glassmail.domain.mail.SyncAccountUseCase
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
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
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AccountSetupViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val graph = mockk<AppGraph>()
    private val repository = mockk<MailRepository>(relaxed = true)
    private val credentials = mockk<AndroidKeystoreCredentialStore>(relaxed = true)
    private val accounts = MutableStateFlow<List<MailAccount>>(emptyList())
    private val store = ViewModelStore()
    private lateinit var vm: AccountSetupViewModel

    @Before fun setup() {
        Dispatchers.setMain(dispatcher)
        every { graph.mailRepository } returns repository
        every { graph.credentialStore } returns credentials
        every { repository.observeAccounts() } returns accounts
        coEvery { repository.createAccount(any(), any(), any()) } coAnswers {
            accounts.value = accounts.value + MailAccount(firstArg(), secondArg(), thirdArg())
        }
        coEvery { repository.removeAccount(any()) } coAnswers {
            accounts.value = accounts.value.filterNot { it.accountId == firstArg<String>() }
        }
        vm = AccountSetupViewModel(graph, SyncAccountUseCase(repository))
        store.put("setup", vm)
    }

    @After fun cleanup() { store.clear(); Dispatchers.resetMain() }

    @Test fun `wrong password for existing account keeps account and cached data available for correction`() = runTest(dispatcher) {
        val existing = MailAccount("existing", "me@example.com", "READY")
        accounts.value = listOf(existing)
        coEvery { repository.synchronize("existing") } returns MailSyncResult.Failure(MailSyncError.Authentication)
        val password = charArrayOf('b', 'a', 'd')
        vm.connect(" ME@example.com ", password)
        advanceUntilIdle()
        assertEquals(listOf(existing), accounts.value)
        assertEquals(CharArray(3).toList(), password.toList())
        assertFalse(vm.state.value.connected)
        assertEquals("Gmail rejected the account or App Password.", vm.state.value.message)
        coVerify(exactly = 0) { repository.removeAccount(any()) }
        coVerify(exactly = 0) { repository.createAccount(any(), any(), any()) }
        vm.connect("me@example.com", charArrayOf('n', 'e', 'w'))
        advanceUntilIdle()
        coVerify(exactly = 2) { credentials.store("existing", any()) }
        coVerify(exactly = 0) { repository.removeAccount(any()) }
    }

    @Test fun `new account is rolled back on authentication failure`() = runTest(dispatcher) {
        coEvery { repository.synchronize(any()) } returns MailSyncResult.Failure(MailSyncError.Authentication)
        vm.connect("new@example.com", charArrayOf('x'))
        advanceUntilIdle()
        assertEquals(emptyList<MailAccount>(), accounts.value)
        coVerify(exactly = 1) { repository.removeAccount(any()) }
    }

    @Test fun `new attempt retains rollback ownership after network failure and password reentry`() = runTest(dispatcher) {
        coEvery { repository.synchronize(any()) } returnsMany listOf(
            MailSyncResult.Failure(MailSyncError.Network), MailSyncResult.Failure(MailSyncError.Authentication),
        )
        vm.connect("new@example.com", charArrayOf('x'))
        advanceUntilIdle()
        assertEquals(1, accounts.value.size)
        vm.connect("new@example.com", charArrayOf('y'))
        advanceUntilIdle()
        assertEquals(emptyList<MailAccount>(), accounts.value)
        coVerify(exactly = 1) { repository.createAccount(any(), any(), any()) }
        coVerify(exactly = 1) { repository.removeAccount(any()) }
    }

    @Test fun `changing email during existing account retry does not remove that account`() = runTest(dispatcher) {
        val existing = MailAccount("existing", "me@example.com", "READY")
        accounts.value = listOf(existing)
        coEvery { repository.synchronize(any()) } returns MailSyncResult.Failure(MailSyncError.Network)
        vm.connect("me@example.com", charArrayOf('x'))
        advanceUntilIdle()
        vm.connect("other@example.com", charArrayOf('y'))
        advanceUntilIdle()
        assertEquals(existing, accounts.value.first())
        coVerify(exactly = 0) { repository.removeAccount("existing") }
    }
}
