package com.glassmail.data.mail

import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.PendingMutationDao
import com.glassmail.core.database.SyncDao
import com.glassmail.core.model.GmailInboxSnapshot

/** Discard a page fetched with an obsolete boundary before it can advance the checkpoint. */
internal suspend fun recoverInboxSnapshot(
    accountId: String,
    storedUidValidity: Long?,
    snapshot: GmailInboxSnapshot,
    mailDao: MailDao,
    syncDao: SyncDao,
    mutationDao: PendingMutationDao,
    inTransaction: suspend (suspend () -> Unit) -> Unit,
    fetchLatest: suspend () -> GmailInboxSnapshot,
): GmailInboxSnapshot {
    if (storedUidValidity == null || storedUidValidity == snapshot.inbox.uidValidity) return snapshot
    val inboxId = "$accountId:INBOX"
    inTransaction {
        mailDao.clearMailboxMembership(inboxId)
        syncDao.deleteCheckpoint(inboxId)
        // Includes archives whose optimistic update already removed their membership.
        // Canonical Gmail identities survive; only fresh memberships can supply UIDs.
        mutationDao.clearActiveTargetUids(accountId)
    }
    return fetchLatest()
}

/** Caller holds the database transaction, including deletion of the pending archive. */
internal suspend fun undoArchiveInCurrentNamespace(
    messageId: String,
    mailDao: MailDao,
    syncDao: SyncDao,
    mutationDao: PendingMutationDao,
): Boolean {
    val mutation = mutationDao.undoableArchive(messageId) ?: return false
    val mailboxId = mutation.mailboxId ?: return false
    val uid = mutation.targetUid ?: return false
    if (mailboxId != "${mutation.accountId}:INBOX" || mutation.lastErrorCode == "UIDVALIDITY_CHANGED") return false
    val checkpoint = syncDao.checkpoint(mailboxId) ?: return false
    if (checkpoint.uidValidity != mailDao.mailboxUidValidity(mailboxId)) return false
    // A reset nulls targetUid atomically with membership removal, so an old captured
    // UID cannot be restored after the new checkpoint has been established.
    mailDao.upsertMailboxMessages(
        listOf(MailboxMessageEntity(mailboxId, uid, messageId, mutation.previousFlags, mutation.previousLabels)),
    )
    mutationDao.delete(mutation.mutationId)
    return true
}
