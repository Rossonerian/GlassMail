package com.glassmail.core.model

data class ImapMailbox(
    val name: String,
    val attributes: Set<String>,
)

data class ImapSelectedMailbox(
    val uidValidity: Long,
    val uidNext: Long,
    val messageCount: Int,
)

data class ImapStorageQuota(val usedKb: Long, val limitKb: Long)

data class ImapRemoteDraft(
    val uid: Long,
    val draftId: String?,
    val to: List<String>,
    val cc: List<String>,
    val bcc: List<String>,
    val subject: String,
    val body: String,
    val inReplyTo: String?,
    val references: List<String>,
    val updatedAtEpochMillis: Long,
)

data class ImapMessageMetadata(
    val uid: Long,
    val flags: Set<String>,
    val gmailMessageId: String?,
    val gmailThreadId: String?,
    val labels: Set<String>,
    val subject: String?,
    val sender: String?,
    val sentAtEpochMillis: Long?,
    val sizeBytes: Long?,
    val hasListUnsubscribe: Boolean = false,
    val precedence: String? = null,
    val listId: String? = null,
    val listUnsubscribe: String? = null,
    val listUnsubscribePost: String? = null,
)

data class GmailInboxSnapshot(
    val capabilities: Set<String>,
    val mailboxes: List<ImapMailbox>,
    val inbox: ImapSelectedMailbox,
    val messages: List<ImapMessageMetadata>,
    /** Last UID requested from the server, including an empty range with UID holes. */
    val requestedThroughUid: Long = 0,
) {
    val supportsGmailExtensions: Boolean get() = "X-GM-EXT-1" in capabilities
    val hasMoreUids: Boolean get() = requestedThroughUid < inbox.uidNext - 1
}

sealed interface MailSyncResult {
    data class Success(
        val messageCount: Int,
        val gmailExtensionsEnabled: Boolean,
        /** More historical/incremental UIDs remain after this committed page. */
        val hasMore: Boolean = false,
    ) : MailSyncResult
    data class Failure(val error: MailSyncError) : MailSyncResult
}

sealed interface MailSyncError {
    data object Authentication : MailSyncError
    data object Network : MailSyncError
    data object Protocol : MailSyncError
    data object MissingCredential : MailSyncError
    data object Cancelled : MailSyncError
}
