package com.glassmail.domain.mail

import java.util.Locale
import java.io.InputStream

data class OutgoingMail(
    val operationId: String,
    val accountId: String,
    val from: String,
    val to: List<String>,
    val cc: List<String> = emptyList(),
    val bcc: List<String> = emptyList(),
    val subject: String,
    val body: String,
    val inReplyTo: String? = null,
    val references: List<String> = emptyList(),
    val attachments: List<OutgoingAttachment> = emptyList(),
)

data class OutgoingAttachment(
    val fileName: String,
    val mimeType: String,
    val sizeBytes: Long,
    val openStream: () -> InputStream,
)

sealed interface SendMailResult {
    data object Sent : SendMailResult
    data class Failed(val error: SendMailError) : SendMailResult
}

sealed interface SendMailError {
    data object Authentication : SendMailError
    data object Network : SendMailError
    data object Protocol : SendMailError
    data object InvalidMessage : SendMailError
}

interface MailSender {
    suspend fun send(account: MailAccount, mail: OutgoingMail): SendMailResult
}

interface DraftRepository {
    fun observeDrafts(accountId: String): kotlinx.coroutines.flow.Flow<List<MailDraft>>
    fun observeDraft(draftId: String): kotlinx.coroutines.flow.Flow<MailDraft?>
    suspend fun saveDraft(draft: MailDraft)
    suspend fun deleteDraft(draftId: String)
}

data class MailDraft(
    val draftId: String,
    val accountId: String,
    val to: List<String> = emptyList(),
    val cc: List<String> = emptyList(),
    val bcc: List<String> = emptyList(),
    val subject: String = "",
    val body: String = "",
    val inReplyTo: String? = null,
    val references: List<String> = emptyList(),
    val status: DraftStatus = DraftStatus.DRAFT,
    val updatedAtEpochMillis: Long = 0,
    val attachments: List<DraftAttachment> = emptyList(),
)

data class DraftAttachment(
    val uri: String,
    val fileName: String,
    val mimeType: String,
    val sizeBytes: Long,
)

fun sanitizeAttachmentName(raw: String): String = raw.substringAfterLast('/').substringAfterLast('\\')
    .replace(Regex("[^A-Za-z0-9._ -]"), "_").take(120).ifBlank { "attachment" }

fun estimatedOutgoingMessageBytes(mail: OutgoingMail): Long = mail.body.toByteArray(Charsets.UTF_8).size.toLong() +
    (mail.attachments.sumOf { it.sizeBytes.coerceAtLeast(0) } * 4 / 3) + mail.attachments.size * 1024L + 16_384

enum class DraftStatus { DRAFT, QUEUED, SENDING, SENT, FAILED, UNCERTAIN }

fun normalizeAddresses(raw: String): List<String> = raw.split(',', ';', '\n')
    .map(String::trim)
    .filter(String::isNotBlank)
    .distinctBy(String::lowercase)

fun validateAddresses(addresses: List<String>): Boolean = addresses.isNotEmpty() && addresses.all { address ->
    address.length <= 254 && address.count { it == '@' } == 1 &&
        address.substringBefore('@').isNotBlank() && address.substringAfter('@').contains('.') &&
        address.none { it.isWhitespace() || it == '\r' || it == '\n' }
}

fun replySubject(subject: String): String = if (subject.trim().lowercase(Locale.ROOT).startsWith("re:")) subject else "Re: $subject"

fun replyRecipients(message: MailMessage, ownAddress: String): List<String> = listOf(message.sender)
    .filter { it.isNotBlank() && !it.equals(ownAddress, ignoreCase = true) }
    .distinctBy(String::lowercase)

fun replyAllRecipients(message: ReceivedMailHeaders, ownAddress: String): List<String> =
    (message.replyTo + message.to + message.cc)
        .filter { it.isNotBlank() && !it.equals(ownAddress, ignoreCase = true) }
        .distinctBy(String::lowercase)

data class ReceivedMailHeaders(
    val replyTo: List<String> = emptyList(),
    val to: List<String> = emptyList(),
    val cc: List<String> = emptyList(),
    val messageId: String? = null,
    val references: List<String> = emptyList(),
)

fun forwardSubject(subject: String): String = if (subject.trim().lowercase(Locale.ROOT).startsWith("fwd:")) subject else "Fwd: $subject"

fun referencesForReply(messageId: String?, references: List<String>): List<String> =
    (references + listOfNotNull(messageId)).distinct()
