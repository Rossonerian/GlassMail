package com.glassmail.domain.mail

import com.glassmail.core.model.MailSyncResult
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.combine

interface MailRepository {
    fun observeAccounts(): Flow<List<MailAccount>>
    fun observeAccount(accountId: String): Flow<AccountSyncSummary?>
    fun observeInbox(accountId: String): Flow<List<MailListItem>>
    fun observeInbox(accountId: String, category: String): Flow<List<MailListItem>> = observeInbox(accountId)
    fun observeUnifiedInbox(accountIds: List<String>, category: String): Flow<List<MailListItem>> =
        if (accountIds.isEmpty()) flowOf(emptyList()) else combine(accountIds.map { observeInbox(it, category) }) { lists ->
            lists.flatMap { it }.sortedByDescending { it.sentAtEpochMillis ?: Long.MIN_VALUE }
        }
    fun observeCategoryUnreadCounts(accountId: String): Flow<Map<String, Int>> = flowOf(emptyMap())
    fun observeUnifiedCategoryUnreadCounts(accountIds: List<String>): Flow<Map<String, Int>> =
        if (accountIds.isEmpty()) flowOf(emptyMap()) else combine(accountIds.map(::observeCategoryUnreadCounts)) { maps ->
            maps.flatMap { it.entries }.groupBy({ it.key }, { it.value }).mapValues { (_, values) -> values.sum() }
        }
    fun search(accountId: String, query: String): Flow<List<MailListItem>>
    fun searchUnified(accountIds: List<String>, query: String): Flow<List<MailListItem>> =
        if (accountIds.isEmpty()) flowOf(emptyList()) else combine(accountIds.map { search(it, query) }) { lists ->
            lists.flatMap { it }.sortedByDescending { it.sentAtEpochMillis ?: Long.MIN_VALUE }
        }
    fun observeCacheSettings(accountId: String): Flow<MailCacheSettings> = flowOf(MailCacheSettings())
    fun observeStorageQuota(accountId: String): Flow<StorageQuota?> = flowOf(null)
    suspend fun saveCacheSettings(accountId: String, settings: MailCacheSettings) = Unit
    suspend fun enforceCacheLimits(accountId: String) = Unit
    suspend fun refreshStorageQuota(accountId: String): Result<StorageQuota> = Result.failure(UnsupportedOperationException("Storage quota is unavailable"))
    fun observeMessage(messageId: String): Flow<MailMessage?>
    fun observeThread(messageId: String): Flow<List<MailMessage>>
    suspend fun createAccount(accountId: String, email: String, syncState: String = "READY")
    suspend fun removeAccount(accountId: String)
    suspend fun synchronize(accountId: String): MailSyncResult
    suspend fun applyMutation(mutation: MailMutation)
    suspend fun undoPendingArchive(messageId: String): Boolean = false
    suspend fun seedDebugMailbox(count: Int)
    suspend fun clearDebugMailbox()
    suspend fun loadMessageBody(messageId: String): Result<MailMessage>
}

data class DownloadedAttachment(val filePath: String, val fileName: String, val mimeType: String)

interface AttachmentRepository {
    suspend fun downloadAttachment(accountId: String, attachmentId: String): Result<DownloadedAttachment>
}

data class MailAccount(val accountId: String, val email: String, val syncState: String)
object MailCategory {
    const val PRIMARY = "PRIMARY"
    const val SOCIAL = "SOCIAL"
    const val PROMOTIONS = "PROMOTIONS"
    const val UPDATES = "UPDATES"
    const val FORUMS = "FORUMS"

    val all = listOf(PRIMARY, SOCIAL, PROMOTIONS, UPDATES, FORUMS)
}

data class MailListItem(
    val messageId: String,
    val threadId: String?,
    val sender: String,
    val subject: String,
    val preview: String,
    val sentAtEpochMillis: Long?,
    val unread: Boolean,
    val starred: Boolean,
    val labels: List<String>,
    val hasAttachment: Boolean,
    val category: String = MailCategory.PRIMARY,
    val messageCount: Int = 1,
    val participantCount: Int = 1,
    val threadMessageIds: List<String> = listOf(messageId),
)
data class MailAttachment(val attachmentId: String, val fileName: String?, val mimeType: String?, val sizeBytes: Long?, val downloadState: String)
data class MailMessage(val messageId: String, val threadId: String?, val sender: String, val subject: String, val preview: String, val body: String?, val html: Boolean, val sentAtEpochMillis: Long?, val unread: Boolean, val starred: Boolean, val labels: List<String>, val attachments: List<MailAttachment> = emptyList(), val listUnsubscribe: String? = null, val listUnsubscribePost: String? = null)

sealed interface MailMutation {
    val accountId: String
    val messageId: String
    val mailboxId: String?

    data class MarkRead(override val accountId: String, override val messageId: String, override val mailboxId: String?, val read: Boolean) : MailMutation
    data class Star(override val accountId: String, override val messageId: String, override val mailboxId: String?, val starred: Boolean) : MailMutation
    data class Archive(override val accountId: String, override val messageId: String, override val mailboxId: String) : MailMutation
    data class Delete(override val accountId: String, override val messageId: String, override val mailboxId: String?) : MailMutation
    data class Label(override val accountId: String, override val messageId: String, override val mailboxId: String?, val label: String, val add: Boolean) : MailMutation
}

data class AccountSyncSummary(
    val accountId: String,
    val email: String,
    val syncState: String,
    val messageCount: Int,
    val gmailExtensionsEnabled: Boolean,
    val lastSyncedAtEpochMillis: Long?,
)

data class MailCacheSettings(
    val offlineMessageCount: Int = 200,
    val attachmentCacheLimitMb: Int = 500,
    val autoEvictReadOlderThanDays: Int = 60,
    val prefetchUnreadBodies: Boolean = true,
)

data class StorageQuota(val usedKb: Long, val limitKb: Long, val checkedAtEpochMillis: Long)

class SyncAccountUseCase(private val repository: MailRepository) {
    suspend operator fun invoke(accountId: String): MailSyncResult = repository.synchronize(accountId)
}
