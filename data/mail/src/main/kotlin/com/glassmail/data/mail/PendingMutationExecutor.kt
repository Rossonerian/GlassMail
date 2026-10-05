package com.glassmail.data.mail

import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MutationState
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.imap.ImapException
import com.glassmail.core.imap.ImapMutation
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.ARCHIVE_UNDO_MILLIS
import kotlinx.coroutines.CancellationException

/** The repository serializes flushes per account, including recovery after process death. */
class PendingMutationExecutor(
    private val database: GlassMailDatabase,
    private val credentialStore: CredentialStore,
    private val imapClient: GmailImapClient,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    suspend fun flush(accountId: String, email: String) {
        val dao = database.pendingMutationDao()
        dao.recoverInFlight(accountId)
        val mutations = dao.activeForAccount(accountId)
        credentialStore.withCredential(accountId) { password ->
            val threadByMessage = mutations.mapNotNull { mutation -> mutation.threadId()?.let { mutation.messageId to it } }.toMap()
            val completed = mutableSetOf<String>()
            val blocked = mutableSetOf<String>()
            for (mutation in mutations) {
                val threadId = mutation.threadId()
                val key = threadId ?: threadByMessage[mutation.messageId] ?: mutation.messageId
                if (key in blocked || mutation.payload in completed) continue
                val createdAt = if (threadId == null) mutation.createdAtEpochMillis else
                    mutations.filter { it.payload == mutation.payload }.maxOf { it.createdAtEpochMillis }
                if (mutation.state == MutationState.FAILED_PERMANENT ||
                    (mutation.type == "ARCHIVE" && clock() - createdAt < ARCHIVE_UNDO_MILLIS)) {
                    blocked.add(key)
                    continue
                }
                // Undo may have deleted the detached row since enumeration.
                val claimed = if (threadId == null) dao.claim(mutation.mutationId) else dao.claimThreadAction(requireNotNull(mutation.payload))
                if (claimed == 0) continue
                if (threadId != null) completed.add(requireNotNull(mutation.payload))
                when (executeOne(mutation, email, password)) {
                    Outcome.APPLIED -> Unit
                    Outcome.BLOCK_TARGET -> blocked.add(key)
                    Outcome.STOP_ACCOUNT -> break
                }
            }
        }
    }

    private enum class Outcome { APPLIED, BLOCK_TARGET, STOP_ACCOUNT }

    private suspend fun executeOne(mutation: PendingMutationEntity, email: String, password: CharArray): Outcome {
        try {
            val threadId = mutation.threadId()
            if (threadId != null) {
                imapClient.applyThreadMutation(email, password, threadId, mutation.type)
            } else {
                val inboxId = "${mutation.accountId}:INBOX"
                if (mutation.mailboxId != null && mutation.mailboxId != inboxId) {
                    markPermanent(mutation, "MISSING_UID")
                    return Outcome.BLOCK_TARGET
                }
                val validity = database.syncDao().checkpoint(inboxId)?.uidValidity
                if (validity == null) {
                    markAwaitingSync(mutation)
                    return Outcome.STOP_ACCOUNT
                }
                val uid = mutation.targetUid ?: database.mailDao().membershipsForMessage(mutation.messageId)
                    .firstOrNull { it.mailboxId == inboxId }?.uid
                if (uid == null) {
                    markPermanent(mutation, "MISSING_UID")
                    return Outcome.BLOCK_TARGET
                }
                imapClient.applyInboxMutations(email, password, listOf(ImapMutation(uid, mutation.type, mutation.payload)), validity)
            }
            if (threadId == null) database.pendingMutationDao().delete(mutation.mutationId)
            else database.pendingMutationDao().deleteThreadAction(requireNotNull(mutation.payload))
            return Outcome.APPLIED
        } catch (error: CancellationException) {
            // A cancelled session must remain retryable; the command may already have run.
            kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) {
                updateState(mutation, MutationState.PENDING, mutation.retryCount, null)
            }
            throw error
        } catch (_: ImapException.UidValidityChanged) {
            markAwaitingSync(mutation)
            return Outcome.STOP_ACCOUNT
        } catch (_: ImapException.Transport) {
            updateState(mutation, MutationState.PENDING, mutation.retryCount + 1, "NETWORK")
            return Outcome.STOP_ACCOUNT
        } catch (_: ImapException.Authentication) {
            updateState(mutation, MutationState.PENDING, mutation.retryCount, "AUTHENTICATION")
            return Outcome.STOP_ACCOUNT
        } catch (_: ImapException.Protocol) {
            markPermanent(mutation, "SERVER_REJECTED")
            return Outcome.BLOCK_TARGET
        }
    }

    private suspend fun updateState(mutation: PendingMutationEntity, state: String, retryCount: Int, errorCode: String?) {
        if (mutation.threadId() == null) database.pendingMutationDao().updateState(mutation.mutationId, state, retryCount, errorCode)
        else database.pendingMutationDao().updateThreadActionState(requireNotNull(mutation.payload), state, retryCount, errorCode)
    }

    private suspend fun markAwaitingSync(mutation: PendingMutationEntity) {
        updateState(mutation, MutationState.PENDING, mutation.retryCount, "UIDVALIDITY_CHANGED")
    }

    private suspend fun markPermanent(mutation: PendingMutationEntity, code: String) {
        updateState(mutation, MutationState.FAILED_PERMANENT, mutation.retryCount, code)
    }
}

private fun PendingMutationEntity.threadId(): String? =
    payload?.takeIf { type in setOf("ARCHIVE", "DELETE", "MARK_READ", "MARK_UNREAD", "STAR", "UNSTAR") && it.startsWith("gmail-thread:") }
        ?.removePrefix("gmail-thread:")?.substringBefore(':')
