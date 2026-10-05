@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class, kotlinx.coroutines.FlowPreview::class)

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
import com.glassmail.domain.mail.MailCategory
import com.glassmail.domain.mail.MailRepository
import com.glassmail.domain.mail.OlderMailResult
import com.glassmail.domain.mail.MailCacheSettings
import com.glassmail.domain.mail.StorageQuota
import com.glassmail.sync.AccountSyncScheduler
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

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
    private val accountId = combine(accounts, _appearance) { available, settings ->
        settings.selectedAccountId?.takeIf { chosen -> available.any { it.accountId == chosen } } ?: available.firstOrNull()?.accountId
    }
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)
    val drafts: StateFlow<List<MailDraft>> = accounts.flatMapLatest { available ->
        if (available.isEmpty()) flowOf(emptyList()) else combine(available.map { draftRepository.observeDrafts(it.accountId) }) { lists ->
            lists.flatMap { it }.filter { it.status != com.glassmail.domain.mail.DraftStatus.SENT }
                .sortedByDescending(MailDraft::updatedAtEpochMillis)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val cacheSettings: StateFlow<MailCacheSettings> = accountId.flatMapLatest { id ->
        if (id == null) flowOf(MailCacheSettings()) else repository.observeCacheSettings(id)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), MailCacheSettings())
    val storageQuota: StateFlow<StorageQuota?> = accountId.flatMapLatest { id ->
        if (id == null) flowOf(null) else repository.observeStorageQuota(id)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    private val selectedCategory = MutableStateFlow(MailCategory.PRIMARY)
    private val inboxData = combine(accounts, accountId, selectedCategory, _appearance.map { it.unifiedInbox }) { available, id, category, unified ->
        InboxInputs(available, id, category, unified)
    }.flatMapLatest { input ->
            val ids = input.accounts.map { it.accountId }
            if (input.unified) combine(
                repository.observeUnifiedInbox(ids, input.category),
                repository.observeUnifiedCategoryUnreadCounts(ids),
            ) { messages, unreadCounts -> InboxData(messages, unreadCounts) }
            else if (input.accountId == null) flowOf(InboxData())
            else combine(
                repository.observeInbox(input.accountId, input.category),
                repository.observeCategoryUnreadCounts(input.accountId),
            ) { messages, unreadCounts -> InboxData(messages, unreadCounts) }
        }
    val inboxUiState: StateFlow<InboxUiState> = combine(accounts, accountId, selectedCategory, inboxData, _appearance.map { it.unifiedInbox }) { availableAccounts, selectedId, category, data, unified ->
        InboxUiState(
            account = if (unified) null else availableAccounts.firstOrNull { it.accountId == selectedId },
            accounts = availableAccounts,
            unifiedInbox = unified,
            messages = data.messages,
            selectedCategory = category,
            unreadByCategory = data.unreadByCategory,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InboxUiState())

    val failedMutations: StateFlow<Map<String, Int>> = combine(accounts, accountId, _appearance.map { it.unifiedInbox }) { available, id, unified ->
        if (unified) available.map { it.accountId } else listOfNotNull(id)
    }.flatMapLatest { ids ->
        if (ids.isEmpty()) flowOf(emptyMap()) else combine(ids.map { id -> repository.observeFailedMutationCount(id).map { id to it } }) { counts ->
            counts.filter { it.second > 0 }.toMap()
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyMap())

    fun retryFailedActions(accountIds: List<String>) = viewModelScope.launch {
        accountIds.forEach { repository.retryFailedMutations(it) }
    }

    fun dismissFailedActions(accountIds: List<String>) = viewModelScope.launch {
        accountIds.forEach { repository.dismissFailedMutations(it) }
    }

    private val searchQuery = MutableStateFlow("")
    private val searchResults: StateFlow<SearchUiState> = combine(accounts, accountId, _appearance.map { it.unifiedInbox }, searchQuery.debounce(250)) { available, id, unified, query ->
        SearchInputs(available.map { it.accountId }, id, unified, query)
    }.flatMapLatest { input ->
            if (input.query.isBlank() || (input.accountId == null && !input.unified)) flowOf(SearchUiState(query = input.query))
            else (if (input.unified) repository.searchUnified(input.accountIds, input.query) else repository.search(input.accountId!!, input.query))
                .map { SearchUiState(query = input.query, messages = it) }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SearchUiState())
    val searchUiState: StateFlow<SearchUiState> = combine(searchQuery, searchResults) { query, result ->
        when {
            query.isBlank() -> SearchUiState()
            query == result.query -> result.copy(isLoading = false)
            else -> SearchUiState(query = query, isLoading = true)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SearchUiState())

    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing
    private val _olderMail = MutableStateFlow<Map<String, OlderMailUiState>>(emptyMap())
    val olderMail: StateFlow<Map<String, OlderMailUiState>> = _olderMail
    private val invalidatedOlderMail = mutableSetOf<String>()

    private fun invalidateOlderMail(accountId: String) {
        if (_olderMail.value[accountId]?.isLoading == true) invalidatedOlderMail.add(accountId)
        else _olderMail.value = _olderMail.value - accountId
    }

    private fun completeOlderMail(accountId: String, state: OlderMailUiState) {
        val resolved = if (invalidatedOlderMail.remove(accountId)) OlderMailUiState() else state
        _olderMail.value = _olderMail.value + (accountId to resolved)
    }

    fun loadOlder(accountId: String) = viewModelScope.launch {
        if (_olderMail.value[accountId]?.isLoading == true) return@launch
        val previous = _olderMail.value[accountId] ?: OlderMailUiState()
        _olderMail.value = _olderMail.value + (accountId to previous.copy(isLoading = true, failed = false))
        try {
            val result = repository.loadOlder(accountId)
            val state = when (result) {
                is OlderMailResult.Success -> OlderMailUiState(
                    hasMoreOlder = result.hasMoreOlder, cacheLimitReached = result.cacheLimitReached,
                )
                is OlderMailResult.Failure -> previous.copy(failed = true)
            }
            completeOlderMail(accountId, state)
        } catch (error: CancellationException) {
            completeOlderMail(accountId, previous)
            throw error
        } catch (_: Exception) {
            completeOlderMail(accountId, previous.copy(failed = true))
        }
    }

    private val _undoableArchive = MutableStateFlow<UndoableArchive?>(null)
    val undoableArchive: StateFlow<UndoableArchive?> = _undoableArchive

    private val readerMessageId = MutableStateFlow<String?>(null)
    val readerUiState: StateFlow<ReaderUiState> = readerMessageId.flatMapLatest { messageId ->
        if (messageId == null) flowOf(ReaderUiState())
        else combine(repository.observeMessage(messageId), repository.observeThread(messageId)) { selected, thread ->
            ReaderUiState(selected = selected, thread = thread)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReaderUiState())

    fun mutation(item: MailListItem, type: String) = viewModelScope.launch {
        val threadIds = item.threadMessageIds.distinct().ifEmpty { listOf(item.messageId) }
        val mutations = threadIds.mapNotNull { messageId ->
            val account = accountForMessage(messageId) ?: return@mapNotNull null
            val inboxId = "${account.accountId}:INBOX"
            when (type) {
                "star" -> MailMutation.Star(account.accountId, messageId, inboxId, !item.starred, item.threadId)
                "read" -> MailMutation.MarkRead(account.accountId, messageId, inboxId, item.unread, item.threadId)
                "archive" -> MailMutation.Archive(account.accountId, messageId, inboxId, item.threadId)
                "delete" -> MailMutation.Delete(account.accountId, messageId, inboxId, item.threadId)
                else -> null
            }
        }
        repository.applyMutations(mutations)
        if (type == "archive" && mutations.isNotEmpty()) _undoableArchive.value = UndoableArchive(UUID.randomUUID().toString(), mutations.map { it.messageId })
    }

    fun threadMutation(messageIds: List<String>, type: String, desiredStarred: Boolean? = null) = viewModelScope.launch {
        val messages = messageIds.distinct()
        val currentThread = messages.mapNotNull { id -> readerUiState.value.thread.firstOrNull { it.messageId == id } }
        val star = desiredStarred ?: !currentThread.any { it.starred }
        val mutations = messages.mapNotNull { messageId ->
            val account = accountForMessage(messageId) ?: return@mapNotNull null
            val inboxId = "${account.accountId}:INBOX"
            val threadId = currentThread.firstOrNull { it.messageId == messageId }?.threadId
            when (type) {
                "star" -> MailMutation.Star(account.accountId, messageId, inboxId, star, threadId)
                "archive" -> MailMutation.Archive(account.accountId, messageId, inboxId, threadId)
                "delete" -> MailMutation.Delete(account.accountId, messageId, inboxId, threadId)
                else -> null
            }
        }
        repository.applyMutations(mutations)
    }

    fun undoArchive(actionId: String) = viewModelScope.launch {
        val action = _undoableArchive.value?.takeIf { it.actionId == actionId } ?: return@launch
        repository.undoPendingArchives(action.messageIds)
        if (_undoableArchive.value?.actionId == actionId) _undoableArchive.value = null
    }

    fun dismissUndoArchive(actionId: String) {
        if (_undoableArchive.value?.actionId == actionId) _undoableArchive.value = null
    }

    fun accountForMessage(messageId: String): MailAccount? = accounts.value.firstOrNull { account ->
        messageId.startsWith("gmail:${account.accountId}:") || messageId.startsWith("imap:${account.accountId}:")
    } ?: accounts.value.firstOrNull { it.accountId == accountId.value }

    fun currentAccount(): MailAccount? = accounts.value.firstOrNull { it.accountId == accountId.value } ?: accounts.value.firstOrNull()

    fun selectAccount(accountId: String) {
        updateAppearance { it.copy(selectedAccountId = accountId, unifiedInbox = false) }
    }

    fun setUnifiedInbox(enabled: Boolean) {
        updateAppearance { it.copy(unifiedInbox = enabled) }
    }

    fun setLabel(messageId: String, label: String, add: Boolean) = viewModelScope.launch {
        accountForMessage(messageId)?.let { repository.applyMutation(MailMutation.Label(it.accountId, messageId, null, label, add)) }
    }

    fun seed(n: Int) = viewModelScope.launch { repository.seedDebugMailbox(n) }
    fun clear() = viewModelScope.launch { repository.clearDebugMailbox() }

    fun removeAccount() = viewModelScope.launch {
        accounts.value.firstOrNull { it.accountId == accountId.value }?.let {
            repository.removeAccount(it.accountId)
        }
    }

    fun refresh() = viewModelScope.launch {
        if (_isRefreshing.value) return@launch
        _isRefreshing.value = true
        try {
            val selected = if (_appearance.value.unifiedInbox) accounts.value else listOfNotNull(accounts.value.firstOrNull { it.accountId == accountId.value })
            selected.forEach { account ->
                val result = repository.synchronize(account.accountId)
                // Membership changes or a namespace reset can make older mail available.
                if (result is com.glassmail.core.model.MailSyncResult.Success) invalidateOlderMail(account.accountId)
            }
        } finally {
            _isRefreshing.value = false
        }
    }

    fun setSearchQuery(query: String) {
        searchQuery.value = query
    }

    fun selectCategory(category: String) {
        if (category in MailCategory.all) selectedCategory.value = category
    }

    fun selectReaderMessage(messageId: String) {
        readerMessageId.value = messageId
        openReaderMessage(messageId)
    }

    fun openReaderMessage(messageId: String) {
        viewModelScope.launch {
            val message = repository.observeMessage(messageId).first() ?: return@launch
            if (message.unread) accountForMessage(messageId)?.let { account ->
                repository.applyMutation(MailMutation.MarkRead(account.accountId, messageId, null, true))
            }
        }
        loadMessageBody(messageId)
    }

    fun loadMessageBody(messageId: String) = viewModelScope.launch {
        repository.loadMessageBody(messageId)
    }

    fun updateAppearance(update: (AppearanceSettings) -> AppearanceSettings) {
        _appearance.value = update(_appearance.value)
        appearancePreferences.write(_appearance.value)
    }

    fun updateCacheSettings(update: (MailCacheSettings) -> MailCacheSettings) = viewModelScope.launch {
        accountId.value?.let {
            repository.saveCacheSettings(it, update(cacheSettings.value))
            invalidateOlderMail(it)
        }
    }

    fun refreshStorageQuota() = viewModelScope.launch {
        val targets = if (_appearance.value.unifiedInbox) accounts.value else listOfNotNull(currentAccount())
        targets.forEach { repository.refreshStorageQuota(it.accountId) }
    }

    fun saveDraft(draft: MailDraft) = viewModelScope.launch {
        draftRepository.saveDraft(draft)
        if (draft.status == com.glassmail.domain.mail.DraftStatus.DRAFT) RemoteDraftSyncWorker.enqueue(context, draft.draftId)
    }

    fun downloadAttachment(attachment: MailAttachment) = viewModelScope.launch {
        val account = accountForMessage(attachment.attachmentId.substringBeforeLast(':')) ?: accounts.value.firstOrNull { it.accountId == accountId.value } ?: return@launch
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
            repository.synchronize(accountId)
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
    val accounts: List<MailAccount> = emptyList(),
    val unifiedInbox: Boolean = false,
    val messages: List<MailListItem> = emptyList(),
    val selectedCategory: String = MailCategory.PRIMARY,
    val unreadByCategory: Map<String, Int> = emptyMap(),
)

private data class InboxData(
    val messages: List<MailListItem> = emptyList(),
    val unreadByCategory: Map<String, Int> = emptyMap(),
)

private data class InboxInputs(val accounts: List<MailAccount>, val accountId: String?, val category: String, val unified: Boolean)
private data class SearchInputs(val accountIds: List<String>, val accountId: String?, val unified: Boolean, val query: String)

data class SearchUiState(
    val query: String = "",
    val messages: List<MailListItem> = emptyList(),
    val isLoading: Boolean = false,
)

data class UndoableArchive(val actionId: String, val messageIds: List<String>)

data class ReaderUiState(
    val selected: MailMessage? = null,
    val thread: List<MailMessage> = emptyList(),
)

/** Per-account transient request state; never stored in saved state or preferences. */
data class OlderMailUiState(
    val isLoading: Boolean = false,
    val hasMoreOlder: Boolean = true,
    val cacheLimitReached: Boolean = false,
    val failed: Boolean = false,
)
