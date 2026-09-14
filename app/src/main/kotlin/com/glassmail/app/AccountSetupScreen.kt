package com.glassmail.app

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewModelScope
import com.glassmail.core.model.MailSyncResult
import com.glassmail.domain.mail.SyncAccountUseCase
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

@Composable
fun AccountSetupRoute(graph: AppGraph) {
    val viewModel: AccountSetupViewModel = viewModel(factory = AccountSetupViewModel.factory(graph))
    val state by viewModel.state.collectAsStateWithLifecycle()
    var email by remember { mutableStateOf("") }
    var appPassword by remember { mutableStateOf("") }

    Column(
        modifier = Modifier.fillMaxSize().imePadding().navigationBarsPadding().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("GlassMail diagnostic setup", style = MaterialTheme.typography.headlineSmall)
        Text("Phase 1 connects Gmail IMAP and stores only message metadata locally.")
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Gmail address") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )
        OutlinedTextField(
            value = appPassword,
            onValueChange = { appPassword = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Google App Password") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        )
        Button(
            enabled = !state.isWorking && email.isNotBlank() && appPassword.isNotBlank(),
            onClick = {
                val credential = appPassword.toCharArray()
                appPassword = ""
                viewModel.connect(email, credential)
            },
        ) {
            Text(if (state.isWorking) "Connecting…" else "Store securely and sync")
        }
        if (BuildConfig.DEBUG) {
            Button(enabled = !state.isWorking, onClick = { viewModel.seedDebugMailbox() }) {
                Text("Use 100-message debug mailbox")
            }
        }
        Text(state.message)
        state.messageCount?.let { Text("Persisted INBOX metadata rows: $it") }
        state.gmailExtensionsEnabled?.let { Text("X-GM-EXT-1 detected: $it") }
    }
}

data class AccountSetupUiState(
    val isWorking: Boolean = false,
    val message: String = "Enter a Gmail address and Google App Password.",
    val messageCount: Int? = null,
    val gmailExtensionsEnabled: Boolean? = null,
)

class AccountSetupViewModel(
    private val graph: AppGraph,
    private val syncAccount: SyncAccountUseCase,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AccountSetupUiState())
    val state: StateFlow<AccountSetupUiState> = mutableState.asStateFlow()

    fun connect(email: String, credential: CharArray) {
        viewModelScope.launch {
            mutableState.value = AccountSetupUiState(isWorking = true, message = "Connecting securely…")
            val accountId = UUID.randomUUID().toString()
            try {
                graph.mailRepository.createAccount(accountId, email)
                graph.credentialStore.store(accountId, credential)
                when (val result = syncAccount(accountId)) {
                    is MailSyncResult.Success -> {
                        graph.syncScheduler.schedulePeriodic(accountId)
                        mutableState.value = AccountSetupUiState(
                            message = "Sync completed.",
                            messageCount = result.messageCount,
                            gmailExtensionsEnabled = result.gmailExtensionsEnabled,
                        )
                    }
                    is MailSyncResult.Failure -> mutableState.value = AccountSetupUiState(
                        message = result.error.toUserMessage(),
                    )
                }
            } catch (error: CancellationException) {
                credential.fill('\u0000')
                throw error
            } catch (_: Exception) {
                credential.fill('\u0000')
                mutableState.value = AccountSetupUiState(message = "Secure setup could not complete.")
            }
        }
    }

    fun seedDebugMailbox() {
        viewModelScope.launch {
            mutableState.value = AccountSetupUiState(isWorking = true, message = "Seeding deterministic local mailbox…")
            graph.mailRepository.seedDebugMailbox(100)
            mutableState.value = AccountSetupUiState(message = "Debug mailbox ready. Open Inbox.", messageCount = 100)
        }
    }

    companion object {
        fun factory(graph: AppGraph): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                AccountSetupViewModel(graph, graph.syncAccountUseCase) as T
        }
    }
}

private fun com.glassmail.core.model.MailSyncError.toUserMessage(): String = when (this) {
    com.glassmail.core.model.MailSyncError.Authentication -> "Gmail rejected the account or App Password."
    com.glassmail.core.model.MailSyncError.Network -> "Could not reach Gmail securely. Check network access and try again."
    com.glassmail.core.model.MailSyncError.Protocol -> "Gmail returned an unexpected IMAP response."
    com.glassmail.core.model.MailSyncError.MissingCredential -> "No credential is stored for this account."
    com.glassmail.core.model.MailSyncError.Cancelled -> "Connection cancelled."
}
