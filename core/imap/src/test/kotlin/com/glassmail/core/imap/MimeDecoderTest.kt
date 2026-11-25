package com.glassmail.core.imap

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.charset.StandardCharsets

class MimeDecoderTest {

    @Test
    fun `decodes Quoted-Printable UTF-8 encoded words`() {
        val input = "=?UTF-8?Q?=E2=8F=B0_[$60_OFF]_Limited_Time!?="
        val decoded = MimeDecoder.decodeMimeWords(input)
        assertEquals("⏰ [$60 OFF] Limited Time!", decoded)
    }

    @Test
    fun `decodes emoji and symbols in QP`() {
        val input = "=?UTF-8?Q?=F0=9F=93=A3_Important_Update:_Delisting_?==?UTF-8?Q?of_Tokens?="
        val decoded = MimeDecoder.decodeMimeWords(input)
        assertEquals("\uD83D\uDCE3 Important Update: Delisting of Tokens", decoded)
    }

    @Test
    fun `decodes Base64 UTF-8 encoded words`() {
        // "Hello World" in Base64 is "SGVsbG8gV29ybGQ="
        val input = "=?UTF-8?B?SGVsbG8gV29ybGQ=?="
        val decoded = MimeDecoder.decodeMimeWords(input)
        assertEquals("Hello World", decoded)
    }

    @Test
    fun `decodes adjacent encoded words separated by whitespace without extra space`() {
        // RFC 2047: space between adjacent words must be removed
        val input = "=?UTF-8?Q?Hello_?=  =?UTF-8?Q?World!?="
        val decoded = MimeDecoder.decodeMimeWords(input)
        assertEquals("Hello World!", decoded)
    }

    @Test
    fun `leaves plain text untouched`() {
        val input = "Standard Plain Subject Without Encoding"
        assertEquals(input, MimeDecoder.decodeMimeWords(input))
    }

    @Test
    fun `parses simple plain text RFC822 message`() {
        val raw = "Content-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\nHello, this is a plain text email body."
        val parsed = MimeDecoder.parseRfc822(raw.toByteArray(StandardCharsets.UTF_8))
        assertEquals("Hello, this is a plain text email body.", parsed.plainText)
        assertEquals("Hello, this is a plain text email body.", parsed.previewSnippet)
    }

    @Test
    fun `parses multipart alternative message and generates snippet`() {
        val raw = """
            Content-Type: multipart/alternative; boundary="boundary42"

            --boundary42
            Content-Type: text/plain; charset=utf-8
            Content-Transfer-Encoding: quoted-printable

            Hello=20World!=20Welcome to GlassMail.
            --boundary42
            Content-Type: text/html; charset=utf-8

            <p>Hello <b>World</b>! Welcome to GlassMail.</p>
            --boundary42--
        """.trimIndent()

        val parsed = MimeDecoder.parseRfc822(raw.toByteArray(StandardCharsets.UTF_8))
        assertTrue(parsed.plainText?.contains("Hello World! Welcome to GlassMail.") == true)
        assertEquals("Hello World! Welcome to GlassMail.", parsed.previewSnippet)
    }

    @Test
    fun `htmlToPlainText strips tags and decodes entities`() {
        val html = "<div><h1>Title</h1><p>Paragraph with &amp; &lt;brackets&gt; &quot;quotes&quot; and&nbsp;spaces.</p></div>"
        val plain = MimeDecoder.htmlToPlainText(html)
        assertTrue(plain.contains("Title"))
        assertTrue(plain.contains("Paragraph with & <brackets> \"quotes\" and spaces."))
    }

    @Test
    fun `svg cid inline image is not inlined into html`() {
        val raw = """
            Content-Type: multipart/related; boundary="rel1"

            --rel1
            Content-Type: text/html; charset=utf-8

            <img src="cid:logo-svg">
            --rel1
            Content-Type: image/svg+xml
            Content-ID: <logo-svg>

            <svg xmlns="http://www.w3.org/2000/svg"></svg>
            --rel1--
        """.trimIndent()

        val parsed = MimeDecoder.parseRfc822(raw.toByteArray(StandardCharsets.UTF_8))
        val html = parsed.htmlText.orEmpty()
        assertTrue(html.contains("cid:logo-svg"))
        assertTrue(!html.contains("data:image/svg+xml"))
    }

    @Test
    fun `repeated cid expansion is capped at MAX_TOTAL_INLINE_DATA_URI_CHARS`() {
        val payload = ByteArray(100 * 1024) { 0x41 }
        val base64Payload = java.util.Base64.getEncoder().encodeToString(payload)
        val cidRefs = (1..60).joinToString(" ") { """<img src="cid:img1">""" }
        val raw = """
            Content-Type: multipart/related; boundary="rel2"

            --rel2
            Content-Type: text/html; charset=utf-8

            $cidRefs
            --rel2
            Content-Type: image/png
            Content-Transfer-Encoding: base64
            Content-ID: <img1>

            $base64Payload
            --rel2--
        """.trimIndent()

        val parsed = MimeDecoder.parseRfc822(raw.toByteArray(StandardCharsets.UTF_8))
        val html = parsed.htmlText.orEmpty()
        assertTrue(html.length <= MimeDecoder.MAX_TOTAL_INLINE_DATA_URI_CHARS + 2048)
        assertTrue(html.contains("cid:img1"))
    }

    @Test
    fun `htmlToPlainText decodes entities in single pass and rejects NUL or surrogate`() {
        val html = "<p>&amp;lt; &#X27; &#0; &#xD800;</p>"
        val plain = MimeDecoder.htmlToPlainText(html)
        assertEquals("&lt; ' &#0; &#xD800;", plain)
    }

    @Test
    fun `htmlToPlainText strips MSO conditional comments`() {
        val html = "<div><!--[if mso]>noise<![endif]-->Hello</div>"
        val plain = MimeDecoder.htmlToPlainText(html)
        assertEquals("Hello", plain)
    }

    @Test
    fun `decodes RFC 2231 language tag and split UTF-8 encoded words`() {
        assertEquals("Hello World", MimeDecoder.decodeMimeWords("=?UTF-8*en?Q?Hello_World?="))
        assertEquals("\uD83D\uDE00", MimeDecoder.decodeMimeWords("=?UTF-8?Q?=F0=9F?= =?UTF-8?Q?=98=80?="))
    }

    @Test
    fun `deeply nested multiparts exceeding max depth do not StackOverflow`() {
        val depth = 40
        val sb = StringBuilder()
        for (i in 1..depth) {
            sb.append("Content-Type: multipart/mixed; boundary=\"b$i\"\r\n\r\n--b$i\r\n")
        }
        sb.append("Content-Type: text/plain; charset=utf-8\r\n\r\nDeep body\r\n")
        for (i in depth downTo 1) {
            sb.append("--b$i--\r\n")
        }
        val bytes = sb.toString().toByteArray(StandardCharsets.UTF_8)

        val javaMailParsed = MimeDecoder.parseRfc822(bytes)
        assertNotNull(javaMailParsed)

        val legacyMethod = MimeDecoder::class.java.getDeclaredMethod("parseRfc822Legacy", ByteArray::class.java)
        legacyMethod.isAccessible = true
        val legacyParsed = legacyMethod.invoke(MimeDecoder, bytes) as ParsedMessageBody
        assertNotNull(legacyParsed)
    }
}
