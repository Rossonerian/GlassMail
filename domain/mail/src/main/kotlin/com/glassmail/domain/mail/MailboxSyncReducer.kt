package com.glassmail.domain.mail

data class ServerMessage(
    val uid: Long,
    val canonicalId: String,
    val flags: Set<String>,
)

data class ServerMailboxBatch(
    val uidValidity: Long,
    val messages: List<ServerMessage>,
)

data class LocalMessage(
    val canonicalId: String,
    val flags: Set<String>,
)

sealed interface LocalMutation {
    val messageUid: Long

    data class Read(override val messageUid: Long, val read: Boolean) : LocalMutation
    data class Star(override val messageUid: Long, val starred: Boolean) : LocalMutation
}

data class MailboxLocalState(
    val uidValidity: Long,
    val highestKnownUid: Long,
    val messages: Map<Long, LocalMessage> = emptyMap(),
    val pendingMutations: List<LocalMutation> = emptyList(),
)

object MailboxSyncReducer {
    fun apply(current: MailboxLocalState, server: ServerMailboxBatch): MailboxLocalState {
        val previousByCanonicalId = current.messages.values.associateBy { it.canonicalId }
        val reset = current.uidValidity != server.uidValidity
        val merged = buildMap {
            server.messages.forEach { remote ->
                val existing = if (reset) previousByCanonicalId[remote.canonicalId] else current.messages[remote.uid]
                val flags = reconcileFlags(remote.uid, remote.flags, current.pendingMutations)
                put(remote.uid, LocalMessage(remote.canonicalId, flags.ifEmpty { existing?.flags.orEmpty() }))
            }
        }
        return MailboxLocalState(
            uidValidity = server.uidValidity,
            highestKnownUid = maxOf(if (reset) 0 else current.highestKnownUid, server.messages.maxOfOrNull { it.uid } ?: 0),
            messages = if (reset) merged else current.messages + merged,
            pendingMutations = current.pendingMutations,
        )
    }

    private fun reconcileFlags(uid: Long, serverFlags: Set<String>, pending: List<LocalMutation>): Set<String> =
        pending.filter { it.messageUid == uid }.fold(serverFlags) { flags, mutation ->
            when (mutation) {
                is LocalMutation.Read -> flags.withFlag("\\Seen", mutation.read)
                is LocalMutation.Star -> flags.withFlag("\\Flagged", mutation.starred)
            }
        }

    private fun Set<String>.withFlag(flag: String, present: Boolean): Set<String> =
        if (present) this + flag else this - flag
}
