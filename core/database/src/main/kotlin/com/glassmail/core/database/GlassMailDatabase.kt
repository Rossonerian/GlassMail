package com.glassmail.core.database

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Fts4
import androidx.room.FtsOptions
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.ColumnInfo
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Upsert
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "accounts", indices = [Index(value = ["email"], unique = true)])
data class AccountEntity(
    @PrimaryKey val accountId: String,
    val email: String,
    val createdAtEpochMillis: Long,
    val syncState: String,
    val gmailExtensionsEnabled: Boolean = false,
    val lastSyncedAtEpochMillis: Long? = null,
)

@Entity(
    tableName = "mailboxes",
    foreignKeys = [ForeignKey(entity = AccountEntity::class, parentColumns = ["accountId"], childColumns = ["accountId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index(value = ["accountId", "remoteName"], unique = true)],
)
data class MailboxEntity(
    @PrimaryKey val mailboxId: String,
    val accountId: String,
    val remoteName: String,
    val uidValidity: Long,
    val uidNext: Long,
    val messageCount: Int,
)

@Entity(
    tableName = "messages",
    foreignKeys = [ForeignKey(entity = AccountEntity::class, parentColumns = ["accountId"], childColumns = ["accountId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index(value = ["accountId", "gmailMessageId"], unique = true), Index(value = ["accountId", "gmailThreadId"]), Index(value = ["accountId", "category"])],
)
data class MessageEntity(
    @PrimaryKey val messageId: String,
    val accountId: String,
    val gmailMessageId: String?,
    val gmailThreadId: String?,
    val subject: String?,
    val sender: String?,
    val sentAtEpochMillis: Long?,
    val sizeBytes: Long?,
    @ColumnInfo(defaultValue = "'PRIMARY'") val category: String = "PRIMARY",
    val preview: String? = null,
    val body: String? = null,
    val contentKind: String = "PLAIN",
    val bodyDownloadState: String = DownloadState.NOT_FETCHED,
    val listUnsubscribe: String? = null,
    val listUnsubscribePost: String? = null,
)

@Fts4(contentEntity = MessageEntity::class, tokenizer = FtsOptions.TOKENIZER_UNICODE61)
@Entity(tableName = "messages_fts")
data class MessageFtsEntity(
    val subject: String?,
    val sender: String?,
    val preview: String?,
    val body: String?,
)

@Entity(
    tableName = "mailbox_messages",
    primaryKeys = ["mailboxId", "uid"],
    foreignKeys = [
        ForeignKey(entity = MailboxEntity::class, parentColumns = ["mailboxId"], childColumns = ["mailboxId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = MessageEntity::class, parentColumns = ["messageId"], childColumns = ["messageId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index(value = ["messageId"]), Index(value = ["mailboxId", "uid"], unique = true)],
)
data class MailboxMessageEntity(
    val mailboxId: String,
    val uid: Long,
    val messageId: String,
    val flags: String,
    val labels: String,
)

object DownloadState {
    const val NOT_FETCHED = "NOT_FETCHED"
    const val FETCHING = "FETCHING"
    const val AVAILABLE = "AVAILABLE"
    const val FAILED = "FAILED"
}

object MutationState {
    const val PENDING = "PENDING"
    const val IN_FLIGHT = "IN_FLIGHT"
    const val ACKNOWLEDGED = "ACKNOWLEDGED"
    const val FAILED_PERMANENT = "FAILED_PERMANENT"
}

@Entity(
    tableName = "message_labels",
    primaryKeys = ["messageId", "label"],
    foreignKeys = [ForeignKey(entity = MessageEntity::class, parentColumns = ["messageId"], childColumns = ["messageId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index(value = ["label"])],
)
data class MessageLabelEntity(
    val messageId: String,
    val label: String,
)

@Entity(
    tableName = "attachments",
    foreignKeys = [ForeignKey(entity = MessageEntity::class, parentColumns = ["messageId"], childColumns = ["messageId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index(value = ["messageId"]), Index(value = ["downloadState"])],
)
data class AttachmentEntity(
    @PrimaryKey val attachmentId: String,
    val messageId: String,
    val partId: String,
    val fileName: String?,
    val mimeType: String?,
    val sizeBytes: Long?,
    val downloadState: String = DownloadState.NOT_FETCHED,
    @ColumnInfo(defaultValue = "0") val lastAccessedAtEpochMillis: Long = 0,
)

@Entity(tableName = "cache_config")
data class CacheConfigEntity(
    @PrimaryKey val accountId: String,
    @ColumnInfo(defaultValue = "200") val offlineMessageCount: Int = 200,
    @ColumnInfo(defaultValue = "500") val attachmentCacheLimitMb: Int = 500,
    @ColumnInfo(defaultValue = "60") val autoEvictReadOlderThanDays: Int = 60,
    @ColumnInfo(defaultValue = "1") val prefetchUnreadBodies: Boolean = true,
)

@Entity(tableName = "storage_quota")
data class StorageQuotaEntity(
    @PrimaryKey val accountId: String,
    val usedKb: Long,
    val limitKb: Long,
    val checkedAtEpochMillis: Long,
)

@Entity(
    tableName = "pending_mutations",
    foreignKeys = [
        ForeignKey(entity = AccountEntity::class, parentColumns = ["accountId"], childColumns = ["accountId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = MessageEntity::class, parentColumns = ["messageId"], childColumns = ["messageId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index(value = ["accountId", "state"]), Index(value = ["messageId", "state"]), Index(value = ["mailboxId"])],
)
data class PendingMutationEntity(
    @PrimaryKey val mutationId: String,
    val accountId: String,
    val mailboxId: String?,
    val messageId: String,
    /** UID captured before a local archive removes mailbox membership. */
    val targetUid: Long?,
    val type: String,
    val payload: String?,
    val state: String = MutationState.PENDING,
    val retryCount: Int = 0,
    val createdAtEpochMillis: Long,
    val lastErrorCode: String? = null,
    @ColumnInfo(defaultValue = "''") val previousFlags: String = "",
    @ColumnInfo(defaultValue = "''") val previousLabels: String = "",
)

@Entity(
    tableName = "sync_checkpoints",
    foreignKeys = [
        ForeignKey(entity = AccountEntity::class, parentColumns = ["accountId"], childColumns = ["accountId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = MailboxEntity::class, parentColumns = ["mailboxId"], childColumns = ["mailboxId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index(value = ["accountId"]), Index(value = ["mailboxId"], unique = true)],
)
data class SyncCheckpointEntity(
    @PrimaryKey val mailboxId: String,
    val accountId: String,
    val uidValidity: Long,
    val highestKnownUid: Long,
    val syncGeneration: Long,
    val lastSuccessfulSyncEpochMillis: Long?,
)

@Entity(
    tableName = "drafts",
    foreignKeys = [ForeignKey(entity = AccountEntity::class, parentColumns = ["accountId"], childColumns = ["accountId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index(value = ["accountId", "updatedAtEpochMillis"])],
)
data class DraftEntity(
    @PrimaryKey val draftId: String,
    val accountId: String,
    val toAddresses: String,
    val ccAddresses: String,
    val bccAddresses: String,
    val subject: String,
    val body: String,
    val inReplyTo: String?,
    val references: String,
    val status: String,
    val updatedAtEpochMillis: Long,
    val attachments: String = "",
)

@Entity(tableName = "notification_state")
data class NotificationStateEntity(
    @PrimaryKey val accountId: String,
    val baselineEstablished: Boolean,
)

data class AccountSyncRow(
    val accountId: String,
    val email: String,
    val syncState: String,
    val gmailExtensionsEnabled: Boolean,
    val lastSyncedAtEpochMillis: Long?,
    val messageCount: Int,
)

@Dao
interface AccountDao {
    @Upsert
    suspend fun upsert(account: AccountEntity)

    @Query("SELECT * FROM accounts WHERE accountId = :accountId")
    suspend fun account(accountId: String): AccountEntity?

    @Query("SELECT * FROM accounts ORDER BY createdAtEpochMillis")
    fun observeAccounts(): Flow<List<AccountEntity>>

    @Query("DELETE FROM accounts WHERE accountId = :accountId")
    suspend fun delete(accountId: String)

    @Query("UPDATE accounts SET syncState = :state WHERE accountId = :accountId")
    suspend fun setSyncState(accountId: String, state: String)

    @Query("UPDATE accounts SET syncState = :state, gmailExtensionsEnabled = :gmailExtensionsEnabled, lastSyncedAtEpochMillis = :timestamp WHERE accountId = :accountId")
    suspend fun markSyncSuccess(accountId: String, state: String, gmailExtensionsEnabled: Boolean, timestamp: Long)

    @Query("SELECT a.accountId, a.email, a.syncState, a.gmailExtensionsEnabled, a.lastSyncedAtEpochMillis, COUNT(mm.uid) AS messageCount FROM accounts a LEFT JOIN mailboxes b ON b.accountId = a.accountId AND b.remoteName = 'INBOX' LEFT JOIN mailbox_messages mm ON mm.mailboxId = b.mailboxId WHERE a.accountId = :accountId GROUP BY a.accountId")
    fun observeSummary(accountId: String): Flow<AccountSyncRow?>
}

@Dao
interface MailDao {
    @Query("SELECT COUNT(*) FROM messages WHERE accountId = :accountId")
    suspend fun countMessagesForAccount(accountId: String): Int

    @Query("UPDATE messages SET body = NULL, contentKind = 'PLAIN', bodyDownloadState = 'NOT_FETCHED' WHERE accountId = :accountId AND body IS NOT NULL AND messageId IN (SELECT m.messageId FROM messages m WHERE m.accountId = :accountId AND m.body IS NOT NULL AND NOT EXISTS (SELECT 1 FROM mailbox_messages mm WHERE mm.messageId = m.messageId AND instr(mm.flags, char(92) || 'Seen') = 0) AND NOT EXISTS (SELECT 1 FROM mailbox_messages mm WHERE mm.messageId = m.messageId AND instr(mm.flags, char(92) || 'Flagged') > 0) ORDER BY m.sentAtEpochMillis DESC LIMIT -1 OFFSET :keepCount)")
    suspend fun evictExcessBodies(accountId: String, keepCount: Int)

    @Query("UPDATE messages SET body = NULL, contentKind = 'PLAIN', bodyDownloadState = 'NOT_FETCHED' WHERE accountId = :accountId AND body IS NOT NULL AND sentAtEpochMillis < :beforeEpochMillis AND NOT EXISTS (SELECT 1 FROM mailbox_messages mm WHERE mm.messageId = messages.messageId AND (instr(mm.flags, char(92) || 'Seen') = 0 OR instr(mm.flags, char(92) || 'Flagged') > 0))")
    suspend fun evictOldReadBodies(accountId: String, beforeEpochMillis: Long)

    @Upsert
    suspend fun upsertMailboxes(mailboxes: List<MailboxEntity>)

    @Upsert
    suspend fun upsertMessages(messages: List<MessageEntity>)

    @Query("UPDATE messages SET body = :body, preview = :preview, contentKind = :contentKind, bodyDownloadState = :downloadState WHERE messageId = :messageId")
    suspend fun updateMessageBody(
        messageId: String,
        body: String?,
        preview: String?,
        contentKind: String,
        downloadState: String,
    )

    @Query("SELECT bodyDownloadState FROM messages WHERE messageId = :messageId")
    suspend fun bodyDownloadState(messageId: String): String?

    @Query("SELECT messageId, preview, body, contentKind, bodyDownloadState FROM messages WHERE messageId IN (:messageIds)")
    suspend fun existingBodyStates(messageIds: List<String>): List<MessageBodyStateRow>

    @Query("SELECT COUNT(*) FROM mailbox_messages WHERE mailboxId = :mailboxId")
    suspend fun countMailboxMessages(mailboxId: String): Int

    @Query("SELECT messageCount FROM mailboxes WHERE mailboxId = :mailboxId")
    suspend fun inboxMessageCount(mailboxId: String): Int?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMailboxMessages(messages: List<MailboxMessageEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertLabels(labels: List<MessageLabelEntity>)

    @Query("DELETE FROM message_labels WHERE messageId = :messageId AND label = :label")
    suspend fun removeLabel(messageId: String, label: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAttachments(attachments: List<AttachmentEntity>)

    @Query("SELECT * FROM attachments WHERE attachmentId = :attachmentId LIMIT 1")
    suspend fun attachment(attachmentId: String): AttachmentEntity?

    @Query("UPDATE attachments SET downloadState = :state WHERE attachmentId = :attachmentId")
    suspend fun setAttachmentState(attachmentId: String, state: String)

    @Query("UPDATE attachments SET lastAccessedAtEpochMillis = :timestamp WHERE attachmentId = :attachmentId")
    suspend fun markAttachmentAccessed(attachmentId: String, timestamp: Long)

    @Query("SELECT a.* FROM attachments a JOIN messages m ON m.messageId = a.messageId WHERE m.accountId = :accountId AND a.downloadState = 'AVAILABLE' ORDER BY a.lastAccessedAtEpochMillis ASC")
    suspend fun cachedAttachments(accountId: String): List<AttachmentEntity>

    @Query("DELETE FROM mailbox_messages WHERE mailboxId = :mailboxId")
    suspend fun clearMailboxMembership(mailboxId: String)

    @Query("DELETE FROM mailbox_messages WHERE mailboxId = :mailboxId AND messageId = :messageId")
    suspend fun removeMailboxMembership(mailboxId: String, messageId: String)

    @Query("SELECT * FROM mailbox_messages WHERE messageId = :messageId")
    suspend fun membershipsForMessage(messageId: String): List<MailboxMessageEntity>

    @Query("SELECT messageId FROM messages WHERE messageId IN (:messageIds)")
    suspend fun messageIds(messageIds: List<String>): List<String>

    @Query("SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.sentAtEpochMillis, mm.flags, mm.labels, EXISTS(SELECT 1 FROM attachments a WHERE a.messageId = m.messageId) AS hasAttachment, m.category FROM mailbox_messages mm JOIN messages m ON m.messageId = mm.messageId WHERE mm.mailboxId = :mailboxId AND (m.category = :category OR EXISTS(SELECT 1 FROM messages categorized WHERE categorized.accountId = m.accountId AND categorized.gmailThreadId = m.gmailThreadId AND categorized.category = :category)) ORDER BY m.sentAtEpochMillis DESC, mm.uid DESC")
    fun observeInbox(mailboxId: String, category: String): Flow<List<MailboxMessageRow>>

    @Query("SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.sentAtEpochMillis, mm.flags, mm.labels, EXISTS(SELECT 1 FROM attachments a WHERE a.messageId = m.messageId) AS hasAttachment, m.category FROM mailbox_messages mm JOIN messages m ON m.messageId = mm.messageId WHERE mm.mailboxId = :mailboxId ORDER BY m.sentAtEpochMillis DESC, mm.uid DESC")
    fun observeInbox(mailboxId: String): Flow<List<MailboxMessageRow>>

    @Query("SELECT m.category, COUNT(*) AS unreadCount FROM mailbox_messages mm JOIN messages m ON m.messageId = mm.messageId WHERE mm.mailboxId = :mailboxId AND instr(mm.flags, char(92) || 'Seen') = 0 GROUP BY m.category")
    fun observeCategoryUnreadCounts(mailboxId: String): Flow<List<CategoryUnreadCountRow>>

    @Query("SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.body, m.contentKind, m.sentAtEpochMillis, mm.flags, mm.labels, m.listUnsubscribe, m.listUnsubscribePost FROM messages m JOIN mailbox_messages mm ON mm.messageId = m.messageId WHERE m.messageId = :messageId LIMIT 1")
    fun observeMessage(messageId: String): Flow<MessageDetailRow?>

    @Query("SELECT DISTINCT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.body, m.contentKind, m.sentAtEpochMillis, mm.flags, mm.labels, m.listUnsubscribe, m.listUnsubscribePost FROM messages m JOIN mailbox_messages mm ON mm.messageId = m.messageId WHERE (m.messageId = :messageId OR (m.gmailThreadId IS NOT NULL AND m.gmailThreadId != '' AND m.gmailThreadId = (SELECT target.gmailThreadId FROM messages target WHERE target.messageId = :messageId AND target.gmailThreadId IS NOT NULL AND target.gmailThreadId != ''))) ORDER BY m.sentAtEpochMillis ASC")
    fun observeThread(messageId: String): Flow<List<MessageDetailRow>>

    @Query("SELECT * FROM attachments WHERE messageId = :messageId ORDER BY partId")
    fun observeAttachments(messageId: String): Flow<List<AttachmentEntity>>

    @Query("WITH matched_threads AS (SELECT DISTINCT m.gmailThreadId FROM messages_fts JOIN messages m ON m.rowid = messages_fts.rowid WHERE messages_fts MATCH :ftsQuery AND m.gmailThreadId IS NOT NULL), matched_messages AS (SELECT m.messageId FROM messages_fts JOIN messages m ON m.rowid = messages_fts.rowid WHERE messages_fts MATCH :ftsQuery) SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.sentAtEpochMillis, mm.flags, mm.labels, EXISTS(SELECT 1 FROM attachments a WHERE a.messageId = m.messageId) AS hasAttachment, m.category FROM messages m JOIN mailbox_messages mm ON mm.messageId = m.messageId WHERE mm.mailboxId = :mailboxId AND (m.messageId IN matched_messages OR m.gmailThreadId IN matched_threads) ORDER BY m.sentAtEpochMillis DESC LIMIT 500")
    fun search(mailboxId: String, ftsQuery: String): Flow<List<MailboxMessageRow>>
}

data class MailboxMessageRow(val messageId: String, val gmailThreadId: String?, val sender: String?, val subject: String?, val preview: String?, val sentAtEpochMillis: Long?, val flags: String, val labels: String, val hasAttachment: Boolean, val category: String)
data class CategoryUnreadCountRow(val category: String, val unreadCount: Int)
data class MessageDetailRow(val messageId: String, val gmailThreadId: String?, val sender: String?, val subject: String?, val preview: String?, val body: String?, val contentKind: String, val sentAtEpochMillis: Long?, val flags: String, val labels: String, val listUnsubscribe: String?, val listUnsubscribePost: String?)

@Dao
interface CacheConfigDao {
    @Query("SELECT * FROM cache_config WHERE accountId = :accountId LIMIT 1")
    fun observe(accountId: String): Flow<CacheConfigEntity?>

    @Query("SELECT * FROM cache_config WHERE accountId = :accountId LIMIT 1")
    suspend fun get(accountId: String): CacheConfigEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(config: CacheConfigEntity)

    @Query("SELECT * FROM storage_quota WHERE accountId = :accountId LIMIT 1")
    fun observeQuota(accountId: String): Flow<StorageQuotaEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveQuota(quota: StorageQuotaEntity)
}
data class MessageBodyStateRow(val messageId: String, val preview: String?, val body: String?, val contentKind: String, val bodyDownloadState: String)

@Dao
interface SyncDao {
    @Query("SELECT * FROM sync_checkpoints WHERE mailboxId = :mailboxId")
    suspend fun checkpoint(mailboxId: String): SyncCheckpointEntity?

    @Query("DELETE FROM sync_checkpoints WHERE mailboxId = :mailboxId")
    suspend fun deleteCheckpoint(mailboxId: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertCheckpoint(checkpoint: SyncCheckpointEntity)
}

@Dao
interface DraftDao {
    @Query("SELECT * FROM drafts WHERE accountId = :accountId ORDER BY updatedAtEpochMillis DESC")
    fun observeDrafts(accountId: String): Flow<List<DraftEntity>>

    @Query("SELECT * FROM drafts WHERE draftId = :draftId LIMIT 1")
    fun observeDraft(draftId: String): Flow<DraftEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(draft: DraftEntity)

    @Query("DELETE FROM drafts WHERE draftId = :draftId")
    suspend fun delete(draftId: String)
}

@Dao
interface NotificationStateDao {
    @Query("SELECT * FROM notification_state WHERE accountId = :accountId LIMIT 1")
    suspend fun state(accountId: String): NotificationStateEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(state: NotificationStateEntity)

    @Query("DELETE FROM notification_state WHERE accountId = :accountId")
    suspend fun delete(accountId: String)
}

@Dao
interface PendingMutationDao {
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(mutation: PendingMutationEntity)

    @Query("SELECT * FROM pending_mutations WHERE accountId = :accountId AND state IN ('PENDING', 'IN_FLIGHT') ORDER BY createdAtEpochMillis, mutationId")
    suspend fun activeForAccount(accountId: String): List<PendingMutationEntity>

    @Query("SELECT * FROM pending_mutations WHERE messageId = :messageId AND state IN ('PENDING', 'IN_FLIGHT') ORDER BY createdAtEpochMillis, mutationId")
    suspend fun activeForMessage(messageId: String): List<PendingMutationEntity>

    @Query("UPDATE pending_mutations SET state = :state, retryCount = :retryCount, lastErrorCode = :errorCode WHERE mutationId = :mutationId")
    suspend fun updateState(mutationId: String, state: String, retryCount: Int, errorCode: String?)

    @Query("DELETE FROM pending_mutations WHERE mutationId = :mutationId")
    suspend fun delete(mutationId: String)

    @Query("SELECT * FROM pending_mutations WHERE messageId = :messageId AND type = 'ARCHIVE' AND state = 'PENDING' ORDER BY createdAtEpochMillis DESC LIMIT 1")
    suspend fun undoableArchive(messageId: String): PendingMutationEntity?
}

@Database(
    entities = [
        AccountEntity::class,
        MailboxEntity::class,
        MessageEntity::class,
        MessageFtsEntity::class,
        MailboxMessageEntity::class,
        MessageLabelEntity::class,
        AttachmentEntity::class,
        PendingMutationEntity::class,
        SyncCheckpointEntity::class,
        DraftEntity::class,
        NotificationStateEntity::class,
        CacheConfigEntity::class,
        StorageQuotaEntity::class,
    ],
    version = 10,
    exportSchema = true,
)
abstract class GlassMailDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun mailDao(): MailDao
    abstract fun syncDao(): SyncDao
    abstract fun pendingMutationDao(): PendingMutationDao
    abstract fun draftDao(): DraftDao
    abstract fun notificationStateDao(): NotificationStateDao
    abstract fun cacheConfigDao(): CacheConfigDao

    companion object {
        fun create(context: Context): GlassMailDatabase = Room.databaseBuilder(
            context.applicationContext,
            GlassMailDatabase::class.java,
            "glassmail.db",
        ).addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6, MIGRATION_6_7, MIGRATION_7_8, MIGRATION_8_9, MIGRATION_9_10).build()

        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("ALTER TABLE messages ADD COLUMN bodyDownloadState TEXT NOT NULL DEFAULT 'NOT_FETCHED'")
                database.execSQL("CREATE TABLE IF NOT EXISTS message_labels (messageId TEXT NOT NULL, label TEXT NOT NULL, PRIMARY KEY(messageId, label), FOREIGN KEY(messageId) REFERENCES messages(messageId) ON DELETE CASCADE)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_message_labels_label ON message_labels(label)")
                database.execSQL("CREATE TABLE IF NOT EXISTS attachments (attachmentId TEXT NOT NULL, messageId TEXT NOT NULL, partId TEXT NOT NULL, fileName TEXT, mimeType TEXT, sizeBytes INTEGER, downloadState TEXT NOT NULL, PRIMARY KEY(attachmentId), FOREIGN KEY(messageId) REFERENCES messages(messageId) ON DELETE CASCADE)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_attachments_messageId ON attachments(messageId)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_attachments_downloadState ON attachments(downloadState)")
                database.execSQL("CREATE TABLE IF NOT EXISTS pending_mutations (mutationId TEXT NOT NULL, accountId TEXT NOT NULL, mailboxId TEXT, messageId TEXT NOT NULL, type TEXT NOT NULL, payload TEXT, state TEXT NOT NULL, retryCount INTEGER NOT NULL, createdAtEpochMillis INTEGER NOT NULL, lastErrorCode TEXT, PRIMARY KEY(mutationId), FOREIGN KEY(accountId) REFERENCES accounts(accountId) ON DELETE CASCADE, FOREIGN KEY(messageId) REFERENCES messages(messageId) ON DELETE CASCADE)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_pending_mutations_accountId_state ON pending_mutations(accountId, state)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_pending_mutations_messageId_state ON pending_mutations(messageId, state)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_pending_mutations_mailboxId ON pending_mutations(mailboxId)")
                database.execSQL("CREATE TABLE IF NOT EXISTS sync_checkpoints (mailboxId TEXT NOT NULL, accountId TEXT NOT NULL, uidValidity INTEGER NOT NULL, highestKnownUid INTEGER NOT NULL, syncGeneration INTEGER NOT NULL, lastSuccessfulSyncEpochMillis INTEGER, PRIMARY KEY(mailboxId), FOREIGN KEY(accountId) REFERENCES accounts(accountId) ON DELETE CASCADE, FOREIGN KEY(mailboxId) REFERENCES mailboxes(mailboxId) ON DELETE CASCADE)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_sync_checkpoints_accountId ON sync_checkpoints(accountId)")
                database.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_sync_checkpoints_mailboxId ON sync_checkpoints(mailboxId)")
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("ALTER TABLE pending_mutations ADD COLUMN targetUid INTEGER")
            }
        }

        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("ALTER TABLE messages ADD COLUMN preview TEXT")
                database.execSQL("ALTER TABLE messages ADD COLUMN body TEXT")
                database.execSQL("ALTER TABLE messages ADD COLUMN contentKind TEXT NOT NULL DEFAULT 'PLAIN'")
            }
        }

        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("CREATE TABLE IF NOT EXISTS drafts (draftId TEXT NOT NULL, accountId TEXT NOT NULL, toAddresses TEXT NOT NULL, ccAddresses TEXT NOT NULL, bccAddresses TEXT NOT NULL, subject TEXT NOT NULL, body TEXT NOT NULL, inReplyTo TEXT, `references` TEXT NOT NULL, status TEXT NOT NULL, updatedAtEpochMillis INTEGER NOT NULL, PRIMARY KEY(draftId), FOREIGN KEY(accountId) REFERENCES accounts(accountId) ON UPDATE NO ACTION ON DELETE CASCADE)")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_drafts_accountId_updatedAtEpochMillis ON drafts(accountId, updatedAtEpochMillis)")
            }
        }

        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("ALTER TABLE drafts ADD COLUMN attachments TEXT NOT NULL DEFAULT ''")
            }
        }

        val MIGRATION_6_7 = object : Migration(6, 7) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("CREATE TABLE IF NOT EXISTS notification_state (accountId TEXT NOT NULL, baselineEstablished INTEGER NOT NULL, PRIMARY KEY(accountId))")
            }
        }

        val MIGRATION_7_8 = object : Migration(7, 8) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("ALTER TABLE messages ADD COLUMN category TEXT NOT NULL DEFAULT 'PRIMARY'")
                database.execSQL("CREATE INDEX IF NOT EXISTS index_messages_accountId_category ON messages(accountId, category)")
                database.execSQL("CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING FTS4(subject, sender, preview, body, content='messages', tokenize=unicode61)")
                database.execSQL("INSERT INTO messages_fts(messages_fts) VALUES('rebuild')")
            }
        }

        val MIGRATION_8_9 = object : Migration(8, 9) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("CREATE TABLE IF NOT EXISTS cache_config (accountId TEXT NOT NULL, offlineMessageCount INTEGER NOT NULL DEFAULT 200, attachmentCacheLimitMb INTEGER NOT NULL DEFAULT 500, autoEvictReadOlderThanDays INTEGER NOT NULL DEFAULT 60, prefetchUnreadBodies INTEGER NOT NULL DEFAULT 1, PRIMARY KEY(accountId))")
                database.execSQL("ALTER TABLE attachments ADD COLUMN lastAccessedAtEpochMillis INTEGER NOT NULL DEFAULT 0")
                database.execSQL("ALTER TABLE messages ADD COLUMN listUnsubscribe TEXT")
                database.execSQL("ALTER TABLE messages ADD COLUMN listUnsubscribePost TEXT")
                database.execSQL("CREATE TABLE IF NOT EXISTS storage_quota (accountId TEXT NOT NULL, usedKb INTEGER NOT NULL, limitKb INTEGER NOT NULL, checkedAtEpochMillis INTEGER NOT NULL, PRIMARY KEY(accountId))")
            }
        }

        val MIGRATION_9_10 = object : Migration(9, 10) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("ALTER TABLE pending_mutations ADD COLUMN previousFlags TEXT NOT NULL DEFAULT ''")
                database.execSQL("ALTER TABLE pending_mutations ADD COLUMN previousLabels TEXT NOT NULL DEFAULT ''")
            }
        }
    }
}
