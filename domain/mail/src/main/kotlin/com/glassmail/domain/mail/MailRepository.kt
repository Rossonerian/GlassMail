package com.glassmail.domain.mail

import com.glassmail.core.model.MailSyncResult
import kotlinx.coroutines.flow.Flow

interface MailRepository {
    fun observeAccounts(): Flow<List<MailAccount>>
    fun observeAccount(accountId: String): Flow<AccountSyncSummary?>
    fun observeInbox(accountId: String): Flow<List<MailListItem>>
    fun search(accountId: String, query: String): Flow<List<MailListItem>>
    fun observeMessage(messageId: String): Flow<MailMessage?>
    fun observeThread(messageId: String): Flow<List<MailMessage>>
    suspend fun createAccount(accountId: String, email: String)
    suspend fun removeAccount(accountId: String)
    suspend fun synchronize(accountId: String): MailSyncResult
    suspend fun applyMutation(mutation: MailMutation)
    suspend fun seedDebugMailbox(count: Int)
    suspend fun clearDebugMailbox()
}

data class MailAccount(val accountId: String, val email: String, val syncState: String)
data class MailListItem(val messageId: String, val threadId: String?, val sender: String, val subject: String, val preview: String, val sentAtEpochMillis: Long?, val unread: Boolean, val starred: Boolean, val labels: List<String>, val hasAttachment: Boolean)
data class MailAttachment(val attachmentId: String, val fileName: String?, val mimeType: String?, val sizeBytes: Long?, val downloadState: String)
data class MailMessage(val messageId: String, val threadId: String?, val sender: String, val subject: String, val preview: String, val body: String?, val html: Boolean, val sentAtEpochMillis: Long?, val unread: Boolean, val starred: Boolean, val labels: List<String>, val attachments: List<MailAttachment> = emptyList())

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

class SyncAccountUseCase(private val repository: MailRepository) {
    suspend operator fun invoke(accountId: String): MailSyncResult = repository.synchronize(accountId)
}
