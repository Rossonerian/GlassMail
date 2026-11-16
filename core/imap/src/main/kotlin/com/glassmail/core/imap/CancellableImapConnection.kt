package com.glassmail.core.imap

import kotlinx.coroutines.InternalCoroutinesApi
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.job
import kotlin.coroutines.coroutineContext

/** Close a blocking connection as soon as cancellation starts, before its read can finish. */
@OptIn(InternalCoroutinesApi::class)
internal suspend fun <T> withConnectionCancellation(connection: AutoCloseable, block: suspend () -> T): T {
    val context = coroutineContext
    // A normal completion handler waits for the blocking coroutine to finish. The
    // cancelling-phase handler must run immediately to unblock that coroutine.
    val registration = context.job.invokeOnCompletion(onCancelling = true, invokeImmediately = true) { cause ->
        if (cause != null) runCatching { connection.close() }
    }
    return try {
        context.ensureActive()
        block().also { context.ensureActive() }
    } catch (error: Exception) {
        // Socket closure can surface as IOException, Transport, or protocol EOF.
        // Preserve cancellation so the IDLE service does not retry a removed account.
        context.ensureActive()
        throw error
    } finally {
        registration.dispose()
    }
}
