package com.glassmail.domain.mail

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OutgoingMailTest {
    @Test fun `normalizes and validates recipient input`() {
        assertEquals(listOf("a@example.com", "b@example.com"), normalizeAddresses(" a@example.com; b@example.com, a@example.com"))
        assertTrue(validateAddresses(listOf("a@example.com")))
        assertFalse(validateAddresses(listOf("not-an-address")))
    }

    @Test fun `reply all excludes own address and deduplicates`() {
        val headers = ReceivedMailHeaders(
            replyTo = listOf("reply@example.com"),
            to = listOf("me@example.com", "reply@example.com"),
            cc = listOf("copy@example.com"),
        )
        assertEquals(listOf("reply@example.com", "copy@example.com"), replyAllRecipients(headers, "me@example.com"))
    }

    @Test fun `reply and forward preserve prefixes and reference chain`() {
        assertEquals("Re: Status", replySubject("Status"))
        assertEquals("Fwd: Status", forwardSubject("Status"))
        assertEquals(listOf("<old>", "<current>"), referencesForReply("<current>", listOf("<old>")))
    }

    @Test fun `attachment names cannot escape storage`() {
        assertEquals("secret.txt", sanitizeAttachmentName("../../secret.txt"))
        assertEquals("a_b.txt", sanitizeAttachmentName("a:b.txt"))
    }
}
