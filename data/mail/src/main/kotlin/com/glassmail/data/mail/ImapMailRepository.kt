package com.glassmail.data.mail

import androidx.room.withTransaction
import com.glassmail.core.database.AccountEntity
import com.glassmail.core.database.AttachmentEntity
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MailboxEntity
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.MessageEntity
import com.glassmail.core.database.MessageLabelEntity
import com.glassmail.core.database.DraftEntity
import com.glassmail.core.database.MutationState
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.database.SyncCheckpointEntity
import com.glassmail.core.database.NotificationStateEntity
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.imap.ImapException
import com.glassmail.core.model.GmailInboxSnapshot
import com.glassmail.core.model.MailSyncError
import com.glassmail.core.model.MailSyncResult
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.AccountSyncSummary
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailAttachment
import com.glassmail.domain.mail.MailListItem
import com.glassmail.domain.mail.MailMessage
import com.glassmail.domain.mail.MailRepository
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailDraft
import com.glassmail.domain.mail.DraftStatus
import com.glassmail.domain.mail.DraftAttachment
import com.glassmail.domain.mail.sanitizeAttachmentName
import com.glassmail.domain.mail.MailMutation
import com.glassmail.domain.mail.AttachmentRepository
import com.glassmail.domain.mail.DownloadedAttachment
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class ImapMailRepository(
    private val database: GlassMailDatabase,
    private val credentialStore: CredentialStore,
    private val imapClient: GmailImapClient,
    private val attachmentRoot: File? = null,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onNewMessages: suspend (List<MailListItem>) -> Unit = {},
) : MailRepository, DraftRepository, AttachmentRepository {
    private val accountMutexes = ConcurrentHashMap<String, Mutex>()
    private val mutationExecutor = PendingMutationExecutor(database, credentialStore, imapClient)

    override fun observeAccounts(): Flow<List<MailAccount>> = database.accountDao().observeAccounts().map { accounts ->
        accounts.map { MailAccount(it.accountId, it.email, it.syncState) }
    }

    override fun observeAccount(accountId: String): Flow<AccountSyncSummary?> = database.accountDao()
        .observeSummary(accountId)
        .map { row ->
            row?.let {
                AccountSyncSummary(
                    accountId = it.accountId,
                    email = it.email,
                    syncState = it.syncState,
                    messageCount = it.messageCount,
                    gmailExtensionsEnabled = it.gmailExtensionsEnabled,
                    lastSyncedAtEpochMillis = it.lastSyncedAtEpochMillis,
                )
            }
        }

    override fun observeInbox(accountId: String): Flow<List<MailListItem>> = database.mailDao()
        .observeInbox("$accountId:INBOX").map { rows -> rows.map { it.toListItem() } }

    override fun search(accountId: String, query: String): Flow<List<MailListItem>> = database.mailDao()
        .search("$accountId:INBOX", query.trim()).map { rows -> rows.map { it.toListItem() } }

    override fun observeMessage(messageId: String): Flow<MailMessage?> = database.mailDao().observeMessage(messageId)
        .combine(database.mailDao().observeAttachments(messageId)) { row, attachments ->
            row?.let { MailMessage(it.messageId, it.gmailThreadId, it.sender.orEmpty(), it.subject.orEmpty(), it.preview.orEmpty(), it.body, it.contentKind == "HTML", it.sentAtEpochMillis, "\\Seen" !in it.flags.toFlagSet(), "\\Flagged" in it.flags.toFlagSet(), it.labels.toLabels(), attachments.map { attachment -> MailAttachment(attachment.attachmentId, attachment.fileName, attachment.mimeType, attachment.sizeBytes, attachment.downloadState) }) }
        }

    override fun observeThread(messageId: String): Flow<List<MailMessage>> = database.mailDao().observeThread(messageId)
        .map { rows -> rows.map { it.toMailMessage() } }

    override fun observeDrafts(accountId: String): Flow<List<MailDraft>> = database.draftDao().observeDrafts(accountId).map { drafts -> drafts.map(DraftEntity::toDraft) }

    override fun observeDraft(draftId: String): Flow<MailDraft?> = database.draftDao().observeDraft(draftId).map { it?.toDraft() }

    override suspend fun saveDraft(draft: MailDraft) {
        require(draft.draftId.isNotBlank() && draft.accountId.isNotBlank())
        database.draftDao().upsert(draft.toEntity())
    }

    override suspend fun deleteDraft(draftId: String) = database.draftDao().delete(draftId)

    override suspend fun downloadAttachment(accountId: String, attachmentId: String): Result<DownloadedAttachment> = runCatching {
        val root = attachmentRoot ?: error("Attachment storage is unavailable")
        val account = database.accountDao().account(accountId) ?: error("Account is unavailable")
        val attachment = database.mailDao().attachment(attachmentId) ?: error("Attachment is unavailable")
        require(attachment.messageId.startsWith("gmail:$accountId:") || attachment.messageId.startsWith("imap:$accountId:")) { "Attachment does not belong to account" }
        val membership = database.mailDao().membershipsForMessage(attachment.messageId).firstOrNull() ?: error("Mailbox mapping is unavailable")
        database.mailDao().setAttachmentState(attachmentId, com.glassmail.core.database.DownloadState.FETCHING)
        val payload = credentialStore.withCredential(accountId) { password ->
            imapClient.fetchAttachment(account.email, password, membership.mailboxId.substringAfter(':', "INBOX"), membership.uid, attachment.partId)
        } ?: error("Authentication required")
        val safeName = sanitizeAttachmentName(attachment.fileName.orEmpty())
        val accountDir = File(root, "attachments/$accountId").apply { mkdirs() }
        val target = File(accountDir, "${attachmentId.hashCode().toUInt().toString(16)}-$safeName")
        val temp = File(accountDir, ".${target.name}.part")
        temp.outputStream().use { it.write(payload) }
        check(temp.renameTo(target)) { "Could not store attachment" }
        database.mailDao().setAttachmentState(attachmentId, com.glassmail.core.database.DownloadState.AVAILABLE)
        DownloadedAttachment(target.canonicalPath, safeName, attachment.mimeType ?: "application/octet-stream")
    }.onFailure { database.mailDao().setAttachmentState(attachmentId, com.glassmail.core.database.DownloadState.FAILED) }

    override suspend fun createAccount(accountId: String, email: String) {
        require(email.isNotBlank() && email.none { it == '\r' || it == '\n' }) { "Invalid account email" }
        database.accountDao().upsert(
            AccountEntity(
                accountId = accountId,
                email = email.trim(),
                createdAtEpochMillis = clock(),
                syncState = "READY",
            ),
        )
    }

    override suspend fun removeAccount(accountId: String) {
        database.accountDao().delete(accountId)
        database.notificationStateDao().delete(accountId)
        credentialStore.delete(accountId)
    }

    override suspend fun clearDebugMailbox() { database.accountDao().delete(DEBUG_ACCOUNT_ID) }

    override suspend fun seedDebugMailbox(count: Int) {
        require(count in setOf(10, 100, 1_000, 10_000))
        clearDebugMailbox()
        createAccount(DEBUG_ACCOUNT_ID, "debug@glassmail.local")
        database.withTransaction {
            database.mailDao().upsertMailboxes(listOf(MailboxEntity("$DEBUG_ACCOUNT_ID:INBOX", DEBUG_ACCOUNT_ID, "INBOX", 1, count.toLong() + 1, count)))
            database.syncDao().upsertCheckpoint(SyncCheckpointEntity("$DEBUG_ACCOUNT_ID:INBOX", DEBUG_ACCOUNT_ID, 1, count.toLong(), 1, clock()))
        }
        (1..count).chunked(BATCH_SIZE).forEach { ids -> database.withTransaction {
            val messages = ids.map { fixtureMessage(it) }
            database.mailDao().upsertMessages(messages)
            database.mailDao().upsertMailboxMessages(messages.mapIndexed { index, message -> MailboxMessageEntity("$DEBUG_ACCOUNT_ID:INBOX", ids[index].toLong(), message.messageId, buildString { if (ids[index] % 3 != 0) append("\\Seen "); if (ids[index] % 5 == 0) append("\\Flagged") }.trim(), if (ids[index] % 5 == 0) "STARRED" else "INBOX") })
            database.mailDao().upsertLabels(messages.filterIndexed { index, _ -> ids[index] % 7 == 0 }.map { MessageLabelEntity(it.messageId, "Travel") })
            database.mailDao().upsertAttachments(messages.filterIndexed { index, _ -> ids[index] % 9 == 0 }.map { AttachmentEntity("${it.messageId}:1", it.messageId, "1", "fixture-${it.messageId}.pdf", "application/pdf", 4_096) })
        } }
    }

    override suspend fun synchronize(accountId: String): MailSyncResult = accountMutexes
        .getOrPut(accountId) { Mutex() }
        .withLock {
            synchronizeLocked(accountId)
        }

    override suspend fun applyMutation(mutation: MailMutation) {
        database.withTransaction {
            val targetUid = database.mailDao().membershipsForMessage(mutation.messageId)
                .firstOrNull { mutation.mailboxId == null || it.mailboxId == mutation.mailboxId }
                ?.uid
            when (mutation) {
                is MailMutation.MarkRead -> updateFlags(mutation.messageId, mutation.mailboxId) { it.withFlag("\\Seen", mutation.read) }
                is MailMutation.Star -> updateFlags(mutation.messageId, mutation.mailboxId) { it.withFlag("\\Flagged", mutation.starred) }
                is MailMutation.Archive -> database.mailDao().removeMailboxMembership(mutation.mailboxId, mutation.messageId)
                is MailMutation.Delete -> {
                    val mId = mutation.mailboxId
                    if (mId != null) {
                        database.mailDao().removeMailboxMembership(mId, mutation.messageId)
                    } else {
                        database.mailDao().membershipsForMessage(mutation.messageId).forEach {
                            database.mailDao().removeMailboxMembership(it.mailboxId, mutation.messageId)
                        }
                    }
                }
                is MailMutation.Label -> if (mutation.add) database.mailDao().upsertLabels(listOf(MessageLabelEntity(mutation.messageId, mutation.label)))
                else database.mailDao().removeLabel(mutation.messageId, mutation.label)
            }
            database.pendingMutationDao().insert(
                PendingMutationEntity(
                    mutationId = UUID.randomUUID().toString(),
                    accountId = mutation.accountId,
                    mailboxId = mutation.mailboxId,
                    messageId = mutation.messageId,
                    targetUid = targetUid,
                    type = mutation.type(),
                    payload = mutation.payload(),
                    state = MutationState.PENDING,
                    createdAtEpochMillis = clock(),
                ),
            )
        }
    }

    private suspend fun synchronizeLocked(accountId: String): MailSyncResult {
        val account = database.accountDao().account(accountId)
            ?: return MailSyncResult.Failure(MailSyncError.Protocol)
        database.accountDao().setSyncState(accountId, "SYNCING")
        return try {
            val checkpoint = database.syncDao().checkpoint("$accountId:INBOX")
            val snapshot = credentialStore.withCredential(accountId) { password ->
                imapClient.fetchInboxPage(
                    email = account.email,
                    password = password,
                    afterUid = checkpoint?.highestKnownUid ?: 0,
                    limit = BATCH_SIZE,
                )
            } ?: return fail(accountId, MailSyncError.MissingCredential)
            val newMessages = persistSnapshot(accountId, snapshot)
            if (newMessages.isNotEmpty()) onNewMessages(newMessages.map { it.toListItem(accountId, snapshot.inbox.uidValidity) })
            mutationExecutor.flush(accountId, account.email)
            MailSyncResult.Success(
                messageCount = snapshot.messages.size,
                gmailExtensionsEnabled = snapshot.supportsGmailExtensions,
                hasMore = snapshot.hasMoreUids,
            )
        } catch (error: CancellationException) {
            throw error
        } catch (_: ImapException.Authentication) {
            fail(accountId, MailSyncError.Authentication)
        } catch (_: ImapException.Transport) {
            fail(accountId, MailSyncError.Network)
        } catch (_: ImapException.Protocol) {
            fail(accountId, MailSyncError.Protocol)
        }
    }

    private suspend fun fail(accountId: String, error: MailSyncError): MailSyncResult.Failure {
        database.accountDao().setSyncState(accountId, "ERROR_${error.javaClass.simpleName}")
        return MailSyncResult.Failure(error)
    }

    private suspend fun persistSnapshot(accountId: String, snapshot: GmailInboxSnapshot): List<com.glassmail.core.model.ImapMessageMetadata> {
        val state = database.notificationStateDao().state(accountId)
        val ids = snapshot.messages.map { it.canonicalId(accountId, snapshot.inbox.uidValidity) }
        val existing = if (state?.baselineEstablished == true) database.mailDao().messageIds(ids).toSet() else emptySet()
        val inboxId = "$accountId:INBOX"
        snapshot.messages.chunked(BATCH_SIZE).forEachIndexed { index, batch ->
            persistBatch(
                accountId = accountId,
                inboxId = inboxId,
                snapshot = snapshot,
                batch = batch,
                isFinalBatch = index == snapshot.messages.chunked(BATCH_SIZE).lastIndex,
            )
        }
        if (snapshot.messages.isEmpty()) {
            persistBatch(accountId, inboxId, snapshot, emptyList(), isFinalBatch = true)
        }
        database.notificationStateDao().upsert(NotificationStateEntity(accountId, baselineEstablished = true))
        return if (state?.baselineEstablished == true) snapshot.messages.filterNot { it.canonicalId(accountId, snapshot.inbox.uidValidity) in existing } else emptyList()
    }

    private suspend fun persistBatch(
        accountId: String,
        inboxId: String,
        snapshot: GmailInboxSnapshot,
        batch: List<com.glassmail.core.model.ImapMessageMetadata>,
        isFinalBatch: Boolean,
    ) {
        database.withTransaction {
            val previousCheckpoint = database.syncDao().checkpoint(inboxId)
            val uidValidityChanged = previousCheckpoint != null && previousCheckpoint.uidValidity != snapshot.inbox.uidValidity
            val mailboxes = snapshot.mailboxes.map { mailbox ->
                MailboxEntity(
                    mailboxId = "$accountId:${mailbox.name}",
                    accountId = accountId,
                    remoteName = mailbox.name,
                    uidValidity = if (mailbox.name.equals("INBOX", true)) snapshot.inbox.uidValidity else 0,
                    uidNext = if (mailbox.name.equals("INBOX", true)) snapshot.inbox.uidNext else 0,
                    messageCount = if (mailbox.name.equals("INBOX", true)) snapshot.inbox.messageCount else 0,
                )
            }
            database.mailDao().upsertMailboxes(mailboxes)
            if (uidValidityChanged) database.mailDao().clearMailboxMembership(inboxId)
            val messages = batch.map { message ->
                MessageEntity(
                    messageId = message.canonicalId(accountId, snapshot.inbox.uidValidity),
                    accountId = accountId,
                    gmailMessageId = message.gmailMessageId,
                    gmailThreadId = message.gmailThreadId,
                    subject = message.subject,
                    sender = message.sender,
                    sentAtEpochMillis = message.sentAtEpochMillis,
                    sizeBytes = message.sizeBytes,
                )
            }
            database.mailDao().upsertMessages(messages)
            database.mailDao().upsertMailboxMessages(batch.map { message ->
                val messageId = message.canonicalId(accountId, snapshot.inbox.uidValidity)
                val resolvedFlags = reconcilePendingFlags(message.flags, database.pendingMutationDao().activeForMessage(messageId))
                MailboxMessageEntity(
                    mailboxId = inboxId,
                    uid = message.uid,
                    messageId = messageId,
                    flags = resolvedFlags.sorted().joinToString(" "),
                    labels = message.labels.sorted().joinToString("\u001F"),
                )
            })
            database.mailDao().upsertLabels(batch.flatMap { message ->
                message.labels.map { label ->
                    MessageLabelEntity(message.canonicalId(accountId, snapshot.inbox.uidValidity), label)
                }
            })
            database.syncDao().upsertCheckpoint(
                SyncCheckpointEntity(
                    mailboxId = inboxId,
                    accountId = accountId,
                    uidValidity = snapshot.inbox.uidValidity,
                    // Persist the requested range boundary, rather than only returned messages.
                    // IMAP UIDs are sparse; an empty range must still make durable progress.
                    highestKnownUid = maxOf(
                        previousCheckpoint?.takeIf { !uidValidityChanged }?.highestKnownUid ?: 0,
                        snapshot.requestedThroughUid,
                        batch.maxOfOrNull { it.uid } ?: 0,
                    ),
                    syncGeneration = (previousCheckpoint?.syncGeneration ?: 0) + if (uidValidityChanged) 1 else 0,
                    lastSuccessfulSyncEpochMillis = if (isFinalBatch) clock() else previousCheckpoint?.lastSuccessfulSyncEpochMillis,
                ),
            )
            if (isFinalBatch) database.accountDao().markSyncSuccess(
                accountId = accountId,
                state = "IDLE",
                gmailExtensionsEnabled = snapshot.supportsGmailExtensions,
                timestamp = clock(),
            )
        }
    }

    private companion object {
        const val BATCH_SIZE = 200
        const val DEBUG_ACCOUNT_ID = "debug-fixture"
    }

    private suspend fun updateFlags(messageId: String, mailboxId: String?, transform: (Set<String>) -> Set<String>) {
        val memberships = database.mailDao().membershipsForMessage(messageId)
            .filter { mailboxId == null || it.mailboxId == mailboxId }
        database.mailDao().upsertMailboxMessages(memberships.map { membership ->
            membership.copy(flags = transform(membership.flags.toFlagSet()).sorted().joinToString(" "))
        })
    }
}

private fun com.glassmail.core.model.ImapMessageMetadata.canonicalId(accountId: String, uidValidity: Long): String =
    gmailMessageId?.let { "gmail:$accountId:$it" } ?: "imap:$accountId:$uidValidity:$uid"

private fun com.glassmail.core.model.ImapMessageMetadata.toListItem(accountId: String, uidValidity: Long) = MailListItem(
    messageId = canonicalId(accountId, uidValidity), threadId = gmailThreadId, sender = sender.orEmpty(),
    subject = subject.orEmpty(), preview = "New message", sentAtEpochMillis = sentAtEpochMillis,
    unread = "\\Seen" !in flags, starred = "\\Flagged" in flags, labels = labels.toList(), hasAttachment = false,
)

private fun MailMutation.type(): String = when (this) {
    is MailMutation.MarkRead -> if (read) "MARK_READ" else "MARK_UNREAD"
    is MailMutation.Star -> if (starred) "STAR" else "UNSTAR"
    is MailMutation.Archive -> "ARCHIVE"
    is MailMutation.Delete -> "DELETE"
    is MailMutation.Label -> if (add) "ADD_LABEL" else "REMOVE_LABEL"
}

private fun MailMutation.payload(): String? = (this as? MailMutation.Label)?.label

private fun Set<String>.withFlag(flag: String, enabled: Boolean): Set<String> = if (enabled) this + flag else this - flag

private fun String.toFlagSet(): Set<String> = split(' ').filter(String::isNotBlank).toSet()

private fun String.toLabels(): List<String> = split('\u001F', ' ').filter(String::isNotBlank).distinct()

private fun List<String>.encodeList(): String = joinToString("\u001F")
private fun String.decodeList(): List<String> = split('\u001F').filter(String::isNotBlank)

private fun MailDraft.toEntity() = DraftEntity(draftId, accountId, to.encodeList(), cc.encodeList(), bcc.encodeList(), subject, body, inReplyTo, references.encodeList(), status.name, updatedAtEpochMillis, attachments.encodeDraftAttachments())
private fun DraftEntity.toDraft() = MailDraft(draftId, accountId, toAddresses.decodeList(), ccAddresses.decodeList(), bccAddresses.decodeList(), subject, body, inReplyTo, references.decodeList(), runCatching { DraftStatus.valueOf(status) }.getOrDefault(DraftStatus.DRAFT), updatedAtEpochMillis, attachments.decodeDraftAttachments())

private fun List<DraftAttachment>.encodeDraftAttachments(): String = joinToString("\u001E") {
    listOf(it.uri, it.fileName, it.mimeType, it.sizeBytes.toString()).joinToString("\u001F")
}

private fun String.decodeDraftAttachments(): List<DraftAttachment> = split('\u001E').mapNotNull { encoded ->
    val fields = encoded.split('\u001F')
    if (fields.size != 4) return@mapNotNull null
    DraftAttachment(fields[0], fields[1], fields[2], fields[3].toLongOrNull() ?: return@mapNotNull null)
}

private fun com.glassmail.core.database.MailboxMessageRow.toListItem() = MailListItem(
    messageId, gmailThreadId, sender.orEmpty(), subject.orEmpty(), preview.orEmpty(), sentAtEpochMillis,
    unread = "\\Seen" !in flags.toFlagSet(), starred = "\\Flagged" in flags.toFlagSet(), labels.toLabels(), hasAttachment,
)

private fun com.glassmail.core.database.MessageDetailRow.toMailMessage() = MailMessage(
    messageId, gmailThreadId, sender.orEmpty(), subject.orEmpty(), preview.orEmpty(), body,
    contentKind == "HTML", sentAtEpochMillis, "\\Seen" !in flags.toFlagSet(),
    "\\Flagged" in flags.toFlagSet(), labels.toLabels(),
)

private fun fixtureMessage(index: Int): MessageEntity {
    val senders = listOf("Ada Lovelace", "Grace Hopper", "Linus Torvalds", "Margaret Hamilton", "Katherine Johnson")
    val sender = senders[index % senders.size]
    val long = if (index % 11 == 0) " — a deliberately long subject to exercise truncation and accessibility with a realistic amount of descriptive text" else ""
    val subject = listOf("Quarterly update", "Design review", "Travel itinerary", "Build status", "Welcome to GlassMail")[index % 5] + long
    val html = index % 4 == 0
    val preview = "Deterministic fixture $index: this local message is available offline for inbox, search, and reader testing."
    return MessageEntity(
        messageId = "debug:$index", accountId = "debug-fixture", gmailMessageId = "debug-$index", gmailThreadId = "thread-${index / 3}",
        subject = subject, sender = sender, sentAtEpochMillis = 1_735_689_600_000L - index * 60_000L, sizeBytes = 1024L + index,
        preview = preview, body = if (html) "<p>$preview</p><p>Remote images are blocked in this local preview.</p>" else preview, contentKind = if (html) "HTML" else "PLAIN",
    )
}

private fun reconcilePendingFlags(serverFlags: Set<String>, mutations: List<PendingMutationEntity>): Set<String> =
    mutations.fold(serverFlags) { flags, mutation ->
        when (mutation.type) {
            "MARK_READ" -> flags.withFlag("\\Seen", true)
            "MARK_UNREAD" -> flags.withFlag("\\Seen", false)
            "STAR" -> flags.withFlag("\\Flagged", true)
            "UNSTAR" -> flags.withFlag("\\Flagged", false)
            "DELETE" -> flags.withFlag("\\Deleted", true)
            else -> flags
        }
    }
