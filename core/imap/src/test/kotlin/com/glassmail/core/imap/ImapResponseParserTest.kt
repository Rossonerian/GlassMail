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
    fun `parses a literal without treating it as an atom`() {
        val response = ImapResponseParser.parse(
            "* 1 FETCH (BODY[] \u0000L0\u0000)",
            listOf("hello".encodeToByteArray()),
        ) as ImapResponse.Untagged

        val literal = response.values[2].listValue().attribute("BODY[]")
        assertEquals("hello", literal?.literalValue()?.decodeToString())
    }
}
