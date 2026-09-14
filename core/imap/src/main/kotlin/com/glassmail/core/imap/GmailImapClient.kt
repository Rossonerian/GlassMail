package com.glassmail.core.imap

import com.glassmail.core.model.GmailInboxSnapshot
import com.glassmail.core.model.ImapMailbox
import com.glassmail.core.model.ImapMessageMetadata
import com.glassmail.core.model.ImapSelectedMailbox
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.net.InetSocketAddress
import java.net.SocketTimeoutException
import java.nio.charset.StandardCharsets
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import javax.net.ssl.SSLParameters
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory
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
                val firstUid = maxOf(1L, inbox.uidNext - limit)
                val messages = client.fetchMetadata("$firstUid:*")
                GmailInboxSnapshot(
                    capabilities = authenticatedCapabilities,
                    mailboxes = mailboxes,
                    inbox = inbox,
                    messages = messages,
                    requestedThroughUid = inbox.uidNext - 1,
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
            val messages = if (lastUid < firstUid) emptyList() else client.fetchMetadata("$firstUid:$lastUid")
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
        val assembled = StringBuilder(readLine())
        while (LITERAL_SUFFIX.find(assembled)?.groupValues?.get(1) != null) {
            val length = LITERAL_SUFFIX.find(assembled)!!.groupValues[1].toInt()
            literals += readExactly(length)
            assembled.append('\u0000').append('L').append(literals.lastIndex).append('\u0000')
            assembled.append(' ').append(readLine())
        }
        return ImapResponseParser.parse(assembled.toString(), literals)
    }

    fun write(command: String) {
        require(!command.contains('\r') && !command.contains('\n')) { "Invalid IMAP command" }
        output.write((command + "\r\n").toByteArray(StandardCharsets.UTF_8))
        output.flush()
    }

    private fun readLine(): String {
        val bytes = ArrayList<Byte>(128)
        while (true) {
            val next = try {
                input.read()
            } catch (error: SocketTimeoutException) {
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
        while (offset < length) {
            val read = input.read(bytes, offset, length - offset)
            if (read < 0) throw ImapException.Protocol("IMAP server disconnected in literal")
            offset += read
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
        try {
            execute("LOGIN ${quote(email)} ${quote(String(password))}", authenticationCommand = true)
        } catch (error: ImapException.Protocol) {
            throw ImapException.Authentication()
        }
    }

    fun listMailboxes(): List<ImapMailbox> = execute("LIST \"\" \"*\"").mapNotNull { response ->
        val values = (response as? ImapResponse.Untagged)?.values ?: return@mapNotNull null
        if (values.firstOrNull()?.atomValue()?.equals("LIST", ignoreCase = true) != true) return@mapNotNull null
        val attributes = values.getOrNull(1)?.listValue().orEmpty().mapNotNull { it.atomValue() }.toSet()
        val name = values.getOrNull(3)?.atomValue() ?: return@mapNotNull null
        ImapMailbox(name = name, attributes = attributes)
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

    fun fetchMetadata(uidRange: String): List<ImapMessageMetadata> = execute(
        "UID FETCH $uidRange (UID FLAGS ENVELOPE INTERNALDATE RFC822.SIZE X-GM-MSGID X-GM-THRID X-GM-LABELS)",
    ).mapNotNull { response -> GmailFetchMapper.map(response) }

    fun fetchBodyPart(uid: Long, partId: String): ByteArray {
        val response = execute("UID FETCH $uid (BODY.PEEK[$partId])")
            .asSequence().filterIsInstance<ImapResponse.Untagged>().firstOrNull { item ->
                item.values.getOrNull(1)?.atomValue()?.equals("FETCH", ignoreCase = true) == true
            } ?: throw ImapException.Protocol("Attachment response missing")
        val fields = response.values.getOrNull(2)?.listValue().orEmpty()
        return fields.firstNotNullOfOrNull { it.literalValue() }
            ?: throw ImapException.Protocol("Attachment payload missing")
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
        return ImapMessageMetadata(
            uid = uid,
            flags = fields.attribute("FLAGS")?.listValue().orEmpty().mapNotNull { it.atomValue() }.toSet(),
            gmailMessageId = fields.attribute("X-GM-MSGID")?.atomValue(),
            gmailThreadId = fields.attribute("X-GM-THRID")?.atomValue(),
            labels = fields.attribute("X-GM-LABELS")?.listValue().orEmpty().mapNotNull { it.atomValue() }.toSet(),
            subject = envelope.getOrNull(1)?.atomValue(),
            sender = envelope.getOrNull(2)?.listValue().orEmpty().firstOrNull()?.listValue().orEmpty().let { address ->
                listOfNotNull(address.getOrNull(2)?.atomValue(), address.getOrNull(3)?.atomValue()).joinToString("@")
                    .ifBlank { null }
            },
            sentAtEpochMillis = envelope.getOrNull(0)?.atomValue()?.let(::parseImapDate),
            sizeBytes = fields.attribute("RFC822.SIZE")?.atomValue()?.toLongOrNull(),
        )
    }

    private fun parseImapDate(value: String): Long? = runCatching {
        ZonedDateTime.parse(value, DateTimeFormatter.RFC_1123_DATE_TIME).toInstant().toEpochMilli()
    }.getOrNull()
}

private fun List<ImapValue>.uidResponse(name: String): String? = getOrNull(1)?.listValue().orEmpty()
    .takeIf { getOrNull(0)?.atomValue()?.equals("OK", ignoreCase = true) == true }
    ?.attribute(name)
    ?.atomValue()
