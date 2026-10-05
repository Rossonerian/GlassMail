package com.glassmail.core.imap

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ImapDatesTest {
    private fun utc(text: String) = Instant.parse(text).toEpochMilli()

    @Test fun `header with trailing zone comment from JavaMail parses`() {
        assertEquals(utc("2026-10-05T15:21:00Z"), ImapDates.header("Mon, 5 Oct 2026 20:51:00 +0530 (IST)"))
    }

    @Test fun `header without weekday and with obsolete zone names parses`() {
        assertEquals(utc("2026-10-05T15:21:00Z"), ImapDates.header("5 Oct 2026 15:21:00 GMT"))
        assertEquals(utc("2026-10-05T20:21:00Z"), ImapDates.header("Mon, 05 Oct 2026 15:21:00 -0500"))
        assertEquals(utc("2026-01-05T20:21:00Z"), ImapDates.header("Mon, 5 Jan 2026 15:21 EST"))
    }

    @Test fun `header tolerates extra whitespace and two digit years`() {
        assertEquals(utc("2026-10-05T15:21:07Z"), ImapDates.header("Mon,  5  Oct  26 15:21:07 +0000"))
    }

    @Test fun `unparseable or missing headers yield null so the caller can fall back`() {
        assertNull(ImapDates.header(null))
        assertNull(ImapDates.header("yesterday-ish"))
        assertNull(ImapDates.header("Mon, 5 Oct 2026 15:21:00 +0000 (unterminated"))
    }

    @Test fun `internal date format used by FETCH parses including single digit day`() {
        assertEquals(utc("2026-10-05T15:21:04Z"), ImapDates.internalDate("05-Oct-2026 15:21:04 +0000"))
        assertEquals(utc("2026-10-05T09:51:04Z"), ImapDates.internalDate(" 5-Oct-2026 15:21:04 +0530"))
    }
}
