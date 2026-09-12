package com.glassmail.core.database

import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
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
        assertEquals(1, db.syncDao().checkpoint("a:INBOX")?.highestKnownUid)
        assertNotNull(db.pendingMutationDao().activeForAccount("a").singleOrNull())
    }

    @Test fun migrationThreeToFourAddsMessagePresentationColumns() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val helper = FrameworkSQLiteOpenHelperFactory().create(
            SupportSQLiteOpenHelper.Configuration.builder(context)
                .name("migration-test-${System.nanoTime()}")
                .callback(object : SupportSQLiteOpenHelper.Callback(3) {
                    override fun onCreate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                        database.execSQL(
                            "CREATE TABLE messages (messageId TEXT NOT NULL, accountId TEXT NOT NULL, gmailMessageId TEXT, gmailThreadId TEXT, subject TEXT, sender TEXT, sentAtEpochMillis INTEGER, sizeBytes INTEGER, bodyDownloadState TEXT NOT NULL, PRIMARY KEY(messageId))",
                        )
                    }

                    override fun onUpgrade(database: androidx.sqlite.db.SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
                }).build(),
        )
        val sqlite = helper.writableDatabase
        GlassMailDatabase.MIGRATION_3_4.migrate(sqlite)

        val columns = sqlite.query("PRAGMA table_info(messages)").use { cursor ->
            buildSet { while (cursor.moveToNext()) add(cursor.getString(cursor.getColumnIndexOrThrow("name"))) }
        }
        assertEquals(setOf("preview", "body", "contentKind"), columns.intersect(setOf("preview", "body", "contentKind")))
        helper.close()
    }
}
