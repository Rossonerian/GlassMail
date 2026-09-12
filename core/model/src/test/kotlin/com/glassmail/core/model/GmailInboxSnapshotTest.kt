package com.glassmail.core.model

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GmailInboxSnapshotTest {
    private val inbox = ImapSelectedMailbox(uidValidity = 7, uidNext = 401, messageCount = 250)

    @Test fun `empty sparse page still reports more UIDs until its requested boundary reaches uidNext`() {
        val page = GmailInboxSnapshot(emptySet(), emptyList(), inbox, emptyList(), requestedThroughUid = 200)

        assertTrue(page.hasMoreUids)
    }

    @Test fun `last page does not request a continuation`() {
        val page = GmailInboxSnapshot(emptySet(), emptyList(), inbox, emptyList(), requestedThroughUid = 400)

        assertFalse(page.hasMoreUids)
    }
}
