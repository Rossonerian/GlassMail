package com.glassmail.core.database

import android.database.sqlite.SQLiteException
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class GlassMailDatabaseInstrumentedTest {
    private val db = Room.inMemoryDatabaseBuilder(
        ApplicationProvider.getApplicationContext(), GlassMailDatabase::class.java,
    ).allowMainThreadQueries().build()

    @After fun close() = db.close()

    @Test fun accountMailboxMessageAndFlowAreDurableAndUnique() = runBlocking {
        db.accountDao().upsert(AccountEntity("a", "a@example.test", 1, "READY"))
        db.mailDao().upsertMailboxes(listOf(MailboxEntity("a:INBOX", "a", "INBOX", 7, 2, 1)))
        db.mailDao().upsertMessages(listOf(MessageEntity("gmail:a:1", "a", "1", "t", "Subject", "Sender", 1, 1, preview = "preview")))
        db.mailDao().upsertMailboxMessages(listOf(MailboxMessageEntity("a:INBOX", 1, "gmail:a:1", "", "INBOX")))
        db.mailDao().upsertMailboxMessages(listOf(MailboxMessageEntity("a:INBOX", 1, "gmail:a:1", "\\Seen", "INBOX")))
        val rows = db.mailDao().observeInbox("a:INBOX").first()
        assertEquals(1, rows.size)
        assertEquals("\\Seen", rows.single().flags)
    }

    @Test fun threadQueryReturnsCachedMessagesWithTheSameGmailThreadId() = runBlocking {
        db.accountDao().upsert(AccountEntity("a", "a@example.test", 1, "READY"))
        db.mailDao().upsertMailboxes(listOf(MailboxEntity("a:INBOX", "a", "INBOX", 7, 3, 2)))
        db.mailDao().upsertMessages(
            listOf(
                MessageEntity("m1", "a", "1", "thread", "First", "Sender", 1, 1),
                MessageEntity("m2", "a", "2", "thread", "Second", "Sender", 2, 1),
                MessageEntity("m3", "a", "3", "other", "Other", "Sender", 3, 1),
            ),
        )
        db.mailDao().upsertMailboxMessages(
            listOf(
                MailboxMessageEntity("a:INBOX", 1, "m1", "", "INBOX"),
                MailboxMessageEntity("a:INBOX", 2, "m2", "", "INBOX"),
                MailboxMessageEntity("a:INBOX", 3, "m3", "", "INBOX"),
            ),
        )

        assertEquals(listOf("m1", "m2"), db.mailDao().observeThread("m1").first().map { it.messageId })
    }

    @Test fun checkpointAndPendingMutationPersist() = runBlocking {
        db.accountDao().upsert(AccountEntity("a", "a@example.test", 1, "READY"))
        db.mailDao().upsertMailboxes(listOf(MailboxEntity("a:INBOX", "a", "INBOX", 7, 2, 1)))
        db.mailDao().upsertMessages(listOf(MessageEntity("m", "a", null, null, null, null, null, null)))
        db.syncDao().upsertCheckpoint(SyncCheckpointEntity("a:INBOX", "a", 7, 1, 1, 2))
        db.pendingMutationDao().insert(PendingMutationEntity("p", "a", "a:INBOX", "m", 1, "MARK_READ", null, createdAtEpochMillis = 1))
        assertEquals(1L, db.syncDao().checkpoint("a:INBOX")?.highestKnownUid)
        assertNotNull(db.pendingMutationDao().activeForAccount("a").singleOrNull())
    }

    @Test fun threadQueryDoesNotMixAccountsWithTheSameGmailThreadId() = runBlocking {
        db.accountDao().upsert(AccountEntity("a", "a@example.test", 1, "READY"))
        db.accountDao().upsert(AccountEntity("b", "b@example.test", 2, "READY"))
        db.mailDao().upsertMailboxes(listOf(
            MailboxEntity("a:INBOX", "a", "INBOX", 7, 3, 2),
            MailboxEntity("b:INBOX", "b", "INBOX", 7, 2, 1),
        ))
        db.mailDao().upsertMessages(listOf(
            MessageEntity("a1", "a", "1", "shared", "First", "Sender", 1, 1),
            MessageEntity("a2", "a", "2", "shared", "Second", "Sender", 2, 1),
            MessageEntity("b1", "b", "1", "shared", "Foreign", "Sender", 3, 1),
        ))
        db.mailDao().upsertMailboxMessages(listOf(
            MailboxMessageEntity("a:INBOX", 1, "a1", "", "INBOX"),
            MailboxMessageEntity("a:INBOX", 2, "a2", "", "INBOX"),
            MailboxMessageEntity("b:INBOX", 1, "b1", "", "INBOX"),
        ))
        assertEquals(listOf("a1", "a2"), db.mailDao().observeThread("a1").first().map { it.messageId })
        assertEquals(listOf("b1"), db.mailDao().observeThread("b1").first().map { it.messageId })
        assertTrue(db.mailDao().observeThread("missing").first().isEmpty())
    }

    @Test fun threadQueryKeepsNullAndEmptyThreadIdsAsSingleMessages() = runBlocking {
        db.accountDao().upsert(AccountEntity("a", "a@example.test", 1, "READY"))
        db.mailDao().upsertMailboxes(listOf(MailboxEntity("a:INBOX", "a", "INBOX", 7, 5, 4)))
        db.mailDao().upsertMessages(listOf(
            MessageEntity("null1", "a", "1", null, "First", "Sender", 1, 1),
            MessageEntity("null2", "a", "2", null, "Second", "Sender", 2, 1),
            MessageEntity("empty1", "a", "3", "", "Third", "Sender", 3, 1),
            MessageEntity("empty2", "a", "4", "", "Fourth", "Sender", 4, 1),
        ))
        db.mailDao().upsertMailboxMessages(listOf("null1", "null2", "empty1", "empty2").mapIndexed { index, id ->
            MailboxMessageEntity("a:INBOX", index.toLong() + 1, id, "", "INBOX")
        })
        assertEquals(listOf("null1"), db.mailDao().observeThread("null1").first().map { it.messageId })
        assertEquals(listOf("empty1"), db.mailDao().observeThread("empty1").first().map { it.messageId })
    }

    @Test fun searchExpandsThreadsWithinTheSameAccountIncludingMatchesOutsideInbox() = runBlocking {
        db.accountDao().upsert(AccountEntity("a", "a@example.test", 1, "READY"))
        db.accountDao().upsert(AccountEntity("b", "b@example.test", 2, "READY"))
        db.mailDao().upsertMailboxes(listOf(
            MailboxEntity("a:INBOX", "a", "INBOX", 7, 3, 2),
            MailboxEntity("a:Archive", "a", "Archive", 7, 2, 1),
            MailboxEntity("b:INBOX", "b", "INBOX", 7, 2, 1),
        ))
        db.mailDao().upsertMessages(listOf(
            MessageEntity("a1", "a", "1", "shared", "Ordinary", "Sender", 1, 1),
            MessageEntity("a2", "a", "2", "shared", "Threadneedle", "Sender", 2, 1),
            MessageEntity("a3", "a", "3", null, "Directneedle", "Sender", 3, 1),
            MessageEntity("b1", "b", "1", "shared", "Foreignneedle", "Sender", 4, 1),
        ))
        db.mailDao().upsertMailboxMessages(listOf(
            MailboxMessageEntity("a:INBOX", 1, "a1", "", "INBOX"),
            MailboxMessageEntity("a:Archive", 1, "a2", "", "Archive"),
            MailboxMessageEntity("a:INBOX", 2, "a3", "", "INBOX"),
            MailboxMessageEntity("b:INBOX", 1, "b1", "", "INBOX"),
        ))
        assertTrue(db.mailDao().search("a:INBOX", "Foreignneedle").first().isEmpty())
        assertEquals(listOf("a1"), db.mailDao().search("a:INBOX", "Threadneedle").first().map { it.messageId })
        assertEquals(listOf("a3"), db.mailDao().search("a:INBOX", "Directneedle").first().map { it.messageId })
        assertEquals(listOf("b1"), db.mailDao().search("b:INBOX", "Foreignneedle").first().map { it.messageId })
        assertTrue(db.mailDao().search("b:INBOX", "Threadneedle").first().isEmpty())
    }

    @Test fun accountDeletionRemovesAllAccountRowsAndPreservesOtherAccounts() = runBlocking {
        val sqlite = db.openHelper.writableDatabase
        HistoricalRows.insert(sqlite, 10, "a")
        HistoricalRows.insert(sqlite, 10, "b")

        db.accountDao().deleteWithAccountData("a")

        HistoricalRows.assertAbsent(sqlite, "a")
        HistoricalRows.assertSurvive(sqlite, 10, "b")
        assertTrue(ftsMessageIds(sqlite, "Migrationneedle").isEmpty())
        assertEquals(listOf("b:message"), ftsMessageIds(sqlite, "Other"))
    }

    @Test fun accountDeletionRollsBackEveryTableWhenTheAccountDeleteFails() = runBlocking {
        val sqlite = db.openHelper.writableDatabase
        HistoricalRows.insert(sqlite, 10)
        sqlite.execSQL("CREATE TRIGGER reject_account_delete BEFORE DELETE ON accounts " +
            "WHEN OLD.accountId = 'a' BEGIN SELECT RAISE(ABORT, 'test failure'); END")

        var rejected = false
        try {
            db.accountDao().deleteWithAccountData("a")
        } catch (_: SQLiteException) {
            rejected = true
        }
        assertTrue("The injected delete failure must be reached", rejected)
        HistoricalRows.assertSurvive(sqlite, 10)
        assertEquals(listOf("a:message"), ftsMessageIds(sqlite, "Migrationneedle"))
    }
}
