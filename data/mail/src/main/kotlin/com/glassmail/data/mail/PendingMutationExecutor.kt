package com.glassmail.data.mail

import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MutationState
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.imap.ImapException
import com.glassmail.core.imap.ImapMutation
import com.glassmail.core.security.CredentialStore
import kotlinx.coroutines.CancellationException

class PendingMutationExecutor(
    private val database: GlassMailDatabase,
    private val credentialStore: CredentialStore,
    private val imapClient: GmailImapClient,
) {
    suspend fun flush(accountId: String, email: String) {
        val mutations = database.pendingMutationDao().activeForAccount(accountId)
        credentialStore.withCredential(accountId) { password ->
            mutations.forEach { mutation -> executeOne(mutation, email, password) }
        }
    }

    private suspend fun executeOne(mutation: PendingMutationEntity, email: String, password: CharArray) {
        val uid = mutation.targetUid ?: database.mailDao().membershipsForMessage(mutation.messageId)
            .firstOrNull { mutation.mailboxId == null || it.mailboxId == mutation.mailboxId }
            ?.uid ?: return markPermanent(mutation, "MISSING_UID")
        database.pendingMutationDao().updateState(mutation.mutationId, MutationState.IN_FLIGHT, mutation.retryCount, null)
        try {
            imapClient.applyInboxMutations(email, password, listOf(ImapMutation(uid, mutation.type, mutation.payload)))
            database.pendingMutationDao().delete(mutation.mutationId)
        } catch (error: CancellationException) {
            throw error
        } catch (_: ImapException.Transport) {
            database.pendingMutationDao().updateState(mutation.mutationId, MutationState.PENDING, mutation.retryCount + 1, "NETWORK")
        } catch (_: ImapException.Authentication) {
            markPermanent(mutation, "AUTHENTICATION")
        } catch (_: ImapException.Protocol) {
            markPermanent(mutation, "SERVER_REJECTED")
        }
    }

    private suspend fun markPermanent(mutation: PendingMutationEntity, code: String) {
        database.pendingMutationDao().updateState(
            mutation.mutationId,
            MutationState.FAILED_PERMANENT,
            mutation.retryCount,
            code,
        )
    }
}
