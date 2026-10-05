package com.glassmail.core.imap

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class InboxMutationUidValidityTest {
    private val operations = listOf("ARCHIVE", "DELETE", "MARK_READ", "STAR").map { ImapMutation(7, it) }

    @Test fun `mismatched SELECT validity sends no mutation commands`() {
        val sent = mutableListOf<ImapMutation>()
        val error = assertThrows(ImapException.UidValidityChanged::class.java) {
            applySelectedInboxMutations(22, 11, operations) { sent.add(it) }
        }
        assertEquals(11L, error.expected)
        assertEquals(22L, error.actual)
        assertTrue(sent.isEmpty())
    }

    @Test fun `matching SELECT validity sends all mutation commands`() {
        val sent = mutableListOf<ImapMutation>()
        applySelectedInboxMutations(11, 11, operations) { sent.add(it) }
        assertEquals(operations, sent)
    }

    @Test fun `null expected validity is supported for callers without captured UIDs`() {
        val sent = mutableListOf<ImapMutation>()
        applySelectedInboxMutations(22, null, operations) { sent.add(it) }
        assertEquals(operations, sent)
    }
}
