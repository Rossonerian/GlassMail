package com.glassmail.core.imap

import org.junit.Assert.assertEquals
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
}
