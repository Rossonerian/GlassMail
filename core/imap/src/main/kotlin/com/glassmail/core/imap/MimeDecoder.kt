package com.glassmail.core.imap

import java.io.ByteArrayOutputStream
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets
import java.util.Base64

data class ParsedMessageBody(
    val plainText: String?,
    val htmlText: String?,
    val previewSnippet: String,
    val attachments: List<ParsedAttachmentInfo> = emptyList(),
)

data class ParsedAttachmentInfo(
    val partId: String,
    val fileName: String,
    val mimeType: String,
    val sizeBytes: Long,
)

object MimeDecoder {

    private val ENCODED_WORD_REGEX = Regex("=\\?([A-Za-z0-9_-]+)\\?([BbQq])\\?([^?]+)\\?=")
    private val ADJACENT_ENCODED_WORDS_REGEX = Regex("(\\?=\\s*=\\?)")

    /**
     * Decodes RFC 2047 encoded-words in headers (Subject, From, To, etc.).
     * E.g.: "=?UTF-8?Q?=E2=8F=B0_[$60_OFF]_Limited_Time!?=" -> "⏰ [$60 OFF] Limited Time!?"
     */
    fun decodeMimeWords(input: String?): String {
        if (input.isNullOrBlank()) return input.orEmpty()
        if (!input.contains("=?")) return input

        // RFC 2047: White space between adjacent encoded words MUST be ignored.
        // We temporarily replace adjacent words with a direct concatenation marker
        var normalized = input
        // Replace whitespace between ?= and =?
        normalized = normalized.replace(Regex("(\\?=\\s+=\\?)")) { match ->
            "?==?"
        }

        return ENCODED_WORD_REGEX.replace(normalized) { match ->
            val charsetName = match.groupValues[1]
            val encoding = match.groupValues[2].uppercase()
            val encodedText = match.groupValues[3]

            val charset = runCatching { Charset.forName(charsetName) }.getOrElse { StandardCharsets.UTF_8 }

            try {
                when (encoding) {
                    "B" -> decodeBase64(encodedText, charset)
                    "Q" -> decodeQuotedPrintable(encodedText, charset, isHeader = true)
                    else -> match.value
                }
            } catch (_: Exception) {
                match.value
            }
        }
    }

    /**
     * Decodes Quoted-Printable encoded string or bytes.
     * In headers (RFC 2047), '_' represents space (0x20).
     */
    fun decodeQuotedPrintable(input: String, charset: Charset = StandardCharsets.UTF_8, isHeader: Boolean = false): String {
        val out = ByteArrayOutputStream()
        var i = 0
        val len = input.length
        while (i < len) {
            val c = input[i]
            when {
                c == '_' && isHeader -> {
                    out.write(' '.code)
                    i++
                }
                c == '=' -> {
                    if (i + 1 < len && (input[i + 1] == '\r' || input[i + 1] == '\n')) {
                        // Soft line break: = followed by CRLF or LF
                        i++
                        if (i < len && input[i] == '\r') i++
                        if (i < len && input[i] == '\n') i++
                    } else if (i + 2 < len) {
                        val hex = input.substring(i + 1, i + 3)
                        val byteVal = hex.toIntOrNull(16)
                        if (byteVal != null) {
                            out.write(byteVal)
                            i += 3
                        } else {
                            out.write('='.code)
                            i++
                        }
                    } else {
                        out.write('='.code)
                        i++
                    }
                }
                else -> {
                    out.write(c.code)
                    i++
                }
            }
        }
        return out.toByteArray().toString(charset)
    }

    private fun decodeBase64(input: String, charset: Charset): String {
        val clean = input.filterNot { it.isWhitespace() }
        val decoded = Base64.getDecoder().decode(clean)
        return String(decoded, charset)
    }

    /**
     * Parses a full RFC 822 message payload or body text into [ParsedMessageBody].
     */
    fun parseRfc822(rawBytes: ByteArray): ParsedMessageBody {
        val content = rawBytes.toString(StandardCharsets.ISO_8859_1)
        val headerEnd = findHeaderEnd(content)
        val headerSection = if (headerEnd > 0) content.substring(0, headerEnd) else ""
        val bodySection = if (headerEnd > 0) content.substring(headerEnd) else content

        val headers = parseHeaders(headerSection)
        val contentType = headers["content-type"] ?: "text/plain; charset=utf-8"
        val transferEncoding = headers["content-transfer-encoding"]?.lowercase()?.trim() ?: "7bit"

        val (plain, html) = parseBodyParts(contentType, transferEncoding, bodySection)

        val cleanPlain = plain?.let { normalizeWhitespace(it) }
        val cleanHtmlAsText = html?.let { htmlToPlainText(it) }

        val bestText = when {
            !cleanPlain.isNullOrBlank() -> cleanPlain
            !cleanHtmlAsText.isNullOrBlank() -> cleanHtmlAsText
            else -> ""
        }

        val preview = generateSnippet(bestText)

        return ParsedMessageBody(
            plainText = cleanPlain ?: cleanHtmlAsText,
            htmlText = html,
            previewSnippet = preview,
        )
    }

    private fun findHeaderEnd(content: String): Int {
        val crlfcrlf = content.indexOf("\r\n\r\n")
        if (crlfcrlf != -1) return crlfcrlf + 4
        val lflf = content.indexOf("\n\n")
        if (lflf != -1) return lflf + 2
        return -1
    }

    private fun parseHeaders(headerText: String): Map<String, String> {
        val map = mutableMapOf<String, String>()
        val lines = headerText.lines()
        var currentKey: String? = null
        val currentValue = StringBuilder()

        for (line in lines) {
            if (line.startsWith(" ") || line.startsWith("\t")) {
                if (currentKey != null) {
                    currentValue.append(" ").append(line.trim())
                }
            } else {
                if (currentKey != null) {
                    map[currentKey.lowercase()] = currentValue.toString()
                }
                val colon = line.indexOf(':')
                if (colon != -1) {
                    currentKey = line.substring(0, colon).trim()
                    currentValue.setLength(0)
                    currentValue.append(line.substring(colon + 1).trim())
                } else {
                    currentKey = null
                }
            }
        }
        if (currentKey != null) {
            map[currentKey.lowercase()] = currentValue.toString()
        }
        return map
    }

    private fun parseBodyParts(
        contentType: String,
        transferEncoding: String,
        rawBody: String,
    ): Pair<String?, String?> {
        val mimeType = contentType.substringBefore(';').trim().lowercase()

        if (mimeType.startsWith("multipart/")) {
            val boundary = extractParameter(contentType, "boundary")
            if (!boundary.isNullOrBlank()) {
                return parseMultipart(rawBody, boundary)
            }
        }

        // Single part
        val charset = extractCharset(contentType)
        val decoded = decodeTransferEncoding(rawBody, transferEncoding, charset)

        return if (mimeType == "text/html") {
            Pair(null, decoded)
        } else {
            Pair(decoded, null)
        }
    }

    private fun parseMultipart(body: String, boundary: String): Pair<String?, String?> {
        val marker = "--$boundary"
        val parts = body.split(marker)
        var bestPlain: String? = null
        var bestHtml: String? = null

        for (part in parts) {
            val trimmed = part.trim()
            if (trimmed.isEmpty() || trimmed == "--") continue

            val headerEnd = findHeaderEnd(trimmed)
            val headerSection = if (headerEnd > 0) trimmed.substring(0, headerEnd) else ""
            val bodySection = if (headerEnd > 0) trimmed.substring(headerEnd) else trimmed

            val partHeaders = parseHeaders(headerSection)
            val partType = partHeaders["content-type"] ?: "text/plain"
            val partEncoding = partHeaders["content-transfer-encoding"]?.lowercase()?.trim() ?: "7bit"

            val (subPlain, subHtml) = parseBodyParts(partType, partEncoding, bodySection)
            if (subPlain != null && bestPlain == null) bestPlain = subPlain
            if (subHtml != null && bestHtml == null) bestHtml = subHtml
        }

        return Pair(bestPlain, bestHtml)
    }

    private fun decodeTransferEncoding(content: String, encoding: String, charset: Charset): String {
        return when (encoding) {
            "quoted-printable" -> decodeQuotedPrintable(content, charset, isHeader = false)
            "base64" -> runCatching {
                val clean = content.filterNot { it.isWhitespace() }
                val bytes = Base64.getDecoder().decode(clean)
                String(bytes, charset)
            }.getOrElse { content }
            else -> {
                // If it was read as ISO_8859_1, re-encode to bytes and interpret with proper charset
                if (charset != StandardCharsets.ISO_8859_1) {
                    val bytes = content.toByteArray(StandardCharsets.ISO_8859_1)
                    String(bytes, charset)
                } else {
                    content
                }
            }
        }
    }

    private fun extractParameter(header: String, paramName: String): String? {
        val regex = Regex("$paramName=\"?([^\";]+)\"?", RegexOption.IGNORE_CASE)
        return regex.find(header)?.groupValues?.get(1)?.trim()
    }

    private fun extractCharset(contentType: String): Charset {
        val charsetName = extractParameter(contentType, "charset") ?: "utf-8"
        return runCatching { Charset.forName(charsetName) }.getOrElse { StandardCharsets.UTF_8 }
    }

    /**
     * Converts basic HTML to clean plain text.
     */
    fun htmlToPlainText(html: String): String {
        var text = html
        // Remove style and script tags and their contents
        text = text.replace(Regex("(?is)<style.*?>.*?</style>"), "")
        text = text.replace(Regex("(?is)<script.*?>.*?</script>"), "")
        // Replace paragraph and break tags with newlines
        text = text.replace(Regex("(?i)<br\\s*/?>"), "\n")
        text = text.replace(Regex("(?i)</?(p|div|tr|h[1-6]|li)[^>]*>"), "\n")
        // Strip remaining tags
        text = text.replace(Regex("<[^>]+>"), "")
        // Decode HTML entities
        text = decodeHtmlEntities(text)
        return normalizeWhitespace(text)
    }

    private fun decodeHtmlEntities(input: String): String {
        var res = input
        res = res.replace("&nbsp;", " ")
        res = res.replace("&amp;", "&")
        res = res.replace("&lt;", "<")
        res = res.replace("&gt;", ">")
        res = res.replace("&quot;", "\"")
        res = res.replace("&#39;", "'")
        res = res.replace("&apos;", "'")
        res = res.replace(Regex("&#(\\d+);")) { match ->
            val code = match.groupValues[1].toIntOrNull()
            if (code != null && code in 0..0x10FFFF) String(Character.toChars(code)) else match.value
        }
        res = res.replace(Regex("&#x([0-9a-fA-F]+);")) { match ->
            val code = match.groupValues[1].toIntOrNull(16)
            if (code != null && code in 0..0x10FFFF) String(Character.toChars(code)) else match.value
        }
        return res
    }

    private fun normalizeWhitespace(text: String): String {
        val lines = text.lines().map { it.trim() }
        val out = mutableListOf<String>()
        var previousEmpty = false
        for (line in lines) {
            if (line.isEmpty()) {
                if (!previousEmpty && out.isNotEmpty()) {
                    out.add("")
                    previousEmpty = true
                }
            } else {
                out.add(line)
                previousEmpty = false
            }
        }
        return out.joinToString("\n").trim()
    }

    fun generateSnippet(text: String, maxLength: Int = 160): String {
        val singleLine = text.replace(Regex("\\s+"), " ").trim()
        if (singleLine.length <= maxLength) return singleLine
        val truncated = singleLine.take(maxLength)
        val lastSpace = truncated.lastIndexOf(' ')
        return if (lastSpace > maxLength / 2) {
            truncated.substring(0, lastSpace) + "…"
        } else {
            truncated + "…"
        }
    }
}
