package com.glassmail.app

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.MarkEmailUnread
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
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
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing

@Composable
fun AccountSetupRoute(graph: AppGraph, onConnected: () -> Unit = {}) {
    val viewModel: AccountSetupViewModel = viewModel(factory = AccountSetupViewModel.factory(graph))
    val state by viewModel.state.collectAsStateWithLifecycle()
    var email by remember { mutableStateOf("") }
    var appPassword by remember { mutableStateOf("") }

    LaunchedEffect(state.connected) {
        if (state.connected) onConnected()
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
        contentColor = MaterialTheme.colorScheme.onBackground,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .imePadding()
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = GlassSpacing.lg, vertical = GlassSpacing.xl),
            verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
        ) {
            Spacer(Modifier.height(GlassSpacing.md))
            Icon(
                Icons.Outlined.MarkEmailUnread,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(48.dp),
            )
            Text(
                "GlassMail",
                style = MaterialTheme.typography.headlineLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
            FlatMetadata("Local-first Gmail setup", color = MaterialTheme.colorScheme.primary)
            Text(
                "Connect one Gmail account securely. Mail metadata is cached locally so the inbox stays responsive and useful offline.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

        Spacer(Modifier.height(GlassSpacing.xs))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(GlassRadius.card))
                .background(MaterialTheme.colorScheme.surface)
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(GlassRadius.card))
                .padding(GlassSpacing.md),
            verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
        ) {
            SetupField("Gmail address", email, { email = it }, "you@gmail.com", KeyboardType.Email)
            SetupField("Google App Password", appPassword, { appPassword = it }, "Stored in Android Keystore", KeyboardType.Password, password = true)

            Text(
                "For the Google account you’re adding, enable 2-Step Verification, then create an App Password under Google Account → Security → App passwords.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            val uriHandler = LocalUriHandler.current
            Text(
                text = "Open Google App Passwords",
                modifier = Modifier.clickable(role = Role.Button) {
                    uriHandler.openUri(GOOGLE_APP_PASSWORDS_URL)
                },
                style = MaterialTheme.typography.labelLarge.merge(
                    TextStyle(textDecoration = TextDecoration.Underline),
                ),
                color = MaterialTheme.colorScheme.primary,
            )

            Button(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 52.dp),
                enabled = !state.isWorking && email.isNotBlank() && (appPassword.any { !it.isWhitespace() } || state.canRetrySync),
                shape = RoundedCornerShape(GlassRadius.innerLens),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                    disabledContainerColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f),
                    disabledContentColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                ),
                onClick = {
                    if (appPassword.isBlank()) {
                        viewModel.retrySync(email)
                        return@Button
                    }
                    val credential = appPassword.filterNot(Char::isWhitespace).toCharArray()
                    appPassword = ""
                    viewModel.connect(email, credential)
                },
            ) {
                Text(
                    when {
                        state.isWorking -> "Connecting…"
                        state.canRetrySync && appPassword.none { !it.isWhitespace() } -> "Retry sync"
                        else -> "Connect & sync"
                    },
                    style = MaterialTheme.typography.labelLarge,
                )
            }
        }

        if (state.message.isNotBlank()) {
            val isSuccess = state.message.contains("completed", true) || state.message.contains("ready", true)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(GlassRadius.md))
                    .background(
                        if (isSuccess) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)
                        else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.20f)
                    )
                    .padding(horizontal = GlassSpacing.md, vertical = GlassSpacing.sm),
                verticalArrangement = Arrangement.spacedBy(GlassSpacing.xxs),
            ) {
                Text(
                    state.message,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (isSuccess) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                state.messageCount?.let {
                    Text(
                        "Synchronized messages: $it",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        if (BuildConfig.DEBUG) {
            Button(
                enabled = !state.isWorking,
                shape = RoundedCornerShape(GlassRadius.innerLens),
                colors = ButtonDefaults.filledTonalButtonColors(),
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                onClick = { viewModel.seedDebugMailbox() },
            ) {
                Text("Use 100-message debug mailbox", style = MaterialTheme.typography.labelMedium)
            }
        }
    }
    }
}

private const val GOOGLE_APP_PASSWORDS_URL = "https://myaccount.google.com/apppasswords"

@Composable
private fun SetupField(label: String, value: String, onValueChange: (String) -> Unit, placeholder: String, keyboardType: KeyboardType, password: Boolean = false) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(GlassRadius.sm))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(GlassRadius.sm))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
            singleLine = true,
            textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            visualTransformation = if (password) PasswordVisualTransformation() else VisualTransformation.None,
            decorationBox = { inner ->
                if (value.isBlank()) Text(placeholder, color = MaterialTheme.colorScheme.onSurfaceVariant)
                inner()
            },
        )
    }
}

data class AccountSetupUiState(
    val isWorking: Boolean = false,
    val message: String = "Enter a Gmail address and Google App Password.",
    val messageCount: Int? = null,
    val gmailExtensionsEnabled: Boolean? = null,
    val canRetrySync: Boolean = false,
    val connected: Boolean = false,
)

class AccountSetupViewModel(
    private val graph: AppGraph,
    private val syncAccount: SyncAccountUseCase,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AccountSetupUiState())
    val state: StateFlow<AccountSetupUiState> = mutableState.asStateFlow()
    private var pendingAccountId: String? = null
    private var pendingEmail: String? = null

    fun connect(email: String, credential: CharArray) {
        viewModelScope.launch {
            val normalizedEmail = email.trim()
            val currentAccounts = graph.mailRepository.observeAccounts().first().filterNot { it.accountId == "debug-fixture" }
            val existingAccount = currentAccounts.firstOrNull { it.email.equals(normalizedEmail, ignoreCase = true) }
            if (existingAccount == null && currentAccounts.size >= 2) {
                credential.fill('\u0000')
                mutableState.value = AccountSetupUiState(message = "The free version supports up to two accounts.")
                return@launch
            }
            val previousPendingId = pendingAccountId
            if (previousPendingId != null && !pendingEmail.equals(normalizedEmail, ignoreCase = true)) {
                graph.mailRepository.removeAccount(previousPendingId)
                pendingAccountId = null
                pendingEmail = null
            }
            val accountId = existingAccount?.accountId ?: pendingAccountId?.takeIf { pendingEmail.equals(normalizedEmail, ignoreCase = true) }
                ?: UUID.randomUUID().toString().also {
                    pendingAccountId = it
                    pendingEmail = normalizedEmail
                }
            mutableState.value = AccountSetupUiState(isWorking = true, message = "Connecting securely…")
            try {
                graph.mailRepository.createAccount(accountId, normalizedEmail, syncState = "CONNECTING")
                graph.credentialStore.store(accountId, credential)
                completeConnection(accountId)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                mutableState.value = AccountSetupUiState(
                    message = "Secure setup could not complete. Check your connection and try again.",
                    canRetrySync = true,
                )
            } finally {
                credential.fill('\u0000')
            }
        }
    }

    fun retrySync(email: String) {
        val accountId = pendingAccountId ?: return
        if (!pendingEmail.equals(email.trim(), ignoreCase = true)) {
            mutableState.value = AccountSetupUiState(message = "The email changed. Enter its App Password to connect it.")
            return
        }
        viewModelScope.launch {
            mutableState.value = AccountSetupUiState(isWorking = true, message = "Retrying mailbox sync…")
            completeConnection(accountId)
        }
    }

    private suspend fun completeConnection(accountId: String) {
        when (val result = syncAccount(accountId)) {
            is MailSyncResult.Success -> {
                graph.syncScheduler.schedulePeriodic(accountId)
                runCatching { com.glassmail.sync.IdleServiceController.start(graph.context) }
                mutableState.value = AccountSetupUiState(
                    message = "Your inbox is ready.",
                    messageCount = result.messageCount,
                    gmailExtensionsEnabled = result.gmailExtensionsEnabled,
                    connected = true,
                )
                pendingAccountId = null
                pendingEmail = null
            }
            is MailSyncResult.Failure -> {
                if (result.error == com.glassmail.core.model.MailSyncError.Authentication) {
                    graph.mailRepository.removeAccount(accountId)
                    pendingAccountId = null
                    pendingEmail = null
                    mutableState.value = AccountSetupUiState(message = result.error.toUserMessage())
                } else {
                    mutableState.value = AccountSetupUiState(
                        message = result.error.toUserMessage(),
                        canRetrySync = true,
                    )
                }
            }
        }
    }

    fun seedDebugMailbox() {
        viewModelScope.launch {
            mutableState.value = AccountSetupUiState(isWorking = true, message = "Seeding deterministic local mailbox…")
            graph.mailRepository.seedDebugMailbox(100)
            mutableState.value = AccountSetupUiState(message = "Debug mailbox ready.", messageCount = 100, connected = true)
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
