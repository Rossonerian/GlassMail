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
