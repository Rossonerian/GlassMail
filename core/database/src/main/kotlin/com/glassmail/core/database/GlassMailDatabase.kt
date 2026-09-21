package com.glassmail.core.database

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
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
    indices = [Index(value = ["accountId", "gmailMessageId"], unique = true), Index(value = ["accountId", "gmailThreadId"])],
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
    val preview: String? = null,
    val body: String? = null,
    val contentKind: String = "PLAIN",
    val bodyDownloadState: String = DownloadState.NOT_FETCHED,
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
    @Insert(onConflict = OnConflictStrategy.REPLACE)
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
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMailboxes(mailboxes: List<MailboxEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMessages(messages: List<MessageEntity>)

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

    @Query("DELETE FROM mailbox_messages WHERE mailboxId = :mailboxId")
    suspend fun clearMailboxMembership(mailboxId: String)

    @Query("DELETE FROM mailbox_messages WHERE mailboxId = :mailboxId AND messageId = :messageId")
    suspend fun removeMailboxMembership(mailboxId: String, messageId: String)

    @Query("SELECT * FROM mailbox_messages WHERE messageId = :messageId")
    suspend fun membershipsForMessage(messageId: String): List<MailboxMessageEntity>

    @Query("SELECT messageId FROM messages WHERE messageId IN (:messageIds)")
    suspend fun messageIds(messageIds: List<String>): List<String>

    @Query("SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.sentAtEpochMillis, mm.flags, mm.labels, EXISTS(SELECT 1 FROM attachments a WHERE a.messageId = m.messageId) AS hasAttachment FROM mailbox_messages mm JOIN messages m ON m.messageId = mm.messageId WHERE mm.mailboxId = :mailboxId ORDER BY m.sentAtEpochMillis DESC, mm.uid DESC")
    fun observeInbox(mailboxId: String): Flow<List<MailboxMessageRow>>

    @Query("SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.body, m.contentKind, m.sentAtEpochMillis, mm.flags, mm.labels FROM messages m JOIN mailbox_messages mm ON mm.messageId = m.messageId WHERE m.messageId = :messageId LIMIT 1")
    fun observeMessage(messageId: String): Flow<MessageDetailRow?>

    @Query("SELECT DISTINCT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.body, m.contentKind, m.sentAtEpochMillis, mm.flags, mm.labels FROM messages m JOIN mailbox_messages mm ON mm.messageId = m.messageId WHERE (m.messageId = :messageId OR (m.gmailThreadId IS NOT NULL AND m.gmailThreadId != '' AND m.gmailThreadId = (SELECT target.gmailThreadId FROM messages target WHERE target.messageId = :messageId AND target.gmailThreadId IS NOT NULL AND target.gmailThreadId != ''))) ORDER BY m.sentAtEpochMillis ASC")
    fun observeThread(messageId: String): Flow<List<MessageDetailRow>>

    @Query("SELECT * FROM attachments WHERE messageId = :messageId ORDER BY partId")
    fun observeAttachments(messageId: String): Flow<List<AttachmentEntity>>

    @Query("SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, m.sentAtEpochMillis, mm.flags, mm.labels, EXISTS(SELECT 1 FROM attachments a WHERE a.messageId = m.messageId) AS hasAttachment FROM mailbox_messages mm JOIN messages m ON m.messageId = mm.messageId WHERE mm.mailboxId = :mailboxId AND (m.sender LIKE '%' || :query || '%' OR m.subject LIKE '%' || :query || '%' OR m.preview LIKE '%' || :query || '%') ORDER BY m.sentAtEpochMillis DESC LIMIT 200")
    fun search(mailboxId: String, query: String): Flow<List<MailboxMessageRow>>
}

data class MailboxMessageRow(val messageId: String, val gmailThreadId: String?, val sender: String?, val subject: String?, val preview: String?, val sentAtEpochMillis: Long?, val flags: String, val labels: String, val hasAttachment: Boolean)
data class MessageDetailRow(val messageId: String, val gmailThreadId: String?, val sender: String?, val subject: String?, val preview: String?, val body: String?, val contentKind: String, val sentAtEpochMillis: Long?, val flags: String, val labels: String)

@Dao
interface SyncDao {
    @Query("SELECT * FROM sync_checkpoints WHERE mailboxId = :mailboxId")
    suspend fun checkpoint(mailboxId: String): SyncCheckpointEntity?

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
}

@Database(
    entities = [
        AccountEntity::class,
        MailboxEntity::class,
        MessageEntity::class,
        MailboxMessageEntity::class,
        MessageLabelEntity::class,
        AttachmentEntity::class,
        PendingMutationEntity::class,
        SyncCheckpointEntity::class,
        DraftEntity::class,
        NotificationStateEntity::class,
    ],
    version = 7,
    exportSchema = true,
)
abstract class GlassMailDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun mailDao(): MailDao
    abstract fun syncDao(): SyncDao
    abstract fun pendingMutationDao(): PendingMutationDao
    abstract fun draftDao(): DraftDao
    abstract fun notificationStateDao(): NotificationStateDao

    companion object {
        fun create(context: Context): GlassMailDatabase = Room.databaseBuilder(
            context.applicationContext,
            GlassMailDatabase::class.java,
            "glassmail.db",
        ).addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6, MIGRATION_6_7).build()

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
    }
}
