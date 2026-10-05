package com.glassmail.core.imap

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.nio.charset.StandardCharsets

/** SEARCH can list an entire mailbox. Other response lines retain the smaller bound. */
internal fun readImapLine(input: InputStream): String {
    val bytes = ByteArrayOutputStream(128)
    val prefix = StringBuilder(9)
    var limit = 64 * 1024
    while (true) {
        val next = try {
            input.read()
        } catch (error: IOException) {
            throw ImapException.Transport(error)
        }
        if (next == -1) throw ImapException.Protocol("IMAP server disconnected")
        if (next == '\n'.code) {
            val line = bytes.toByteArray()
            val length = if (line.lastOrNull() == '\r'.code.toByte()) line.size - 1 else line.size
            return String(line, 0, length, StandardCharsets.UTF_8)
        }
        if (prefix.length < 9) {
            prefix.append(next.toChar())
            if (prefix.toString().equals("* SEARCH ", ignoreCase = true)) limit = 4 * 1024 * 1024
        }
        if (bytes.size() >= limit) throw ImapException.Protocol("IMAP response line exceeds limit")
        bytes.write(next)
    }
}
