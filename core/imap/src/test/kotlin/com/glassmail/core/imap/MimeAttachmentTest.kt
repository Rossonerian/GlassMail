package com.glassmail.core.imap

import java.nio.charset.StandardCharsets
import java.util.Base64
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MimeAttachmentTest {
    private fun parse(raw: String) = MimeDecoder.parseRfc822(raw.replace("\n", "\r\n").toByteArray(StandardCharsets.UTF_8))

    private val pdfBase64 = Base64.getMimeEncoder().encodeToString("%PDF-1.4 fake".toByteArray())
    private val pngBase64 = Base64.getEncoder().encodeToString(byteArrayOf(1, 2, 3, 4))

    private val mixed = """
        From: a@example.com
        To: b@example.com
        Subject: Report
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="outer"

        --outer
        Content-Type: multipart/alternative; boundary="alt"

        --alt
        Content-Type: text/plain; charset=utf-8

        Hello plain
        --alt
        Content-Type: multipart/related; boundary="rel"

        --rel
        Content-Type: text/html; charset=utf-8
        Content-Transfer-Encoding: quoted-printable

        <p>Caf=C3=A9 <img src=3D"cid:logo@x"></p>
        --rel
        Content-Type: image/png
        Content-ID: <logo@x>
        Content-Transfer-Encoding: base64

        $pngBase64
        --rel--
        --alt--
        --outer
        Content-Type: application/pdf; name="=?UTF-8?B?cmVwb3J0LeKCrC5wZGY=?="
        Content-Disposition: attachment; filename="=?UTF-8?B?cmVwb3J0LeKCrC5wZGY=?="
        Content-Transfer-Encoding: base64

        $pdfBase64
        --outer--
    """.trimIndent()

    @Test fun `HTML is kept as HTML and plain text is available for previews`() {
        val parsed = parse(mixed)
        assertNotNull(parsed.htmlText)
        assertTrue(parsed.htmlText!!.contains("Café"))
        assertEquals("Hello plain", parsed.plainText)
        assertEquals("Hello plain", parsed.previewSnippet)
    }

    @Test fun `small inline cid images become data URIs and are not listed as attachments`() {
        val parsed = parse(mixed)
        assertTrue(parsed.htmlText!!.contains("data:image/png;base64,$pngBase64"))
        assertFalse(parsed.htmlText!!.contains("cid:"))
        assertEquals(1, parsed.attachments.size)
    }

    @Test fun `attachment metadata uses IMAP part numbering and decodes the file name`() {
        val attachment = parse(mixed).attachments.single()
        assertEquals("2", attachment.partId)
        assertEquals("report-€.pdf", attachment.fileName)
        assertEquals("application/pdf", attachment.mimeType)
    }

    @Test fun `single part message with an attachment only uses part 1`() {
        val parsed = parse(
            """
            From: a@example.com
            Subject: Just a file
            Content-Type: application/pdf; name="x.pdf"
            Content-Disposition: attachment; filename="x.pdf"
            Content-Transfer-Encoding: base64

            $pdfBase64
            """.trimIndent(),
        )
        assertEquals(listOf("1"), parsed.attachments.map { it.partId })
    }

    @Test fun `transfer encodings are undone for stored attachment bytes`() {
        assertEquals("%PDF-1.4 fake", String(decodeTransferEncoding(pdfBase64.toByteArray(), "base64")))
        assertEquals("caf\u00e9", String(decodeTransferEncoding("caf=C3=A9".toByteArray(), "quoted-printable"), StandardCharsets.UTF_8))
        assertEquals("raw", String(decodeTransferEncoding("raw".toByteArray(), "7bit")))
    }
}
