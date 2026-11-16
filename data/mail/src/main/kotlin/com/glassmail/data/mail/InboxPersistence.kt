package com.glassmail.data.mail

import com.glassmail.core.database.MailboxEntity
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.MessageEntity
import com.glassmail.core.database.MessageLabelEntity
import com.glassmail.core.database.SyncCheckpointEntity
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.model.GmailInboxSnapshot

internal suspend fun persistInboxBatch(
    mailDao: com.glassmail.core.database.MailDao,
    syncDao: com.glassmail.core.database.SyncDao,
    mutationDao: com.glassmail.core.database.PendingMutationDao,
    accountDao: com.glassmail.core.database.AccountDao,
    inTransaction: suspend (suspend () -> Unit) -> Unit,
    clock: () -> Long,
    advanceCheckpoint: Boolean = true,
    cacheCap: Int? = null,
    accountId: String,
    inboxId: String,
    snapshot: GmailInboxSnapshot,
    batch: List<com.glassmail.core.model.ImapMessageMetadata>,
    isFinalBatch: Boolean,
): Int {
    var persistedCount = 0
    inTransaction {
        // A namespace reset needs fresh UIDs for pending flag/label actions.
        // Overlay those intents; never recreate optimistic archive/delete membership.
        val pending = batch.associate { message ->
            val id = message.canonicalId(accountId, snapshot.inbox.uidValidity)
            id to (mutationDao.activeForMessage(id) +
                (message.gmailThreadId?.let { mutationDao.activeForThread(accountId, it) }.orEmpty()))
                .distinctBy { it.mutationId }
        }
        val eligible = batch.filter { message ->
            pending[message.canonicalId(accountId, snapshot.inbox.uidValidity)].orEmpty()
                .none { it.type == "ARCHIVE" || it.type == "DELETE" }
        }.map { message ->
            val mutations = pending[message.canonicalId(accountId, snapshot.inbox.uidValidity)].orEmpty()
            message.copy(flags = reconcilePendingFlags(message.flags, mutations), labels = reconcilePendingLabels(message.labels, mutations))
        }
        val bounded = if (cacheCap == null) eligible else eligible.sortedByDescending { it.uid }.take(
            (cacheCap - mailDao.countMailboxMessages(inboxId)).coerceAtLeast(0),
        )
        persistedCount = bounded.size
        val previousCheckpoint = if (advanceCheckpoint) syncDao.checkpoint(inboxId) else null
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
        mailDao.upsertMailboxes(mailboxes)
        val batchIds = bounded.map { it.canonicalId(accountId, snapshot.inbox.uidValidity) }
        val existingBodies = if (batchIds.isNotEmpty()) {
            mailDao.existingBodyStates(batchIds).associateBy { it.messageId }
        } else {
            emptyMap()
        }
        val messages = bounded.map { message ->
            val mId = message.canonicalId(accountId, snapshot.inbox.uidValidity)
            val existing = existingBodies[mId]
            MessageEntity(
                messageId = mId,
                accountId = accountId,
                gmailMessageId = message.gmailMessageId,
                gmailThreadId = message.gmailThreadId,
                subject = message.subject,
                sender = message.sender,
                sentAtEpochMillis = message.sentAtEpochMillis,
                sizeBytes = message.sizeBytes,
                category = message.resolveCategory(),
                preview = existing?.preview,
                body = existing?.body,
                contentKind = existing?.contentKind ?: "PLAIN",
                bodyDownloadState = existing?.bodyDownloadState ?: com.glassmail.core.database.DownloadState.NOT_FETCHED,
                listUnsubscribe = message.listUnsubscribe,
                listUnsubscribePost = message.listUnsubscribePost,
            )
        }
        mailDao.upsertMessages(messages)
        mailDao.upsertMailboxMessages(bounded.map { message ->
            val messageId = message.canonicalId(accountId, snapshot.inbox.uidValidity)
            val resolvedFlags = message.flags
            MailboxMessageEntity(
                mailboxId = inboxId,
                uid = message.uid,
                messageId = messageId,
                flags = resolvedFlags.sorted().joinToString(" "),
                labels = message.labels.sorted().joinToString("\u001F"),
            )
        })
        bounded.forEach { mailDao.clearMessageLabels(it.canonicalId(accountId, snapshot.inbox.uidValidity)) }
        mailDao.upsertLabels(bounded.flatMap { message ->
            message.labels.map { label ->
                MessageLabelEntity(message.canonicalId(accountId, snapshot.inbox.uidValidity), label)
            }
        })
        if (advanceCheckpoint) syncDao.upsertCheckpoint(
            SyncCheckpointEntity(
                mailboxId = inboxId,
                accountId = accountId,
                uidValidity = snapshot.inbox.uidValidity,
                // Persist the requested range boundary, rather than only returned messages.
                // IMAP UIDs are sparse; an empty range must still make durable progress.
                highestKnownUid = maxOf(
                    previousCheckpoint?.highestKnownUid ?: 0,
                    snapshot.requestedThroughUid,
                    batch.maxOfOrNull { it.uid } ?: 0,
                ),
                syncGeneration = previousCheckpoint?.syncGeneration ?: 0,
                lastSuccessfulSyncEpochMillis = if (isFinalBatch) clock() else previousCheckpoint?.lastSuccessfulSyncEpochMillis,
            ),
        )
        if (advanceCheckpoint && isFinalBatch) accountDao.markSyncSuccess(
            accountId = accountId,
            state = "IDLE",
            gmailExtensionsEnabled = snapshot.supportsGmailExtensions,
            timestamp = clock(),
        )
    }
    return persistedCount
}

internal fun reconcilePendingFlags(serverFlags: Set<String>, mutations: List<PendingMutationEntity>): Set<String> =
    mutations.fold(serverFlags) { flags, mutation ->
        when (mutation.type) {
            "MARK_READ" -> flags + "\\Seen"
            "MARK_UNREAD" -> flags - "\\Seen"
            "STAR" -> flags + "\\Flagged"
            "UNSTAR" -> flags - "\\Flagged"
            "DELETE" -> flags + "\\Deleted"
            else -> flags
        }
    }

internal fun reconcilePendingLabels(serverLabels: Set<String>, mutations: List<PendingMutationEntity>): Set<String> =
    mutations.fold(serverLabels) { labels, mutation ->
        val label = mutation.payload
        when {
            label == null -> labels
            mutation.type == "ADD_LABEL" -> labels + label
            mutation.type == "REMOVE_LABEL" -> labels - label
            else -> labels
        }
    }
