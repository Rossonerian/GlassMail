package com.glassmail.core.database

import android.content.Context
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class GlassMailMigrationInstrumentedTest {
    private val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
    private val databaseNames = mutableListOf<String>()

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        GlassMailDatabase::class.java,
    )

    private val migrations: Array<Migration> = arrayOf(
        GlassMailDatabase.MIGRATION_1_2,
        GlassMailDatabase.MIGRATION_2_3,
        GlassMailDatabase.MIGRATION_3_4,
        GlassMailDatabase.MIGRATION_4_5,
        GlassMailDatabase.MIGRATION_5_6,
        GlassMailDatabase.MIGRATION_6_7,
        GlassMailDatabase.MIGRATION_7_8,
        GlassMailDatabase.MIGRATION_8_9,
        GlassMailDatabase.MIGRATION_9_10,
    )

    @After
    fun deleteDatabases() {
        databaseNames.forEach { context.deleteDatabase(it) }
    }

    @Test fun migrationOneToTwo() = validateStep(1)
    @Test fun migrationTwoToThree() = validateStep(2)
    @Test fun migrationThreeToFourAddsMessagePresentationColumns() = validateStep(3)
    @Test fun migrationFourToFive() = validateStep(4)
    @Test fun migrationFiveToSix() = validateStep(5)
    @Test fun migrationSixToSeven() = validateStep(6)
    @Test fun migrationSevenToEightRebuildsFts() = validateStep(7)
    @Test fun migrationEightToNine() = validateStep(8)
    @Test fun migrationNineToTen() = validateStep(9)

    @Test fun fullOneToTenUpgradeThroughRoomPreservesData() = validateFullUpgrade(1)
    @Test fun fullSevenToTenUpgradeThroughRoomPreservesData() = validateFullUpgrade(7)

    @Test
    fun freshVersionTenDatabase() {
        val name = databaseName("fresh")
        withRoom(name) { room ->
            val sqlite = room.openHelper.writableDatabase
            assertEquals(10, sqlite.version)
            HistoricalRows.insert(sqlite, 10)
            HistoricalRows.assertSurvive(sqlite, 10)
            assertFtsFindsMessage(sqlite)
            assertNoForeignKeyViolations(sqlite)
        }
        // Validate Room's actual fresh schema against the exported v10 schema as well.
        helper.runMigrationsAndValidate(name, 10, true).use { sqlite ->
            HistoricalRows.assertSurvive(sqlite, 10)
            assertFtsFindsMessage(sqlite)
        }
        withRoom(name) { room ->
            HistoricalRows.assertSurvive(room.openHelper.writableDatabase, 10)
        }
    }

    private fun validateStep(from: Int) {
        val name = databaseName("step-$from")
        helper.createDatabase(name, from).use { sqlite ->
            HistoricalRows.insert(sqlite, from)
        }
        helper.runMigrationsAndValidate(name, from + 1, true, migrations[from - 1]).use { sqlite ->
            HistoricalRows.assertSurvive(sqlite, from)
            assertAddedColumns(sqlite, from)
            assertNoForeignKeyViolations(sqlite)
            if (from == 7) assertFtsFindsMessage(sqlite)
        }
    }

    private fun validateFullUpgrade(from: Int) {
        val name = databaseName("full-$from")
        helper.createDatabase(name, from).use { sqlite ->
            HistoricalRows.insert(sqlite, from)
        }
        // Open the old file using the same Room builder and migrations as production.
        // This exercises generated validation and FTS trigger installation, too.
        withRoom(name) { room ->
            val sqlite = room.openHelper.writableDatabase
            assertEquals(10, sqlite.version)
            HistoricalRows.assertSurvive(sqlite, from)
            assertFtsFindsMessage(sqlite)
            assertNoForeignKeyViolations(sqlite)
            // v1 has no label, attachment, draft, mutation or notification tables.
            // Exercise those newly created tables after the full upgrade and reopen.
            HistoricalRows.insert(sqlite, 10, "new")
            HistoricalRows.assertSurvive(sqlite, 10, "new")
            sqlite.execSQL("UPDATE messages SET subject = 'Updatedneedle' WHERE messageId = 'a:message'")
            assertEquals(listOf("a:message"), ftsMessageIds(sqlite, "Updatedneedle"))
            assertTrue(ftsMessageIds(sqlite, "Migrationneedle").isEmpty())
        }
        helper.runMigrationsAndValidate(name, 10, true).close()
        withRoom(name) { room ->
            val sqlite = room.openHelper.writableDatabase
            HistoricalRows.assertSurvive(sqlite, 10, "new")
            assertEquals(listOf("a:message"), ftsMessageIds(sqlite, "Updatedneedle"))
            assertNoForeignKeyViolations(sqlite)
        }
    }

    private fun withRoom(name: String, block: (GlassMailDatabase) -> Unit) {
        val room = Room.databaseBuilder(context, GlassMailDatabase::class.java, name)
            .addMigrations(*migrations).build()
        try {
            block(room)
        } finally {
            room.close()
        }
    }

    private fun databaseName(suffix: String): String =
        "glassmail-migration-$suffix-${System.nanoTime()}.db".also { databaseNames.add(it) }

    private fun assertAddedColumns(sqlite: SupportSQLiteDatabase, from: Int) {
        when (from) {
            1 -> assertCell(sqlite, "messages", "bodyDownloadState", "NOT_FETCHED")
            2 -> assertCell(sqlite, "pending_mutations", "targetUid", null)
            3 -> {
                assertCell(sqlite, "messages", "preview", null)
                assertCell(sqlite, "messages", "body", null)
                assertCell(sqlite, "messages", "contentKind", "PLAIN")
            }
            4 -> assertCell(sqlite, "drafts", "COUNT(*)", 0L)
            5 -> assertCell(sqlite, "drafts", "attachments", "")
            6 -> assertCell(sqlite, "notification_state", "COUNT(*)", 0L)
            7 -> assertCell(sqlite, "messages", "category", "PRIMARY")
            8 -> {
                assertCell(sqlite, "attachments", "lastAccessedAtEpochMillis", 0L)
                assertCell(sqlite, "messages", "listUnsubscribe", null)
                assertCell(sqlite, "messages", "listUnsubscribePost", null)
                assertCell(sqlite, "cache_config", "COUNT(*)", 0L)
                assertCell(sqlite, "storage_quota", "COUNT(*)", 0L)
            }
            9 -> {
                assertCell(sqlite, "pending_mutations", "previousFlags", "")
                assertCell(sqlite, "pending_mutations", "previousLabels", "")
            }
        }
    }

    private fun assertCell(sqlite: SupportSQLiteDatabase, table: String, expression: String, expected: Any?) {
        sqlite.query("SELECT $expression FROM `$table`").use { cursor ->
            assertTrue(cursor.moveToFirst())
            val actual = when (expected) {
                null -> { assertTrue(cursor.isNull(0)); null }
                is Long -> cursor.getLong(0)
                else -> cursor.getString(0)
            }
            assertEquals("$table.$expression", expected, actual)
            assertFalse(cursor.moveToNext())
        }
    }

    private fun assertFtsFindsMessage(sqlite: SupportSQLiteDatabase) {
        assertEquals(listOf("a:message"), ftsMessageIds(sqlite, "Migrationneedle"))
        // unicode61 must keep the exported tokenizer's accent folding behavior.
        assertEquals(listOf("a:message"), ftsMessageIds(sqlite, "cafe"))
    }

    private fun assertNoForeignKeyViolations(sqlite: SupportSQLiteDatabase) {
        sqlite.query("PRAGMA foreign_key_check").use { assertFalse(it.moveToFirst()) }
    }
}

internal fun ftsMessageIds(sqlite: SupportSQLiteDatabase, query: String): List<String> = sqlite.query(
    "SELECT m.messageId FROM messages_fts JOIN messages m ON m.rowid = messages_fts.rowid " +
        "WHERE messages_fts MATCH ? ORDER BY m.messageId",
    arrayOf<Any>(query),
).use { cursor -> buildList { while (cursor.moveToNext()) add(cursor.getString(0)) } }

/** Explicit old-schema SQL fixtures: only columns and tables available in that version. */
internal object HistoricalRows {
    private data class Row(val table: String, val values: Map<String, Any?>)

    fun insert(sqlite: SupportSQLiteDatabase, version: Int, accountId: String = "a") {
        rows(version, accountId).forEach { row ->
            val columns = row.values.keys.joinToString(", ") { "`$it`" }
            val placeholders = row.values.keys.joinToString(", ") { "?" }
            sqlite.execSQL("INSERT INTO `${row.table}` ($columns) VALUES ($placeholders)", row.values.values.toTypedArray())
        }
    }

    fun assertSurvive(sqlite: SupportSQLiteDatabase, version: Int, accountId: String = "a") {
        rows(version, accountId).forEach { row ->
            val key = row.values.entries.first()
            sqlite.query("SELECT * FROM `${row.table}` WHERE `${key.key}` = ?", arrayOf<Any>(key.value!!)).use { cursor ->
                assertTrue("Missing ${row.table} for $accountId", cursor.moveToFirst())
                row.values.forEach { (column, expected) ->
                    val index = cursor.getColumnIndexOrThrow(column)
                    val actual = when (expected) {
                        null -> { assertTrue("${row.table}.$column", cursor.isNull(index)); null }
                        is Number -> cursor.getLong(index)
                        else -> cursor.getString(index)
                    }
                    assertEquals("${row.table}.$column", expected, actual)
                }
                assertFalse("Duplicate fixture in ${row.table}", cursor.moveToNext())
            }
        }
    }

    fun assertAbsent(sqlite: SupportSQLiteDatabase, accountId: String) {
        rows(10, accountId).forEach { row ->
            val key = row.values.entries.first()
            sqlite.query("SELECT * FROM `${row.table}` WHERE `${key.key}` = ?", arrayOf<Any>(key.value!!)).use { cursor ->
                assertFalse("Leftover ${row.table} for $accountId", cursor.moveToFirst())
            }
        }
    }

    private fun rows(version: Int, accountId: String): List<Row> = buildList {
        val messageId = "$accountId:message"
        val mailboxId = "$accountId:INBOX"
        add(Row("accounts", linkedMapOf(
            "accountId" to accountId, "email" to "$accountId@example.test", "createdAtEpochMillis" to 100L,
            "syncState" to "READY", "gmailExtensionsEnabled" to 1L, "lastSyncedAtEpochMillis" to 200L,
        )))
        add(Row("mailboxes", linkedMapOf(
            "mailboxId" to mailboxId, "accountId" to accountId, "remoteName" to "INBOX",
            "uidValidity" to 7L, "uidNext" to 43L, "messageCount" to 1L,
        )))
        add(Row("messages", linkedMapOf<String, Any?>(
            "messageId" to messageId, "accountId" to accountId, "gmailMessageId" to "gmail-42",
            "gmailThreadId" to "thread-42", "subject" to if (accountId == "a") "Migrationneedle café" else "Other subject",
            "sender" to "sender@example.test", "sentAtEpochMillis" to 123L, "sizeBytes" to 456L,
        ).apply {
            if (version >= 2) put("bodyDownloadState", "AVAILABLE")
            if (version >= 4) {
                put("preview", "Previewneedle"); put("body", "Bodysentinel"); put("contentKind", "HTML")
            }
            if (version >= 8) put("category", "SOCIAL")
            if (version >= 9) {
                put("listUnsubscribe", "<mailto:unsubscribe@example.test>")
                put("listUnsubscribePost", "List-Unsubscribe=One-Click")
            }
        }))
        add(Row("mailbox_messages", linkedMapOf(
            "mailboxId" to mailboxId, "uid" to 42L, "messageId" to messageId,
            "flags" to "\\Seen", "labels" to "INBOX Travel",
        )))
        if (version >= 2) {
            add(Row("message_labels", linkedMapOf("messageId" to messageId, "label" to "Travel")))
            add(Row("attachments", linkedMapOf<String, Any?>(
                "attachmentId" to "$accountId:attachment", "messageId" to messageId, "partId" to "1.2",
                "fileName" to "ticket.pdf", "mimeType" to "application/pdf", "sizeBytes" to 4096L,
                "downloadState" to "AVAILABLE",
            ).apply { if (version >= 9) put("lastAccessedAtEpochMillis", 333L) }))
            add(Row("pending_mutations", linkedMapOf<String, Any?>(
                "mutationId" to "$accountId:mutation", "accountId" to accountId, "mailboxId" to mailboxId,
                "messageId" to messageId, "type" to "MARK_READ", "payload" to "true", "state" to "PENDING",
                "retryCount" to 2L, "createdAtEpochMillis" to 222L, "lastErrorCode" to null,
            ).apply {
                if (version >= 3) put("targetUid", 42L)
                if (version >= 10) { put("previousFlags", "\\Flagged"); put("previousLabels", "INBOX") }
            }))
            add(Row("sync_checkpoints", linkedMapOf(
                "mailboxId" to mailboxId, "accountId" to accountId, "uidValidity" to 7L,
                "highestKnownUid" to 42L, "syncGeneration" to 3L, "lastSuccessfulSyncEpochMillis" to 234L,
            )))
        }
        if (version >= 5) {
            add(Row("drafts", linkedMapOf<String, Any?>(
                "draftId" to "$accountId:draft", "accountId" to accountId, "toAddresses" to "to@example.test",
                "ccAddresses" to "", "bccAddresses" to "", "subject" to "Draft subject", "body" to "Draft body",
                "inReplyTo" to "<message@example.test>", "references" to "<reference@example.test>",
                "status" to "DRAFT", "updatedAtEpochMillis" to 345L,
            ).apply { if (version >= 6) put("attachments", "draft-attachment") }))
        }
        if (version >= 7) {
            add(Row("notification_state", linkedMapOf("accountId" to accountId, "baselineEstablished" to 1L)))
        }
        if (version >= 9) {
            add(Row("cache_config", linkedMapOf(
                "accountId" to accountId, "offlineMessageCount" to 100L, "attachmentCacheLimitMb" to 250L,
                "autoEvictReadOlderThanDays" to 30L, "prefetchUnreadBodies" to 0L,
            )))
            add(Row("storage_quota", linkedMapOf(
                "accountId" to accountId, "usedKb" to 1234L, "limitKb" to 9876L, "checkedAtEpochMillis" to 456L,
            )))
        }
    }
}
