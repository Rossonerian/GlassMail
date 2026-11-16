package com.glassmail.core.imap

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ImapResponseParserTest {

    @Test fun literalSuffixSyntaxIsAcceptedByTheRuntimeRegexEngine() {
        assertTrue(Regex("\\{(\\d+)\\+?\\}$").containsMatchIn("* 1 FETCH (BODY[] {42}"))
    }
    @Test
    fun `parses a Gmail FETCH response with nested flags and labels`() {
        val response = ImapResponseParser.parse(
            "* 42 FETCH (UID 900 FLAGS (\\Seen \\Flagged) X-GM-MSGID 123 X-GM-THRID 456 X-GM-LABELS (\\Inbox \\\"Projects\\\"))",
            emptyList(),
        )

        assertTrue(response is ImapResponse.Untagged)
        val fetch = response as ImapResponse.Untagged
        assertEquals("42", fetch.values[0].atomValue())
        assertEquals("FETCH", fetch.values[1].atomValue())
        assertEquals("900", fetch.values[2].listValue().attribute("UID")?.atomValue())
        assertEquals("123", fetch.values[2].listValue().attribute("X-GM-MSGID")?.atomValue())
    }

    @Test
    fun `maps flags and labels only UID FETCH with quoted multiword label`() {
        val response = ImapResponseParser.parse(
            "* 42 FETCH (UID 900 FLAGS (\\Seen \\Flagged) X-GM-LABELS (\\Inbox \"Project work\"))",
            emptyList(),
        )
        val metadata = GmailFetchMapper.map(response)!!
        assertEquals(900L, metadata.uid)
        assertEquals(setOf("\\Seen", "\\Flagged"), metadata.flags)
        assertEquals(setOf("\\Inbox", "Project work"), metadata.labels)
        assertEquals(null, metadata.subject)
        assertEquals(null, metadata.gmailMessageId)
    }

    @Test
    fun `maps empty flags and labels in reconciliation response`() {
        val metadata = GmailFetchMapper.map(ImapResponseParser.parse(
            "* 1 FETCH (FLAGS () X-GM-LABELS () UID 7)", emptyList(),
        ))!!
        assertEquals(7L, metadata.uid)
        assertTrue(metadata.flags.isEmpty())
        assertTrue(metadata.labels.isEmpty())
    }

    @Test
    fun `parses a literal without treating it as an atom`() {
        val response = ImapResponseParser.parse(
            "* 1 FETCH (BODY[] \u0000L0\u0000)",
            listOf("hello".encodeToByteArray()),
        ) as ImapResponse.Untagged

        val literal = response.values[2].listValue().attribute("BODY[]")
        assertEquals("hello", literal?.literalValue()?.decodeToString())
    }

    @Test
    fun `parses Gmail SELECT status response codes in square brackets`() {
        val response = ImapResponseParser.parse(
            "* OK [UIDVALIDITY 12345] UIDs valid",
            emptyList(),
        ) as ImapResponse.Untagged

        val responseCode = response.values[1].listValue()
        assertEquals("UIDVALIDITY", responseCode[0].atomValue())
        assertEquals("12345", responseCode.attribute("UIDVALIDITY")?.atomValue())
        assertEquals("UIDs", response.values[2].atomValue())
    }

    @Test
    fun `missing response attribute does not return the first value`() {
        val values = listOf(ImapValue.Atom("UIDVALIDITY"), ImapValue.Atom("12345"))

        assertEquals(null, values.attribute("UIDNEXT"))
    }

    @Test
    fun `keeps spaces and parentheses inside BODY section atoms`() {
        val response = ImapResponseParser.parse(
            "* 1 FETCH (UID 7 BODY[HEADER.FIELDS (DATE FROM)] \u0000L0\u0000)",
            listOf("x".encodeToByteArray()),
        ) as ImapResponse.Untagged

        val fields = response.values[2].listValue()
        assertEquals("x", fields.attribute("BODY[HEADER.FIELDS (DATE FROM)]")?.literalValue()?.decodeToString())
    }
}
