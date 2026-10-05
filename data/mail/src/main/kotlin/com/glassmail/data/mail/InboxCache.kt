package com.glassmail.data.mail

import com.glassmail.core.database.MailDao
import com.glassmail.core.database.MessageLabelEntity
import com.glassmail.core.database.PendingMutationDao
import com.glassmail.core.imap.OlderInboxPage
import com.glassmail.core.model.ImapMessageMetadata
import com.glassmail.core.model.MailSyncError
import com.glassmail.domain.mail.MailCategory
import com.glassmail.domain.mail.OlderMailResult
import kotlin.coroutines.coroutineContext
import kotlinx.coroutines.ensureActive

/** Network reads never hold a Room transaction. Each applied chunk is atomic. */
internal suspend fun reconcileCachedInbox(
    accountId: String,
    uidValidity: Long,
    highestKnownUid: Long,
    mailDao: MailDao,
    mutationDao: PendingMutationDao,
    inTransaction: suspend (suspend () -> Unit) -> Unit,
    fetch: suspend (List<Long>) -> List<ImapMessageMetadata>,
) {
    val inboxId = "$accountId:INBOX"
    var afterUid = 0L
    while (true) {
        coroutineContext.ensureActive()
        val cached = mailDao.mailboxMembershipPage(inboxId, afterUid, highestKnownUid, 500)
        if (cached.isEmpty()) return
        val server = fetch(cached.map { it.uid }).associateBy { it.uid }
        coroutineContext.ensureActive()
        inTransaction {
            check(mailDao.mailboxUidValidity(inboxId) == uidValidity) { "Inbox namespace changed" }
            cached.forEach { captured ->
                // Local archive/delete may have removed this membership during FETCH.
                val current = mailDao.membershipsForMessage(captured.messageId)
                    .firstOrNull { it.mailboxId == inboxId && it.uid == captured.uid } ?: return@forEach
                val remote = server[current.uid]
                // Dates are immutable metadata and can heal even while a local flag intent is pending.
                remote?.sentAtEpochMillis?.let { mailDao.updateMissingSentAt(current.messageId, it) }
                if (mutationDao.activeForMessage(captured.messageId).isNotEmpty()) return@forEach
                if (remote == null) {
                    mailDao.removeMailboxMembership(inboxId, current.messageId)
                    // Keep canonical content, attachments, draft and mutation references.
                    // Detached records are not visible in Inbox/search (both join membership).
                    mailDao.clearMessageLabels(current.messageId)
                    val remainingLabels = mailDao.membershipsForMessage(current.messageId)
                        .flatMap { it.labels.split('\u001F').filter(String::isNotBlank) }.distinct()
                    mailDao.upsertLabels(remainingLabels.map { MessageLabelEntity(current.messageId, it) })
                } else {
                    mailDao.upsertMailboxMessages(listOf(current.copy(
                        flags = remote.flags.sorted().joinToString(" "),
                        labels = remote.labels.sorted().joinToString("\u001F"),
                    )))
                    mailDao.clearMessageLabels(current.messageId)
                    mailDao.upsertLabels(remote.labels.map { MessageLabelEntity(current.messageId, it) })
                    // Server category labels take precedence; retain the original header
                    // heuristic when Gmail supplies no category label.
                    MailCategory.all.firstOrNull { category -> remote.labels.any { it.equals("\\Category$category", true) } }
                        ?.let { mailDao.updateCategory(current.messageId, it) }
                }
            }
        }
        afterUid = cached.last().uid
    }
}

/** Caller serializes account sync/backfill/removal. Only the persistence callback writes. */
internal suspend fun loadOlderInbox(
    inboxId: String,
    cacheCap: Int,
    mailDao: MailDao,
    fetch: suspend (beforeUid: Long, limit: Int) -> OlderInboxPage?,
    persist: suspend (OlderInboxPage) -> Int,
    enforceLimits: suspend () -> Unit,
): OlderMailResult {
    val low = mailDao.lowestMailboxUid(inboxId)
        ?: return OlderMailResult.Success(0, hasMoreOlder = false)
    if (low <= 1) return OlderMailResult.Success(0, hasMoreOlder = false)
    val room = cacheCap - mailDao.countMailboxMessages(inboxId)
    if (room <= 0) return OlderMailResult.Success(0, hasMoreOlder = false, cacheLimitReached = true)
    val page = fetch(low, minOf(50, room)) ?: return OlderMailResult.Failure(MailSyncError.MissingCredential)
    coroutineContext.ensureActive()
    val persistedCount = persist(page)
    enforceLimits()
    val atCap = mailDao.countMailboxMessages(inboxId) >= cacheCap
    return OlderMailResult.Success(persistedCount, (page.hasMoreOlder || persistedCount < page.snapshot.messages.size) && !atCap, atCap)
}
