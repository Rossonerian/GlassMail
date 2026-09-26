package com.glassmail.core.imap

import com.glassmail.core.model.GmailInboxSnapshot
import com.glassmail.core.model.ImapMailbox
import com.glassmail.core.model.ImapMessageMetadata
import com.glassmail.core.model.ImapSelectedMailbox
import com.glassmail.core.model.ImapStorageQuota
import com.glassmail.core.model.ImapRemoteDraft
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.net.SocketTimeoutException
import java.nio.charset.StandardCharsets
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.time.OffsetDateTime
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLParameters
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory
import javax.mail.internet.InternetAddress
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import kotlin.coroutines.coroutineContext

sealed class ImapException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class Authentication : ImapException("IMAP authentication failed")
    class Transport(cause: Throwable) : ImapException("IMAP transport failed", cause)
    class Protocol(message: String) : ImapException(message)
}

class GmailImapClient(
    private val host: String = "imap.gmail.com",
    private val port: Int = 993,
    private val connectTimeoutMillis: Int = 15_000,
    private val readTimeoutMillis: Int = 30_000,
) {
    /** Store an accepted outbound RFC 822 message in the server's special-use Sent mailbox. */
    suspend fun appendSent(email: String, password: CharArray, rawMessage: ByteArray) =
        appendSpecialUse(email, password, rawMessage, "\\Sent", listOf("[Gmail]/Sent Mail", "Sent", "Sent Items"), "\\Seen")

    /** Store the current local draft as a remote IMAP draft. */
    suspend fun appendDraft(email: String, password: CharArray, rawMessage: ByteArray) =
        appendSpecialUse(email, password, rawMessage, "\\Drafts", listOf("[Gmail]/Drafts", "Drafts", "Draft"), "\\Draft")

    suspend fun replaceRemoteDraft(email: String, password: CharArray, draftId: String, rawMessage: ByteArray) =
        withContext(Dispatchers.IO.limitedParallelism(1)) {
            require(draftId.matches(Regex("[A-Za-z0-9._-]{1,128}"))) { "Invalid draft identifier" }
            require(rawMessage.isNotEmpty() && rawMessage.size <= MAX_APPEND_BYTES) { "Draft exceeds IMAP APPEND limit" }
            TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
                val client = ImapCommandClient(connection)
                client.requireGreeting()
                val capabilities = client.capability()
                client.login(email, password)
                val folders = client.listMailboxes()
                val folder = folders.firstOrNull { box -> box.attributes.any { it.equals("\\Drafts", ignoreCase = true) } }?.name
                    ?: listOf("[Gmail]/Drafts", "Drafts", "Draft").firstOrNull { name -> folders.any { it.name.equals(name, true) } }
                    ?: throw ImapException.Protocol("Server did not advertise a Drafts mailbox")
                client.selectMailbox(folder)
                client.replaceDraft(draftId, capabilities)
                client.append(folder, "\\Draft", rawMessage)
            }
        }

    suspend fun deleteRemoteDraft(email: String, password: CharArray, draftId: String) =
        withContext(Dispatchers.IO.limitedParallelism(1)) {
            if (!draftId.matches(Regex("[A-Za-z0-9._-]{1,128}"))) return@withContext
            TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
                val client = ImapCommandClient(connection)
                client.requireGreeting()
                val capabilities = client.capability()
                client.login(email, password)
                val folders = client.listMailboxes()
                val folder = folders.firstOrNull { box -> box.attributes.any { it.equals("\\Drafts", ignoreCase = true) } }?.name
                    ?: listOf("[Gmail]/Drafts", "Drafts", "Draft").firstOrNull { name -> folders.any { it.name.equals(name, true) } }
                    ?: return@withContext
                client.selectMailbox(folder)
                client.deleteDraft(draftId, capabilities)
            }
        }

    suspend fun fetchRemoteDrafts(email: String, password: CharArray, limit: Int = 100): List<ImapRemoteDraft> =
        withContext(Dispatchers.IO.limitedParallelism(1)) {
            require(limit in 1..250)
            TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
                val client = ImapCommandClient(connection)
                client.requireGreeting()
                client.login(email, password)
                val folders = client.listMailboxes()
                val folder = folders.firstOrNull { box -> box.attributes.any { it.equals("\\Drafts", ignoreCase = true) } }?.name
                    ?: listOf("[Gmail]/Drafts", "Drafts", "Draft").firstOrNull { name -> folders.any { it.name.equals(name, true) } }
                    ?: return@withContext emptyList()
                client.selectMailbox(folder)
                client.fetchDrafts(limit)
            }
        }

    private suspend fun appendSpecialUse(
        email: String,
        password: CharArray,
        rawMessage: ByteArray,
        specialUse: String,
        fallbacks: List<String>,
        flag: String,
    ) = withContext(Dispatchers.IO.limitedParallelism(1)) {
        require(rawMessage.isNotEmpty() && rawMessage.size <= MAX_APPEND_BYTES) { "Message exceeds IMAP APPEND limit" }
        TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
            val client = ImapCommandClient(connection)
            client.requireGreeting()
            client.login(email, password)
            val mailboxes = client.listMailboxes()
            val mailbox = mailboxes.firstOrNull { box -> box.attributes.any { it.equals(specialUse, ignoreCase = true) } }?.name
                ?: fallbacks.firstOrNull { fallback -> mailboxes.any { it.name.equals(fallback, ignoreCase = true) } }
                ?: throw ImapException.Protocol("Server did not advertise a $specialUse mailbox")
            client.append(mailbox, flag, rawMessage)
        }
    }

    suspend fun applyInboxMutations(email: String, password: CharArray, operations: List<ImapMutation>) {
        if (operations.isEmpty()) return
        withContext(Dispatchers.IO.limitedParallelism(1)) {
            TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
                val client = ImapCommandClient(connection)
                client.requireGreeting()
                client.login(email, password)
                client.selectInbox()
                operations.forEach(client::applyMutation)
            }
        }
    }

    suspend fun fetchLatestInbox(email: String, password: CharArray, limit: Int = 50): GmailInboxSnapshot =
        withContext(Dispatchers.IO.limitedParallelism(1)) {
            coroutineContext.ensureActive()
            TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
                val client = ImapCommandClient(connection)
                client.requireGreeting()
                val capabilities = client.capability()
                client.login(email, password)
                val authenticatedCapabilities = client.capability() + capabilities
                val mailboxes = client.listMailboxes()
                val inbox = client.selectInbox()
                val messages = client.fetchLatestMetadata(
                    limit = limit,
                    messageCount = inbox.messageCount,
                    supportsGmailExtensions = "X-GM-EXT-1" in authenticatedCapabilities,
                )
                GmailInboxSnapshot(
                    capabilities = authenticatedCapabilities,
                    mailboxes = mailboxes,
                    inbox = inbox,
                    messages = messages,
                    requestedThroughUid = (inbox.uidNext - 1).coerceAtLeast(0),
                )
            }
        }

    /**
     * Reads one UID page. A caller persists its highest UID before requesting the next page,
     * so historical enumeration and later incremental catch-up survive process death.
     */
    suspend fun fetchInboxPage(
        email: String,
        password: CharArray,
        afterUid: Long,
        limit: Int = 200,
    ): GmailInboxSnapshot = withContext(Dispatchers.IO.limitedParallelism(1)) {
        require(limit in 1..250) { "IMAP page limit must be bounded" }
        coroutineContext.ensureActive()
        TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
            val client = ImapCommandClient(connection)
            client.requireGreeting()
            val capabilities = client.capability()
            client.login(email, password)
            val authenticatedCapabilities = client.capability() + capabilities
            val mailboxes = client.listMailboxes()
            val inbox = client.selectInbox()
            val firstUid = (afterUid + 1).coerceAtLeast(1)
            val lastUid = minOf(inbox.uidNext - 1, firstUid + limit - 1)
            val messages = if (lastUid < firstUid) emptyList() else client.fetchMetadata(
                "$firstUid:$lastUid",
                "X-GM-EXT-1" in authenticatedCapabilities,
            )
            GmailInboxSnapshot(
                capabilities = authenticatedCapabilities,
                mailboxes = mailboxes,
                inbox = inbox,
                messages = messages,
                requestedThroughUid = lastUid.coerceAtLeast(0),
            )
        }
    }

    suspend fun fetchAttachment(email: String, password: CharArray, mailbox: String, uid: Long, partId: String): ByteArray =
        withContext(Dispatchers.IO.limitedParallelism(1)) {
            require(uid > 0 && partId.matches(Regex("[0-9.]+"))) { "Invalid attachment reference" }
            TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
                val client = ImapCommandClient(connection)
                client.requireGreeting()
                client.login(email, password)
                client.selectMailbox(mailbox)
                client.fetchBodyPart(uid, partId)
            }
        }

    suspend fun fetchMessageBody(
        email: String,
        password: CharArray,
        mailbox: String,
        uid: Long,
    ): ParsedMessageBody = withContext(Dispatchers.IO.limitedParallelism(1)) {
        require(uid > 0) { "Invalid message UID" }
        TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
            val client = ImapCommandClient(connection)
            client.requireGreeting()
            client.login(email, password)
            client.selectMailbox(mailbox)
            client.fetchMessageBody(uid)
        }
    }

    suspend fun fetchStorageQuota(email: String, password: CharArray): ImapStorageQuota? =
        withContext(Dispatchers.IO.limitedParallelism(1)) {
            TlsImapConnection.open(host, port, connectTimeoutMillis, readTimeoutMillis).use { connection ->
                val client = ImapCommandClient(connection)
                client.requireGreeting()
                client.login(email, password)
                client.getStorageQuota()
            }
        }

    /** Stay in IMAP IDLE for a bounded interval and return when the server ends it. */
    suspend fun idle(email: String, password: CharArray, onMailboxChanged: suspend () -> Unit) =
        withContext(Dispatchers.IO.limitedParallelism(1)) {
            TlsImapConnection.open(host, port, connectTimeoutMillis, IDLE_WINDOW_MILLIS.toInt() + 60_000).use { connection ->
                val client = ImapCommandClient(connection)
                client.requireGreeting()
                client.login(email, password)
                client.selectInbox()
                client.idle(IDLE_WINDOW_MILLIS, onMailboxChanged)
            }
        }
}

data class ImapMutation(
    val uid: Long,
    val type: String,
    val payload: String? = null,
)

private class TlsImapConnection private constructor(private val socket: SSLSocket) : AutoCloseable {
    private val input = BufferedInputStream(socket.inputStream)
    private val output = BufferedOutputStream(socket.outputStream)

    fun readResponse(): ImapResponse {
        val literals = mutableListOf<ByteArray>()
        val assembled = StringBuilder()
        var line = readLine()
        while (true) {
            val literalMarker = LITERAL_SUFFIX.find(line)
            if (literalMarker == null) {
                assembled.append(line)
                break
            }
            assembled.append(line.substring(0, literalMarker.range.first))
            val length = literalMarker.groupValues[1].toIntOrNull()
                ?: throw ImapException.Protocol("Invalid IMAP literal length")
            literals += readExactly(length)
            assembled.append(' ').append('\u0000').append('L').append(literals.lastIndex).append('\u0000')
            line = readLine()
        }
        return try {
            ImapResponseParser.parse(assembled.toString(), literals)
        } catch (error: ImapException) {
            throw error
        } catch (_: Exception) {
            throw ImapException.Protocol("Malformed IMAP response")
        }
    }

    fun write(command: String) {
        require(!command.contains('\r') && !command.contains('\n')) { "Invalid IMAP command" }
        output.write((command + "\r\n").toByteArray(StandardCharsets.UTF_8))
        output.flush()
    }

    fun writeLiteral(bytes: ByteArray) {
        output.write(bytes)
        output.write("\r\n".toByteArray(StandardCharsets.US_ASCII))
        output.flush()
    }

    private fun readLine(): String {
        val bytes = ArrayList<Byte>(128)
        while (true) {
            val next = try {
                input.read()
            } catch (error: SocketTimeoutException) {
                throw ImapException.Transport(error)
            } catch (error: IOException) {
                throw ImapException.Transport(error)
            }
            if (next == -1) throw ImapException.Protocol("IMAP server disconnected")
            if (next == '\n'.code) {
                if (bytes.lastOrNull() == '\r'.code.toByte()) bytes.removeAt(bytes.lastIndex)
                return bytes.toByteArray().toString(StandardCharsets.UTF_8)
            }
            if (bytes.size >= MAX_LINE_BYTES) throw ImapException.Protocol("IMAP response line exceeds limit")
            bytes += next.toByte()
        }
    }

    private fun readExactly(length: Int): ByteArray {
        if (length !in 0..MAX_LITERAL_BYTES) throw ImapException.Protocol("IMAP literal exceeds limit")
        val bytes = ByteArray(length)
        var offset = 0
        try {
            while (offset < length) {
                val read = input.read(bytes, offset, length - offset)
                if (read < 0) throw ImapException.Protocol("IMAP server disconnected in literal")
                offset += read
            }
        } catch (error: ImapException) {
            throw error
        } catch (error: IOException) {
            throw ImapException.Transport(error)
        }
        return bytes
    }

    override fun close() = runCatching { socket.close() }.getOrNull().let { }

    companion object {
        // The closing brace is a regex metacharacter too. Android's ICU regex engine
        // rejects an unescaped one during class initialization.
        private val LITERAL_SUFFIX = Regex("\\{(\\d+)\\+?\\}$")
        private const val MAX_LINE_BYTES = 64 * 1024
        private const val MAX_LITERAL_BYTES = 8 * 1024 * 1024

        fun open(host: String, port: Int, connectTimeoutMillis: Int, readTimeoutMillis: Int): TlsImapConnection = try {
            val socket = (SSLSocketFactory.getDefault().createSocket() as SSLSocket).apply {
                sslParameters = SSLParameters().apply { endpointIdentificationAlgorithm = "HTTPS" }
                connect(InetSocketAddress(host, port), connectTimeoutMillis)
                soTimeout = readTimeoutMillis
                startHandshake()
            }
            TlsImapConnection(socket)
        } catch (error: ImapException) {
            throw error
        } catch (error: Exception) {
            throw ImapException.Transport(error)
        }
    }
}

private class ImapCommandClient(private val connection: TlsImapConnection) {
    private var commandNumber = 1

    fun requireGreeting() {
        val greeting = connection.readResponse() as? ImapResponse.Untagged
            ?: throw ImapException.Protocol("Expected IMAP greeting")
        if (greeting.values.firstOrNull()?.atomValue()?.equals("OK", ignoreCase = true) != true) {
            throw ImapException.Protocol("IMAP server rejected connection")
        }
    }

    fun capability(): Set<String> = execute("CAPABILITY").flatMap { response ->
        (response as? ImapResponse.Untagged)?.values
            ?.takeIf { it.firstOrNull()?.atomValue()?.equals("CAPABILITY", ignoreCase = true) == true }
            ?.drop(1)
            ?.mapNotNull { it.atomValue() }
            .orEmpty()
    }.map { it.uppercase() }.toSet()

    fun login(email: String, password: CharArray) {
        execute("LOGIN ${quote(email)} ${quote(String(password))}", authenticationCommand = true)
    }

    fun listMailboxes(): List<ImapMailbox> = execute("LIST \"\" \"*\"").mapNotNull { response ->
        val values = (response as? ImapResponse.Untagged)?.values ?: return@mapNotNull null
        if (values.firstOrNull()?.atomValue()?.equals("LIST", ignoreCase = true) != true) return@mapNotNull null
        val attributes = values.getOrNull(1)?.listValue().orEmpty().mapNotNull { it.atomValue() }.toSet()
        val name = values.getOrNull(3)?.atomValue() ?: return@mapNotNull null
        ImapMailbox(name = name, attributes = attributes)
    }

    fun getStorageQuota(): ImapStorageQuota? {
        val responses = execute("GETQUOTAROOT \"INBOX\"")
        val storage = responses.asSequence().filterIsInstance<ImapResponse.Untagged>()
            .mapNotNull { response ->
                val values = response.values
                if (values.firstOrNull()?.atomValue()?.equals("QUOTA", ignoreCase = true) != true) return@mapNotNull null
                values.drop(2).flatMap { it.listValue() }.firstOrNull { it.atomValue()?.equals("STORAGE", ignoreCase = true) == true }
                    ?.let { marker ->
                        val item = values.drop(2).flatMap { it.listValue() }
                        val at = item.indexOf(marker)
                        (item.getOrNull(at + 1)?.atomValue()?.toLongOrNull()) to (item.getOrNull(at + 2)?.atomValue()?.toLongOrNull())
                    }
            }.firstOrNull() ?: return null
        val used = storage.first ?: return null
        val limit = storage.second ?: return null
        if (used < 0 || limit <= 0) return null
        return ImapStorageQuota(used, limit)
    }

    fun replaceDraft(draftId: String, capabilities: Set<String>) {
        deleteDraft(draftId, capabilities)
    }

    fun deleteDraft(draftId: String, capabilities: Set<String>) {
        val messageId = "<$draftId@glassmail.local>"
        val search = execute("UID SEARCH HEADER MESSAGE-ID ${quote(messageId)}")
            .filterIsInstance<ImapResponse.Untagged>()
            .firstOrNull { it.values.firstOrNull()?.atomValue()?.equals("SEARCH", true) == true }
            ?.values.orEmpty().drop(1).mapNotNull { it.atomValue()?.toLongOrNull() }
        if (search.isEmpty()) return
        if (capabilities.none { it.equals("UIDPLUS", ignoreCase = true) }) {
            throw ImapException.Protocol("Server does not support safe draft replacement")
        }
        val uidSet = search.joinToString(",")
        execute("UID STORE $uidSet +FLAGS.SILENT (\\Deleted)")
        execute("UID EXPUNGE $uidSet")
    }

    fun fetchDrafts(limit: Int): List<ImapRemoteDraft> {
        val search = execute("UID SEARCH ALL")
            .filterIsInstance<ImapResponse.Untagged>()
            .firstOrNull { it.values.firstOrNull()?.atomValue()?.equals("SEARCH", true) == true }
            ?.values.orEmpty().drop(1).mapNotNull { it.atomValue()?.toLongOrNull() }
            .takeLast(limit)
        if (search.isEmpty()) return emptyList()
        return execute("UID FETCH ${search.joinToString(",")} (UID INTERNALDATE BODY.PEEK[])")
            .mapNotNull { response ->
                val values = (response as? ImapResponse.Untagged)?.values ?: return@mapNotNull null
                if (values.getOrNull(1)?.atomValue()?.equals("FETCH", true) != true) return@mapNotNull null
                val fields = values.getOrNull(2)?.listValue().orEmpty()
                val uid = fields.attribute("UID")?.atomValue()?.toLongOrNull() ?: return@mapNotNull null
                val raw = fields.attribute("BODY[]")?.literalValue() ?: return@mapNotNull null
                parseRemoteDraft(uid, fields.attribute("INTERNALDATE")?.atomValue(), raw)
            }
    }

    suspend fun idle(windowMillis: Long, onMailboxChanged: suspend () -> Unit) {
        val tag = "G${commandNumber++.toString().padStart(4, '0')}"
        connection.write("$tag IDLE")
        if (connection.readResponse() !is ImapResponse.Continuation) throw ImapException.Protocol("Server rejected IMAP IDLE")
        val scheduler = Executors.newSingleThreadScheduledExecutor()
        try {
            scheduler.schedule({ runCatching { connection.write("DONE") } }, windowMillis, TimeUnit.MILLISECONDS)
            while (true) {
                when (val response = connection.readResponse()) {
                    is ImapResponse.Continuation -> Unit
                    is ImapResponse.Untagged -> {
                        val values = response.values
                        if (values.getOrNull(1)?.atomValue()?.equals("EXISTS", ignoreCase = true) == true) onMailboxChanged()
                    }
                    is ImapResponse.Tagged -> if (response.tag == tag) {
                        if (response.status.equals("OK", ignoreCase = true)) return
                        throw ImapException.Protocol("Server ended IMAP IDLE with ${response.status}")
                    } else throw ImapException.Protocol("Unexpected IMAP IDLE command tag")
                }
            }
        } finally {
            scheduler.shutdownNow()
        }
    }

    fun append(mailbox: String, flag: String, rawMessage: ByteArray) {
        require(flag == "\\Seen" || flag == "\\Draft")
        val tag = "G${commandNumber++.toString().padStart(4, '0')}"
        connection.write("$tag APPEND ${quote(mailbox)} ($flag) {${rawMessage.size}}")
        when (val response = connection.readResponse()) {
            is ImapResponse.Continuation -> Unit
            is ImapResponse.Tagged -> throw ImapException.Protocol("IMAP APPEND was rejected (${response.status})")
            is ImapResponse.Untagged -> throw ImapException.Protocol("Unexpected response before IMAP APPEND literal")
        }
        connection.writeLiteral(rawMessage)
        while (true) {
            when (val response = connection.readResponse()) {
                is ImapResponse.Continuation -> throw ImapException.Protocol("Unexpected IMAP APPEND continuation")
                is ImapResponse.Untagged -> Unit
                is ImapResponse.Tagged -> if (response.tag == tag) {
                    if (response.status.equals("OK", ignoreCase = true)) return
                    throw ImapException.Protocol("IMAP APPEND was rejected (${response.status})")
                } else throw ImapException.Protocol("Unexpected IMAP command tag")
            }
        }
    }

    fun selectInbox(): ImapSelectedMailbox {
        return selectMailbox("INBOX")
    }

    fun selectMailbox(mailbox: String): ImapSelectedMailbox {
        val responses = execute("SELECT ${quote(mailbox)}")
        val uidValidity = responses.firstNotNullOfOrNull { response ->
            (response as? ImapResponse.Untagged)?.values?.uidResponse("UIDVALIDITY")
        }?.toLongOrNull() ?: throw ImapException.Protocol("SELECT response missing UIDVALIDITY")
        val uidNext = responses.firstNotNullOfOrNull { response ->
            (response as? ImapResponse.Untagged)?.values?.uidResponse("UIDNEXT")
        }?.toLongOrNull() ?: throw ImapException.Protocol("SELECT response missing UIDNEXT")
        val count = responses.firstNotNullOfOrNull { response ->
            val values = (response as? ImapResponse.Untagged)?.values ?: return@firstNotNullOfOrNull null
            values.takeIf { it.size >= 2 && it[1].atomValue().equals("EXISTS", ignoreCase = true) }?.first()?.atomValue()?.toIntOrNull()
        } ?: 0
        return ImapSelectedMailbox(uidValidity = uidValidity, uidNext = uidNext, messageCount = count)
    }

    fun fetchLatestMetadata(
        limit: Int,
        messageCount: Int,
        supportsGmailExtensions: Boolean,
    ): List<ImapMessageMetadata> {
        require(limit in 1..250) { "IMAP page limit must be bounded" }
        if (messageCount <= 0) return emptyList()
        val firstSequence = (messageCount - limit + 1).coerceAtLeast(1)
        return fetchMetadata("$firstSequence:*", supportsGmailExtensions, useUid = false)
    }

    fun fetchMetadata(uidRange: String, supportsGmailExtensions: Boolean): List<ImapMessageMetadata> =
        fetchMetadata(uidRange, supportsGmailExtensions, useUid = true)

    private fun fetchMetadata(uidRange: String, supportsGmailExtensions: Boolean, useUid: Boolean): List<ImapMessageMetadata> {
        val fields = if (supportsGmailExtensions) {
            "UID FLAGS ENVELOPE INTERNALDATE RFC822.SIZE X-GM-MSGID X-GM-THRID X-GM-LABELS BODY.PEEK[HEADER.FIELDS (LIST-UNSUBSCRIBE LIST-UNSUBSCRIBE-POST PRECEDENCE LIST-ID)]"
        } else {
            "UID FLAGS ENVELOPE INTERNALDATE RFC822.SIZE BODY.PEEK[HEADER.FIELDS (LIST-UNSUBSCRIBE LIST-UNSUBSCRIBE-POST PRECEDENCE LIST-ID)]"
        }
        val prefix = if (useUid) "UID FETCH" else "FETCH"
        return execute("$prefix $uidRange ($fields)").mapNotNull { response -> GmailFetchMapper.map(response) }
    }

    fun fetchBodyPart(uid: Long, partId: String): ByteArray {
        val response = execute("UID FETCH $uid (BODY.PEEK[$partId])")
            .asSequence().filterIsInstance<ImapResponse.Untagged>().firstOrNull { item ->
                item.values.getOrNull(1)?.atomValue()?.equals("FETCH", ignoreCase = true) == true
            } ?: throw ImapException.Protocol("Attachment response missing")
        val fields = response.values.getOrNull(2)?.listValue().orEmpty()
        return fields.firstNotNullOfOrNull { it.literalValue() }
            ?: throw ImapException.Protocol("Attachment payload missing")
    }

    fun fetchMessageBody(uid: Long): ParsedMessageBody {
        val responses = execute("UID FETCH $uid (BODY.PEEK[])")
        val fetch = responses.asSequence().filterIsInstance<ImapResponse.Untagged>().firstOrNull { item ->
            item.values.getOrNull(1)?.atomValue()?.equals("FETCH", ignoreCase = true) == true
        } ?: throw ImapException.Protocol("Fetch body response missing")
        val fields = fetch.values.getOrNull(2)?.listValue().orEmpty()
        val rawBytes = fields.firstNotNullOfOrNull { it.literalValue() }
            ?: throw ImapException.Protocol("Message body payload missing")
        return MimeDecoder.parseRfc822(rawBytes)
    }

    fun applyMutation(mutation: ImapMutation) {
        val command = when (mutation.type) {
            "MARK_READ" -> "UID STORE ${mutation.uid} +FLAGS.SILENT (\\Seen)"
            "MARK_UNREAD" -> "UID STORE ${mutation.uid} -FLAGS.SILENT (\\Seen)"
            "STAR" -> "UID STORE ${mutation.uid} +FLAGS.SILENT (\\Flagged)"
            "UNSTAR" -> "UID STORE ${mutation.uid} -FLAGS.SILENT (\\Flagged)"
            "DELETE" -> "UID STORE ${mutation.uid} +X-GM-LABELS.SILENT (\\Trash)"
            "ARCHIVE" -> "UID STORE ${mutation.uid} -X-GM-LABELS.SILENT (\\Inbox)"
            "ADD_LABEL" -> "UID STORE ${mutation.uid} +X-GM-LABELS.SILENT (${quote(mutation.payload ?: throw ImapException.Protocol("Missing label"))})"
            "REMOVE_LABEL" -> "UID STORE ${mutation.uid} -X-GM-LABELS.SILENT (${quote(mutation.payload ?: throw ImapException.Protocol("Missing label"))})"
            else -> throw ImapException.Protocol("Unsupported pending mutation")
        }
        execute(command)
    }

    private fun execute(command: String, authenticationCommand: Boolean = false): List<ImapResponse> {
        val tag = "G${commandNumber++.toString().padStart(4, '0')}"
        connection.write("$tag $command")
        val responses = mutableListOf<ImapResponse>()
        while (true) {
            when (val response = connection.readResponse()) {
                is ImapResponse.Continuation -> throw ImapException.Protocol("Unsupported IMAP continuation")
                is ImapResponse.Untagged -> responses += response
                is ImapResponse.Tagged -> if (response.tag == tag) {
                    when (response.status.uppercase()) {
                        "OK" -> return responses
                        "NO", "BAD" -> if (authenticationCommand) {
                            throw ImapException.Authentication()
                        } else {
                            throw ImapException.Protocol("IMAP command was rejected")
                        }
                        else -> throw ImapException.Protocol("Unknown IMAP completion status")
                    }
                } else {
                    throw ImapException.Protocol("Unexpected IMAP command tag")
                }
            }
        }
    }

    private fun quote(value: String): String {
        require(value.none { it == '\r' || it == '\n' || it.code < 0x20 }) { "Invalid IMAP credential" }
        return "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""
    }
}

private object GmailFetchMapper {
    fun map(response: ImapResponse): ImapMessageMetadata? {
        val values = (response as? ImapResponse.Untagged)?.values ?: return null
        if (values.getOrNull(1)?.atomValue()?.equals("FETCH", ignoreCase = true) != true) return null
        val fields = values.getOrNull(2)?.listValue().orEmpty()
        val uid = fields.attribute("UID")?.atomValue()?.toLongOrNull() ?: return null
        val envelope = fields.attribute("ENVELOPE")?.listValue().orEmpty()
        val rawSubject = envelope.getOrNull(1)?.atomValue()
        val decodedSubject = rawSubject?.let(MimeDecoder::decodeMimeWords)

        val fromList = envelope.getOrNull(2)?.listValue().orEmpty().firstOrNull()?.listValue().orEmpty()
        val personalName = fromList.getOrNull(0)?.atomValue()?.let(MimeDecoder::decodeMimeWords)?.trim('"', ' ', '\t')
        val mailbox = fromList.getOrNull(2)?.atomValue()
        val host = fromList.getOrNull(3)?.atomValue()
        val emailAddress = listOfNotNull(mailbox, host).joinToString("@").ifBlank { null }

        val senderFormatted = when {
            !personalName.isNullOrBlank() && emailAddress != null -> "$personalName <$emailAddress>"
            !personalName.isNullOrBlank() -> personalName
            else -> emailAddress
        }

        val categoryHeaders = fields.attribute("BODY[HEADER.FIELDS (LIST-UNSUBSCRIBE LIST-UNSUBSCRIBE-POST PRECEDENCE LIST-ID)]")
            ?.literalValue()
            ?.toString(StandardCharsets.UTF_8)
            ?.let(::parseCategoryHeaders)
            .orEmpty()

        return ImapMessageMetadata(
            uid = uid,
            flags = fields.attribute("FLAGS")?.listValue().orEmpty().mapNotNull { it.atomValue() }.toSet(),
            gmailMessageId = fields.attribute("X-GM-MSGID")?.atomValue(),
            gmailThreadId = fields.attribute("X-GM-THRID")?.atomValue(),
            labels = fields.attribute("X-GM-LABELS")?.listValue().orEmpty().mapNotNull { it.atomValue() }.toSet(),
            subject = decodedSubject,
            sender = senderFormatted,
            sentAtEpochMillis = envelope.getOrNull(0)?.atomValue()?.let(::parseImapDate),
            sizeBytes = fields.attribute("RFC822.SIZE")?.atomValue()?.toLongOrNull(),
            hasListUnsubscribe = !categoryHeaders["list-unsubscribe"].isNullOrBlank(),
            precedence = categoryHeaders["precedence"],
            listId = categoryHeaders["list-id"],
            listUnsubscribe = categoryHeaders["list-unsubscribe"],
            listUnsubscribePost = categoryHeaders["list-unsubscribe-post"],
        )
    }

    private fun parseCategoryHeaders(rawHeaders: String): Map<String, String> = buildMap {
        var currentName: String? = null
        val currentValue = StringBuilder()
        fun flush() {
            currentName?.let { put(it, currentValue.toString().trim()) }
            currentValue.clear()
        }
        rawHeaders.lineSequence().forEach { line ->
            if (line.startsWith(' ') || line.startsWith('\t')) {
                if (currentName != null) currentValue.append(' ').append(line.trim())
            } else {
                flush()
                val colon = line.indexOf(':')
                if (colon > 0) {
                    currentName = line.substring(0, colon).trim().lowercase()
                    currentValue.append(line.substring(colon + 1).trim())
                } else {
                    currentName = null
                }
            }
        }
        flush()
    }

    private fun parseImapDate(value: String): Long? = runCatching {
        ZonedDateTime.parse(value, DateTimeFormatter.RFC_1123_DATE_TIME).toInstant().toEpochMilli()
    }.getOrNull()
}

private fun parseRemoteDraft(uid: Long, internalDate: String?, raw: ByteArray): ImapRemoteDraft {
    val content = raw.toString(StandardCharsets.ISO_8859_1)
    val crlfSplit = content.indexOf("\r\n\r\n")
    val headerEnd = if (crlfSplit >= 0) crlfSplit else content.indexOf("\n\n")
    val headers = parseHeaderValues(if (headerEnd >= 0) content.substring(0, headerEnd) else "")
    val parsedBody = MimeDecoder.parseRfc822(raw)
    val messageId = headers["message-id"].orEmpty()
    val draftId = Regex("<([^<>@]+)@glassmail\\.local>", RegexOption.IGNORE_CASE).find(messageId)?.groupValues?.get(1)
    fun addresses(name: String): List<String> = runCatching {
        InternetAddress.parse(headers[name].orEmpty()).mapNotNull { it.address?.trim()?.takeIf(String::isNotBlank) }
    }.getOrDefault(emptyList())
    val updatedAt = internalDate?.let { value ->
        runCatching { OffsetDateTime.parse(value, DateTimeFormatter.ofPattern("dd-MMM-yyyy HH:mm:ss Z", Locale.US)).toInstant().toEpochMilli() }.getOrNull()
    } ?: 0L
    return ImapRemoteDraft(
        uid = uid,
        draftId = draftId,
        to = addresses("to"),
        cc = addresses("cc"),
        bcc = addresses("bcc"),
        subject = MimeDecoder.decodeMimeWords(headers["subject"]),
        body = parsedBody.plainText ?: parsedBody.previewSnippet,
        inReplyTo = headers["in-reply-to"],
        references = headers["references"].orEmpty().split(Regex("\\s+")).filter(String::isNotBlank),
        updatedAtEpochMillis = updatedAt,
    )
}

private fun parseHeaderValues(raw: String): Map<String, String> = buildMap {
    var name: String? = null
    val value = StringBuilder()
    fun flush() {
        name?.let { put(it, value.toString().trim()) }
        value.clear()
    }
    raw.lineSequence().forEach { line ->
        if (line.startsWith(' ') || line.startsWith('\t')) {
            if (name != null) value.append(' ').append(line.trim())
        } else {
            flush()
            val colon = line.indexOf(':')
            if (colon > 0) {
                name = line.substring(0, colon).trim().lowercase()
                value.append(line.substring(colon + 1).trim())
            } else name = null
        }
    }
    flush()
}

private const val MAX_APPEND_BYTES = 32 * 1024 * 1024
private const val IDLE_WINDOW_MILLIS = 25 * 60 * 1000L

private fun List<ImapValue>.uidResponse(name: String): String? = getOrNull(1)?.listValue().orEmpty()
    .takeIf { getOrNull(0)?.atomValue()?.equals("OK", ignoreCase = true) == true }
    ?.attribute(name)
    ?.atomValue()
