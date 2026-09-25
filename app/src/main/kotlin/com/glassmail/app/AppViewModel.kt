@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.glassmail.app

import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.AttachmentRepository
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailAttachment
import com.glassmail.domain.mail.MailDraft
import com.glassmail.domain.mail.MailListItem
import com.glassmail.domain.mail.MailMessage
import com.glassmail.domain.mail.MailMutation
import com.glassmail.domain.mail.MailRepository
import com.glassmail.sync.AccountSyncScheduler
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.io.File

class AppViewModel(
    private val context: Context,
    private val repository: MailRepository,
    private val syncScheduler: AccountSyncScheduler,
    private val appearancePreferences: AppearancePreferences,
    private val draftRepository: DraftRepository,
    private val credentialStore: CredentialStore,
) : ViewModel() {
    private val _appearance = MutableStateFlow(appearancePreferences.read())
    val appearance: StateFlow<AppearanceSettings> = _appearance
    val accounts: StateFlow<List<MailAccount>> = repository.observeAccounts()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val accountsLoaded: StateFlow<Boolean> = repository.observeAccounts()
        .map { true }
        .stateIn(viewModelScope, SharingStarted.Eagerly, false)
    private val accountId = accounts.map { it.firstOrNull()?.accountId }
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)
    val drafts: StateFlow<List<MailDraft>> = accountId.flatMapLatest { id ->
        if (id == null) flowOf(emptyList()) else draftRepository.observeDrafts(id)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private val inboxItems = accountId.flatMapLatest { id ->
        if (id == null) flowOf(emptyList()) else repository.observeInbox(id)
    }
    val inboxUiState: StateFlow<InboxUiState> = combine(accounts, inboxItems) { availableAccounts, messages ->
        InboxUiState(account = availableAccounts.firstOrNull(), messages = messages)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InboxUiState())

    private val searchQuery = MutableStateFlow("")
    val searchUiState: StateFlow<SearchUiState> = combine(accountId, searchQuery) { id, query -> id to query }
        .flatMapLatest { (id, query) ->
            if (id == null || query.isBlank()) flowOf(SearchUiState(query = query))
            else repository.search(id, query).map { SearchUiState(query = query, messages = it) }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SearchUiState())

    private val readerMessageId = MutableStateFlow<String?>(null)
    val readerUiState: StateFlow<ReaderUiState> = readerMessageId.flatMapLatest { messageId ->
        if (messageId == null) flowOf(ReaderUiState())
        else combine(repository.observeMessage(messageId), repository.observeThread(messageId)) { selected, thread ->
            ReaderUiState(selected = selected, thread = thread)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReaderUiState())

    fun mutation(item: MailListItem, type: String) = viewModelScope.launch {
        val account = accounts.value.firstOrNull() ?: return@launch
        val inboxId = "${account.accountId}:INBOX"
        repository.applyMutation(
            when (type) {
                "star" -> MailMutation.Star(account.accountId, item.messageId, inboxId, !item.starred)
                "read" -> MailMutation.MarkRead(account.accountId, item.messageId, inboxId, item.unread)
                "archive" -> MailMutation.Archive(account.accountId, item.messageId, inboxId)
                else -> MailMutation.Delete(account.accountId, item.messageId, inboxId)
            }
        )
    }

    fun setLabel(messageId: String, label: String, add: Boolean) = viewModelScope.launch {
        accounts.value.firstOrNull()?.let { repository.applyMutation(MailMutation.Label(it.accountId, messageId, null, label, add)) }
    }

    fun seed(n: Int) = viewModelScope.launch { repository.seedDebugMailbox(n) }
    fun clear() = viewModelScope.launch { repository.clearDebugMailbox() }

    fun removeAccount() = viewModelScope.launch {
        accounts.value.firstOrNull()?.let {
            syncScheduler.cancel(it.accountId)
            repository.removeAccount(it.accountId)
        }
    }

    fun refresh() = viewModelScope.launch {
        accounts.value.firstOrNull()?.let { repository.synchronize(it.accountId) }
    }

    fun setSearchQuery(query: String) {
        searchQuery.value = query
    }

    fun selectReaderMessage(messageId: String) {
        readerMessageId.value = messageId
    }

    fun updateAppearance(update: (AppearanceSettings) -> AppearanceSettings) {
        _appearance.value = update(_appearance.value)
        appearancePreferences.write(_appearance.value)
    }

    fun saveDraft(draft: MailDraft) = viewModelScope.launch {
        draftRepository.saveDraft(draft)
    }

    fun downloadAttachment(attachment: MailAttachment) = viewModelScope.launch {
        val account = accounts.value.firstOrNull() ?: return@launch
        val transfer = repository as? AttachmentRepository ?: return@launch
        transfer.downloadAttachment(account.accountId, attachment.attachmentId).onSuccess { file ->
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", File(file.filePath))
            runCatching {
                context.startActivity(Intent(Intent.ACTION_VIEW, uri).apply {
                    setDataAndType(uri, file.mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                })
            }.onFailure { Toast.makeText(context, "No app can open this attachment", Toast.LENGTH_LONG).show() }
        }.onFailure { Toast.makeText(context, "Attachment download failed", Toast.LENGTH_LONG).show() }
    }

    fun updateCredential(accountId: String, credential: CharArray) = viewModelScope.launch {
        try {
            credentialStore.store(accountId, credential)
            refresh()
        } finally {
            credential.fill('\u0000')
        }
    }

    companion object {
        fun factory(
            context: Context,
            repository: MailRepository,
            syncScheduler: AccountSyncScheduler,
            preferences: AppearancePreferences,
            draftRepository: DraftRepository,
            credentialStore: CredentialStore,
        ) = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>) =
                AppViewModel(context, repository, syncScheduler, preferences, draftRepository, credentialStore) as T
        }
    }
}

fun MailMessage.toListItem() = MailListItem(
    messageId = messageId,
    threadId = threadId,
    sender = sender,
    subject = subject,
    preview = preview,
    sentAtEpochMillis = sentAtEpochMillis,
    unread = unread,
    starred = starred,
    labels = labels,
    hasAttachment = attachments.isNotEmpty(),
)

/** Immutable Room-derived inbox state; Compose never owns a second mail list. */
data class InboxUiState(
    val account: MailAccount? = null,
    val messages: List<MailListItem> = emptyList(),
)

data class SearchUiState(
    val query: String = "",
    val messages: List<MailListItem> = emptyList(),
)

data class ReaderUiState(
    val selected: MailMessage? = null,
    val thread: List<MailMessage> = emptyList(),
)
