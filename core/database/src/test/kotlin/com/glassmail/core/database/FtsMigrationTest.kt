package com.glassmail.core.database

import androidx.room.util.FtsTableInfo
import androidx.sqlite.db.SupportSQLiteDatabase
import java.lang.reflect.Proxy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class FtsMigrationTest {
    @Test
    fun sevenToEightFtsSqlExactlyMatchesExportedSchemasAndRoomMetadata() {
        val statements = mutableListOf<String>()
        // This migration only executes SQL. Record it without invoking Android APIs.
        val database = Proxy.newProxyInstance(
            SupportSQLiteDatabase::class.java.classLoader,
            arrayOf(SupportSQLiteDatabase::class.java),
        ) { _, method, args ->
            check(method.name == "execSQL") { "Unexpected database call: ${method.name}" }
            statements.add(args!![0] as String)
            null
        } as SupportSQLiteDatabase
        GlassMailDatabase.MIGRATION_7_8.migrate(database)
        val actualSql = statements.single { it.startsWith("CREATE VIRTUAL TABLE") }
        val columns = setOf("subject", "sender", "preview", "body")
        for (version in listOf(8, 10)) {
            val resource = checkNotNull(javaClass.classLoader!!.getResourceAsStream(
                "com.glassmail.core.database.GlassMailDatabase/$version.json",
            )) { "Missing exported schema $version" }
            val json = resource.bufferedReader().use { it.readText() }
            val expectedSql = checkNotNull(
                Regex("\"createSql\"\\s*:\\s*\"(CREATE VIRTUAL TABLE[^\"]*)\"").find(json),
            ).groupValues[1].replace("\${TABLE_NAME}", "messages_fts")
            assertEquals("Exported schema $version", expectedSql, actualSql)
            val expectedInfo = FtsTableInfo("messages_fts", columns, expectedSql)
            assertEquals(expectedInfo, FtsTableInfo("messages_fts", columns, actualSql))
            // Guard against the original failure: Room compares content options literally.
            assertNotEquals(expectedInfo, FtsTableInfo(
                "messages_fts", columns, actualSql.replace("content=`messages`", "content='messages'"),
            ))
        }
    }
}
