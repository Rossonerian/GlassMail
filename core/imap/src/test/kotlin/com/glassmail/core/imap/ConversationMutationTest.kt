package com.glassmail.core.imap

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test

class ConversationMutationTest {
    private class Script(vararg responses: String) : ImapCommandConnection {
        private val responses = ArrayDeque(responses.toList())
        val commands = mutableListOf<String>()
        override fun readResponse() = ImapResponseParser.parse(responses.removeFirst(), emptyList())
        override fun write(command: String) { commands.add(command) }
        override fun writeLogin(tag: String, email: String, password: CharArray) = error("Unexpected LOGIN")
        override fun writeLiteral(bytes: ByteArray) = error("Unexpected literal")
    }

    private fun conversationScript(vararg completion: String) = Script(
        "* LIST (\\All) \"/\" \"[Google Mail]/Alle Nachrichten\"", "G0001 OK listed",
        "* 3 EXISTS", "* OK [UIDVALIDITY 91] selected", "* OK [UIDNEXT 1000] next", "G0002 OK selected",
        "* SEARCH 9 200 456", "G0003 OK found", *completion,
    )

    @Test fun `archive resolves uncached sent and old members in advertised All Mail and never expunges`() {
        val script = conversationScript("G0004 OK stored", "G0005 OK stored", "G0006 OK stored")
        ImapCommandClient(script).applyThreadMutation("12345678901234567890", "ARCHIVE")
        assertEquals(listOf(
            "G0001 LIST \"\" \"*\"", "G0002 SELECT \"[Google Mail]/Alle Nachrichten\"",
            "G0003 UID SEARCH X-GM-THRID 12345678901234567890",
            "G0004 UID STORE 9 -X-GM-LABELS.SILENT (\\Inbox)",
            "G0005 UID STORE 200 -X-GM-LABELS.SILENT (\\Inbox)",
            "G0006 UID STORE 456 -X-GM-LABELS.SILENT (\\Inbox)",
        ), script.commands)
        assertFalse(script.commands.any { "EXPUNGE" in it || "\\Deleted" in it })
    }

    @Test fun `delete moves every resolved member to Trash without permanent deletion`() {
        val script = conversationScript("G0004 OK stored", "G0005 OK stored", "G0006 OK stored")
        ImapCommandClient(script).applyThreadMutation("123", "DELETE")
        assertEquals(listOf(9L, 200L, 456L).mapIndexed { index, uid ->
            "G000${index + 4} UID STORE $uid +X-GM-LABELS.SILENT (\\Trash)"
        }, script.commands.takeLast(3))
    }

    @Test fun `read unread star and unstar apply explicit intent to every resolved member`() {
        for ((type, flags) in mapOf("MARK_READ" to "+FLAGS.SILENT (\\Seen)", "MARK_UNREAD" to "-FLAGS.SILENT (\\Seen)", "STAR" to "+FLAGS.SILENT (\\Flagged)", "UNSTAR" to "-FLAGS.SILENT (\\Flagged)")) {
            val script = conversationScript("G0004 OK stored", "G0005 OK stored", "G0006 OK stored")
            ImapCommandClient(script).applyThreadMutation("123", type)
            assertEquals(listOf(9L, 200L, 456L).mapIndexed { index, uid -> "G000${index + 4} UID STORE $uid $flags" }, script.commands.takeLast(3))
        }
    }

    @Test fun `empty conversation is acknowledged without a UID command and NO stops later members`() {
        val empty = Script("* LIST (\\All) \"/\" \"[Gmail]/All Mail\"", "G0001 OK listed", "* OK [UIDVALIDITY 1] selected", "* OK [UIDNEXT 1] next", "G0002 OK selected", "* SEARCH", "G0003 OK searched")
        ImapCommandClient(empty).applyThreadMutation("123", "ARCHIVE")
        assertEquals(3, empty.commands.size)
        val rejected = conversationScript("G0004 NO rejected")
        assertThrows(ImapException.Protocol::class.java) { ImapCommandClient(rejected).applyThreadMutation("123", "ARCHIVE") }
        assertEquals(4, rejected.commands.size)
    }

    @Test fun `invalid thread ID is rejected before any commands`() {
        val script = Script()
        assertThrows(ImapException.Protocol::class.java) { ImapCommandClient(script).applyThreadMutation("123\r\nEXPUNGE", "ARCHIVE") }
        assertEquals(emptyList<String>(), script.commands)
    }

    @Test fun `IDLE observes flag changes expunges and arrivals but ignores other responses`() = runBlocking {
        val script = Script("+ idling", "* 1 FETCH (FLAGS (\\Seen))", "* 2 EXPUNGE", "* 3 EXISTS", "* OK keepalive", "* 4 RECENT", "G0001 OK done")
        var changes = 0
        ImapCommandClient(script).idle(60_000L) { changes++ }
        assertEquals(3, changes)
        assertEquals(listOf("G0001 IDLE"), script.commands)
    }
}
