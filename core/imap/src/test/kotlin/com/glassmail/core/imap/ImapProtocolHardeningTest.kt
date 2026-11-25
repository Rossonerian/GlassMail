package com.glassmail.core.imap

import java.nio.charset.StandardCharsets
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ImapProtocolHardeningTest {
    private data class Frame(
        val line: String,
        val literals: List<ByteArray> = emptyList(),
    )

    private class Script(vararg frames: Frame) : ImapCommandConnection {
        constructor(vararg responses: String) : this(*responses.map { Frame(it) }.toTypedArray())

        private val queue = ArrayDeque(frames.toList())
        val commands = mutableListOf<String>()

        override fun readResponse(): ImapResponse {
            val frame = queue.removeFirst()
            return ImapResponseParser.parse(frame.line, frame.literals)
        }

        override fun write(command: String) {
            commands.add(command)
        }

        override fun writeLogin(tag: String, email: String, password: CharArray) = error("Unexpected LOGIN")

        override fun writeLiteral(bytes: ByteArray) = error("Unexpected literal")
    }

    @Test
    fun `multi-line SEARCH aggregates UIDs across searchOlderUids, deleteDraft, fetchDrafts, and applyThreadMutation`() {
        val olderScript = Script(
            "* SEARCH 10 20",
            "* SEARCH 5 30 150",
            "G0001 OK search complete",
        )
        assertEquals(listOf(5L, 10L, 20L, 30L), ImapCommandClient(olderScript).searchOlderUids(100L))
        assertThrows(ImapException.Protocol::class.java) {
            ImapCommandClient(Script("G0001 OK no search line")).searchOlderUids(100L)
        }

        val deleteDraftScript = Script(
            "* SEARCH 11",
            "* SEARCH 22 33",
            "G0001 OK found",
            "G0002 OK stored",
            "G0003 OK expunged",
        )
        ImapCommandClient(deleteDraftScript).deleteDraft("draft1", setOf("UIDPLUS"))
        assertEquals(
            listOf(
                "G0001 UID SEARCH HEADER MESSAGE-ID \"<draft1@glassmail.local>\"",
                "G0002 UID STORE 11,22,33 +FLAGS.SILENT (\\Deleted)",
                "G0003 UID EXPUNGE 11,22,33",
            ),
            deleteDraftScript.commands,
        )

        val draft1Bytes = "Subject: Draft 1\r\n\r\nBody 1".toByteArray(StandardCharsets.UTF_8)
        val draft2Bytes = "Subject: Draft 2\r\n\r\nBody 2".toByteArray(StandardCharsets.UTF_8)
        val fetchDraftsScript = Script(
            Frame("* SEARCH 10"),
            Frame("* SEARCH 20"),
            Frame("G0001 OK found"),
            Frame("* 1 FETCH (UID 10 INTERNALDATE \"01-Jan-2026 00:00:00 +0000\" BODY[] \u0000L0\u0000)", listOf(draft1Bytes)),
            Frame("* 2 FETCH (UID 20 INTERNALDATE \"02-Jan-2026 00:00:00 +0000\" BODY[] \u0000L0\u0000)", listOf(draft2Bytes)),
            Frame("G0002 OK fetched"),
        )
        val drafts = ImapCommandClient(fetchDraftsScript).fetchDrafts(limit = 10)
        assertEquals(listOf(10L, 20L), drafts.map { it.uid })
        assertEquals(listOf("Draft 1", "Draft 2"), drafts.map { it.subject })

        val threadScript = Script(
            "* LIST (\\All) \"/\" \"[Gmail]/All Mail\"",
            "G0001 OK listed",
            "* OK [UIDVALIDITY 1] v",
            "* OK [UIDNEXT 100] n",
            "G0002 OK selected",
            "* SEARCH 10",
            "* SEARCH 20 30",
            "G0003 OK searched",
            "G0004 OK stored",
            "G0005 OK stored",
            "G0006 OK stored",
        )
        ImapCommandClient(threadScript).applyThreadMutation("999", "ARCHIVE")
        assertEquals(
            listOf(
                "G0004 UID STORE 10 -X-GM-LABELS.SILENT (\\Inbox)",
                "G0005 UID STORE 20 -X-GM-LABELS.SILENT (\\Inbox)",
                "G0006 UID STORE 30 -X-GM-LABELS.SILENT (\\Inbox)",
            ),
            threadScript.commands.takeLast(3),
        )
        assertThrows(ImapException.Protocol::class.java) {
            ImapCommandClient(
                Script(
                    "* LIST (\\All) \"/\" \"[Gmail]/All Mail\"",
                    "G0001 OK listed",
                    "* OK [UIDVALIDITY 1] v",
                    "* OK [UIDNEXT 100] n",
                    "G0002 OK selected",
                    "G0003 OK missing search",
                ),
            ).applyThreadMutation("999", "ARCHIVE")
        }
        assertThrows(ImapException.Protocol::class.java) {
            ImapCommandClient(
                Script(
                    "* LIST (\\All) \"/\" \"[Gmail]/All Mail\"",
                    "G0001 OK listed",
                    "* OK [UIDVALIDITY 1] v",
                    "* OK [UIDNEXT 100] n",
                    "G0002 OK selected",
                    "* SEARCH 10",
                    "* SEARCH baduid",
                    "G0003 OK invalid uid",
                ),
            ).applyThreadMutation("999", "ARCHIVE")
        }
    }

    @Test
    fun `unsolicited FLAGS FETCH frame is skipped and Quoted BODY values are accepted`() {
        val bodyScript = Script(
            "* 1 FETCH (FLAGS (\\Seen))",
            "* 2 FETCH (UID 99 BODY[] \"Content-Type: text/plain\r\n\r\nWrong UID\")",
            "* 3 FETCH (UID 42 BODY[] \"Content-Type: text/plain; charset=utf-8\r\n\r\nQuoted body\")",
            "G0001 OK fetched",
        )
        val parsed = ImapCommandClient(bodyScript).fetchMessageBody(42L)
        assertEquals("Quoted body", parsed.plainText)
        assertEquals(listOf("G0001 UID FETCH 42 (UID BODY.PEEK[])"), bodyScript.commands)

        val partScript = Script(
            "* 1 FETCH (FLAGS (\\Seen))",
            "* 2 FETCH (UID 42 BODY[2.MIME] \"Content-Transfer-Encoding: 7bit\r\n\r\n\")",
            "G0001 OK mime",
            "* 1 FETCH (FLAGS (\\Seen))",
            "* 2 FETCH (UID 42 BODY[2] \"hello-quoted\")",
            "G0002 OK part",
        )
        val partBytes = ImapCommandClient(partScript).fetchBodyPart(42L, "2")
        assertArrayEquals("hello-quoted".toByteArray(StandardCharsets.ISO_8859_1), partBytes)
        assertEquals(
            listOf(
                "G0001 UID FETCH 42 (UID BODY.PEEK[2.MIME])",
                "G0002 UID FETCH 42 (UID BODY.PEEK[2])",
            ),
            partScript.commands,
        )
    }

    @Test
    fun `partId 1 falls back to HEADER FIELDS CONTENT-TRANSFER-ENCODING when 1 MIME is NO or empty and base64 decodes`() {
        val rejectedMimeScript = Script(
            "G0001 NO part mime unavailable",
            "* 1 FETCH (UID 7 BODY[HEADER.FIELDS (CONTENT-TRANSFER-ENCODING)] \"Content-Transfer-Encoding: base64\r\n\r\n\")",
            "G0002 OK headers",
            "* 1 FETCH (UID 7 BODY[1] \"SGVsbG8gV29ybGQ=\")",
            "G0003 OK body",
        )
        val decodedFromNo = ImapCommandClient(rejectedMimeScript).fetchBodyPart(7L, "1")
        assertEquals("Hello World", decodedFromNo.toString(StandardCharsets.UTF_8))
        assertEquals(
            listOf(
                "G0001 UID FETCH 7 (UID BODY.PEEK[1.MIME])",
                "G0002 UID FETCH 7 (UID BODY.PEEK[HEADER.FIELDS (CONTENT-TRANSFER-ENCODING)])",
                "G0003 UID FETCH 7 (UID BODY.PEEK[1])",
            ),
            rejectedMimeScript.commands,
        )

        val emptyMimeScript = Script(
            "* 1 FETCH (UID 7 BODY[1.MIME] \"\")",
            "G0001 OK empty mime",
            "* 1 FETCH (UID 7 BODY[HEADER.FIELDS (CONTENT-TRANSFER-ENCODING)] \"Content-Transfer-Encoding: base64\r\n\r\n\")",
            "G0002 OK headers",
            "* 1 FETCH (UID 7 BODY[1] \"SGVsbG8gV29ybGQ=\")",
            "G0003 OK body",
        )
        val decodedFromEmpty = ImapCommandClient(emptyMimeScript).fetchBodyPart(7L, "1")
        assertEquals("Hello World", decodedFromEmpty.toString(StandardCharsets.UTF_8))
        assertEquals(
            listOf(
                "G0001 UID FETCH 7 (UID BODY.PEEK[1.MIME])",
                "G0002 UID FETCH 7 (UID BODY.PEEK[HEADER.FIELDS (CONTENT-TRANSFER-ENCODING)])",
                "G0003 UID FETCH 7 (UID BODY.PEEK[1])",
            ),
            emptyMimeScript.commands,
        )
    }

    @Test
    fun `selectMailbox and selectInbox throw UidValidityChanged when server UIDVALIDITY mismatches expected`() {
        val mailboxScript = Script(
            "* 5 EXISTS",
            "* OK [UIDVALIDITY 11] uidvalidity",
            "* OK [UIDNEXT 20] uidnext",
            "G0001 OK [READ-WRITE] selected",
        )
        val mailboxError = assertThrows(ImapException.UidValidityChanged::class.java) {
            ImapCommandClient(mailboxScript).selectMailbox("INBOX", expectedUidValidity = 10L)
        }
        assertEquals(10L, mailboxError.expected)
        assertEquals(11L, mailboxError.actual)

        val inboxScript = Script(
            "* 5 EXISTS",
            "* OK [UIDVALIDITY 11] uidvalidity",
            "* OK [UIDNEXT 20] uidnext",
            "G0001 OK [READ-WRITE] selected",
        )
        val inboxError = assertThrows(ImapException.UidValidityChanged::class.java) {
            ImapCommandClient(inboxScript).selectInbox(expectedUidValidity = 10L)
        }
        assertEquals(10L, inboxError.expected)
        assertEquals(11L, inboxError.actual)

        val matchingScript = Script(
            "* 5 EXISTS",
            "* OK [UIDVALIDITY 11] uidvalidity",
            "* OK [UIDNEXT 20] uidnext",
            "G0001 OK [READ-WRITE] selected",
        )
        val selected = ImapCommandClient(matchingScript).selectInbox(expectedUidValidity = 11L)
        assertEquals(11L, selected.uidValidity)
        assertEquals(20L, selected.uidNext)
        assertEquals(5, selected.messageCount)
    }
}
