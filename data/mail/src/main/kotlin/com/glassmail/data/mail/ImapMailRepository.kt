package com.glassmail.data.mail

import androidx.room.withTransaction
import com.glassmail.core.database.AccountEntity
import com.glassmail.core.database.AttachmentEntity
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.database.MailboxEntity
import com.glassmail.core.database.MailboxMessageEntity
import com.glassmail.core.database.MessageEntity
import com.glassmail.core.database.MessageLabelEntity
import com.glassmail.core.database.DraftEntity
import com.glassmail.core.database.MutationState
import com.glassmail.core.database.PendingMutationEntity
import com.glassmail.core.database.SyncCheckpointEntity
import com.glassmail.core.database.NotificationStateEntity
import com.glassmail.core.database.CacheConfigEntity
import com.glassmail.core.database.StorageQuotaEntity
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.imap.ImapException
import com.glassmail.core.model.GmailInboxSnapshot
import com.glassmail.core.model.MailSyncError
import com.glassmail.core.model.MailSyncResult
import com.glassmail.core.security.CredentialStore
import com.glassmail.domain.mail.AccountSyncSummary
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailAttachment
import com.glassmail.domain.mail.MailListItem
import com.glassmail.domain.mail.MailMessage
import com.glassmail.domain.mail.MailCategory
import com.glassmail.domain.mail.MailRepository
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailDraft
import com.glassmail.domain.mail.DraftStatus
import com.glassmail.domain.mail.DraftAttachment
import com.glassmail.domain.mail.sanitizeAttachmentName
import com.glassmail.domain.mail.MailMutation
import com.glassmail.domain.mail.AttachmentRepository
import com.glassmail.domain.mail.DownloadedAttachment
import com.glassmail.domain.mail.MailCacheSettings
import com.glassmail.domain.mail.StorageQuota
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class ImapMailRepository(
    private val database: GlassMailDatabase,
    private val credentialStore: CredentialStore,
    private val imapClient: GmailImapClient,
    private val attachmentRoot: File? = null,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onNewMessages: suspend (List<MailListItem>) -> Unit = {},
) : MailRepository, DraftRepository, AttachmentRepository {
    private val accountMutexes = ConcurrentHashMap<String, Mutex>()
    private val mutationExecutor = PendingMutationExecutor(database, credentialStore, imapClient)

    override fun observeAccounts(): Flow<List<MailAccount>> = database.accountDao().observeAccounts().map { accounts ->
        accounts.map { MailAccount(it.accountId, it.email, it.syncState) }
    }

    override fun observeAccount(accountId: String): Flow<AccountSyncSummary?> = database.accountDao()
        .observeSummary(accountId)
        .map { row ->
            row?.let {
                AccountSyncSummary(
                    accountId = it.accountId,
                    email = it.email,
                    syncState = it.syncState,
                    messageCount = it.messageCount,
                    gmailExtensionsEnabled = it.gmailExtensionsEnabled,
                    lastSyncedAtEpochMillis = it.lastSyncedAtEpochMillis,
                )
            }
        }

    override fun observeInbox(accountId: String): Flow<List<MailListItem>> = observeInbox(accountId, MailCategory.PRIMARY)

    override fun observeInbox(accountId: String, category: String): Flow<List<MailListItem>> = database.mailDao()
        .observeInbox("$accountId:INBOX", category).map { rows -> rows.toThreadItems() }

    override fun observeCategoryUnreadCounts(accountId: String): Flow<Map<String, Int>> = database.mailDao()
        .observeCategoryUnreadCounts("$accountId:INBOX")
        .map { rows -> rows.associate { it.category to it.unreadCount } }

    override fun search(accountId: String, query: String): Flow<List<MailListItem>> {
        val expression = query.toFtsMatchExpression() ?: return flowOf(emptyList())
        return database.mailDao().search("$accountId:INBOX", expression).map { rows -> rows.toThreadItems() }
    }

    override fun observeMessage(messageId: String): Flow<MailMessage?> = database.mailDao().observeMessage(messageId)
        .combine(database.mailDao().observeAttachments(messageId)) { row, attachments ->
            row?.let { MailMessage(it.messageId, it.gmailThreadId, it.sender.orEmpty(), it.subject.orEmpty(), it.preview.orEmpty(), it.body, it.contentKind == "HTML", it.sentAtEpochMillis, "\\Seen" !in it.flags.toFlagSet(), "\\Flagged" in it.flags.toFlagSet(), it.labels.toLabels(), attachments.map { attachment -> MailAttachment(attachment.attachmentId, attachment.fileName, attachment.mimeType, attachment.sizeBytes, attachment.downloadState) }, it.listUnsubscribe, it.listUnsubscribePost) }
        }

    override fun observeThread(messageId: String): Flow<List<MailMessage>> = database.mailDao().observeThread(messageId)
        .map { rows -> rows.map { it.toMailMessage() } }

    override fun observeDrafts(accountId: String): Flow<List<MailDraft>> = database.draftDao().observeDrafts(accountId).map { drafts -> drafts.map(DraftEntity::toDraft) }

    override fun observeDraft(draftId: String): Flow<MailDraft?> = database.draftDao().observeDraft(draftId).map { it?.toDraft() }

    override fun observeCacheSettings(accountId: String): Flow<MailCacheSettings> = database.cacheConfigDao().observe(accountId).map { it?.toSettings() ?: MailCacheSettings() }

    override fun observeStorageQuota(accountId: String): Flow<StorageQuota?> = database.cacheConfigDao().observeQuota(accountId).map { entity ->
        entity?.let { StorageQuota(it.usedKb, it.limitKb, it.checkedAtEpochMillis) }
    }

    override suspend fun saveCacheSettings(accountId: String, settings: MailCacheSettings) {
        require(database.accountDao().account(accountId) != null)
        require(settings.offlineMessageCount in CACHE_MESSAGE_PRESETS)
        require(settings.attachmentCacheLimitMb in CACHE_ATTACHMENT_PRESETS)
        require(settings.autoEvictReadOlderThanDays in setOf(30, 60, 90))
        database.cacheConfigDao().upsert(settings.toEntity(accountId))
        enforceCacheLimits(accountId)
    }

    override suspend fun enforceCacheLimits(accountId: String) {
        val settings = database.cacheConfigDao().get(accountId)?.toSettings() ?: MailCacheSettings()
        database.mailDao().evictExcessBodies(accountId, settings.offlineMessageCount)
        database.mailDao().evictOldReadBodies(accountId, clock() - settings.autoEvictReadOlderThanDays * DAY_MILLIS)
        val attachments = database.mailDao().cachedAttachments(accountId)
        var bytes = attachments.sumOf { it.sizeBytes ?: 0L }
        val limitBytes = settings.attachmentCacheLimitMb * 1024L * 1024L
        attachments.forEach { attachment ->
            if (bytes <= limitBytes) return@forEach
            attachmentPath(attachment)?.delete()
            database.mailDao().setAttachmentState(attachment.attachmentId, com.glassmail.core.database.DownloadState.NOT_FETCHED)
            bytes -= attachment.sizeBytes ?: 0L
        }
    }

    override suspend fun refreshStorageQuota(accountId: String): Result<StorageQuota> = runCatching {
        val account = database.accountDao().account(accountId) ?: error("Account unavailable")
        val remote = credentialStore.withCredential(accountId) { password -> imapClient.fetchStorageQuota(account.email, password) }
            ?: error("Storage quota is unsupported or credentials are unavailable")
        val quota = StorageQuota(remote.usedKb, remote.limitKb, clock())
        database.cacheConfigDao().saveQuota(StorageQuotaEntity(accountId, quota.usedKb, quota.limitKb, quota.checkedAtEpochMillis))
        quota
    }

    override suspend fun saveDraft(draft: MailDraft) {
        require(draft.draftId.isNotBlank() && draft.accountId.isNotBlank())
        database.draftDao().upsert(draft.toEntity())
    }

    override suspend fun deleteDraft(draftId: String) {
        val draft = database.draftDao().observeDraft(draftId).first()?.toDraft()
        if (draft != null && draft.status == DraftStatus.DRAFT) {
            val account = database.accountDao().account(draft.accountId)
            if (account != null) {
                runCatching {
                    credentialStore.withCredential(draft.accountId) { password ->
                        imapClient.deleteRemoteDraft(account.email, password, draftId)
                    }
                }
            }
        }
        database.draftDao().delete(draftId)
    }

    override suspend fun loadMessageBody(messageId: String): Result<MailMessage> = runCatching {
        val existingState = database.mailDao().bodyDownloadState(messageId)
        if (existingState == com.glassmail.core.database.DownloadState.AVAILABLE) {
            val cached = database.mailDao().observeMessage(messageId).firstOrNull()?.toMailMessage()
            if (cached != null && !cached.body.isNullOrBlank()) {
                return@runCatching cached
            }
        }

        val membership = database.mailDao().membershipsForMessage(messageId).firstOrNull()
            ?: error("Mailbox mapping unavailable for message $messageId")
        val accountId = membership.mailboxId.substringBefore(':')
        val account = database.accountDao().account(accountId)
            ?: error("Account unavailable for message $messageId")
        val mailboxName = membership.mailboxId.substringAfter(':', "INBOX")

        val parsed = credentialStore.withCredential(accountId) { password ->
            imapClient.fetchMessageBody(account.email, password, mailboxName, membership.uid)
        } ?: error("Authentication required to fetch message body")

        val bodyToStore = parsed.plainText ?: parsed.htmlText.orEmpty()
        database.mailDao().updateMessageBody(
            messageId = messageId,
            body = bodyToStore,
            preview = parsed.previewSnippet,
            contentKind = if (parsed.htmlText != null) "HTML" else "PLAIN",
            downloadState = com.glassmail.core.database.DownloadState.AVAILABLE,
        )

        database.mailDao().observeMessage(messageId).firstOrNull()?.toMailMessage()
            ?: error("Could not load updated message from database")
    }

    override suspend fun downloadAttachment(accountId: String, attachmentId: String): Result<DownloadedAttachment> = runCatching {
        val root = attachmentRoot ?: error("Attachment storage is unavailable")
        val account = database.accountDao().account(accountId) ?: error("Account is unavailable")
        val attachment = database.mailDao().attachment(attachmentId) ?: error("Attachment is unavailable")
        require(attachment.messageId.startsWith("gmail:$accountId:") || attachment.messageId.startsWith("imap:$accountId:")) { "Attachment does not belong to account" }
        val membership = database.mailDao().membershipsForMessage(attachment.messageId).firstOrNull() ?: error("Mailbox mapping is unavailable")
        database.mailDao().setAttachmentState(attachmentId, com.glassmail.core.database.DownloadState.FETCHING)
        val payload = credentialStore.withCredential(accountId) { password ->
            imapClient.fetchAttachment(account.email, password, membership.mailboxId.substringAfter(':', "INBOX"), membership.uid, attachment.partId)
        } ?: error("Authentication required")
        val safeName = sanitizeAttachmentName(attachment.fileName.orEmpty())
        val accountDir = File(root, "attachments/$accountId").apply { mkdirs() }
        val target = File(accountDir, "${attachmentId.hashCode().toUInt().toString(16)}-$safeName")
        if (target.isFile && attachment.downloadState == com.glassmail.core.database.DownloadState.AVAILABLE) {
            database.mailDao().markAttachmentAccessed(attachmentId, clock())
            return@runCatching DownloadedAttachment(target.canonicalPath, safeName, attachment.mimeType ?: "application/octet-stream")
        }
        val temp = File(accountDir, ".${target.name}.part")
        temp.outputStream().use { it.write(payload) }
        check(temp.renameTo(target)) { "Could not store attachment" }
        database.mailDao().setAttachmentState(attachmentId, com.glassmail.core.database.DownloadState.AVAILABLE)
        database.mailDao().markAttachmentAccessed(attachmentId, clock())
        DownloadedAttachment(target.canonicalPath, safeName, attachment.mimeType ?: "application/octet-stream")
    }.onFailure { database.mailDao().setAttachmentState(attachmentId, com.glassmail.core.database.DownloadState.FAILED) }

    override suspend fun createAccount(accountId: String, email: String, syncState: String) {
        require(email.isNotBlank() && email.none { it == '\r' || it == '\n' }) { "Invalid account email" }
        database.accountDao().upsert(
            AccountEntity(
                accountId = accountId,
                email = email.trim(),
                createdAtEpochMillis = clock(),
                syncState = syncState,
            ),
        )
    }

    override suspend fun removeAccount(accountId: String) {
        database.accountDao().delete(accountId)
        database.notificationStateDao().delete(accountId)
        credentialStore.delete(accountId)
    }

    override suspend fun clearDebugMailbox() { database.accountDao().delete(DEBUG_ACCOUNT_ID) }

    override suspend fun seedDebugMailbox(count: Int) {
        require(count in setOf(10, 100, 1_000, 10_000))
        clearDebugMailbox()
        createAccount(DEBUG_ACCOUNT_ID, "debug@glassmail.local")
        database.withTransaction {
            database.mailDao().upsertMailboxes(listOf(MailboxEntity("$DEBUG_ACCOUNT_ID:INBOX", DEBUG_ACCOUNT_ID, "INBOX", 1, count.toLong() + 1, count)))
            database.syncDao().upsertCheckpoint(SyncCheckpointEntity("$DEBUG_ACCOUNT_ID:INBOX", DEBUG_ACCOUNT_ID, 1, count.toLong(), 1, clock()))
        }
        (1..count).chunked(BATCH_SIZE).forEach { ids -> database.withTransaction {
            val messages = ids.map { fixtureMessage(it) }
            database.mailDao().upsertMessages(messages)
            database.mailDao().upsertMailboxMessages(messages.mapIndexed { index, message -> MailboxMessageEntity("$DEBUG_ACCOUNT_ID:INBOX", ids[index].toLong(), message.messageId, buildString { if (ids[index] % 3 != 0) append("\\Seen "); if (ids[index] % 5 == 0) append("\\Flagged") }.trim(), if (ids[index] % 5 == 0) "STARRED" else "INBOX") })
            database.mailDao().upsertLabels(messages.filterIndexed { index, _ -> ids[index] % 7 == 0 }.map { MessageLabelEntity(it.messageId, "Travel") })
            database.mailDao().upsertAttachments(messages.filterIndexed { index, _ -> ids[index] % 9 == 0 }.map { AttachmentEntity("${it.messageId}:1", it.messageId, "1", "fixture-${it.messageId}.pdf", "application/pdf", 4_096) })
        } }
    }

    override suspend fun synchronize(accountId: String): MailSyncResult = accountMutexes
        .getOrPut(accountId) { Mutex() }
        .withLock {
            synchronizeLocked(accountId)
        }

    override suspend fun applyMutation(mutation: MailMutation) {
        database.withTransaction {
            val previousMembership = database.mailDao().membershipsForMessage(mutation.messageId)
                .firstOrNull { mutation.mailboxId == null || it.mailboxId == mutation.mailboxId }
            val targetUid = previousMembership?.uid
            when (mutation) {
                is MailMutation.MarkRead -> updateFlags(mutation.messageId, mutation.mailboxId) { it.withFlag("\\Seen", mutation.read) }
                is MailMutation.Star -> updateFlags(mutation.messageId, mutation.mailboxId) { it.withFlag("\\Flagged", mutation.starred) }
                is MailMutation.Archive -> database.mailDao().removeMailboxMembership(mutation.mailboxId, mutation.messageId)
                is MailMutation.Delete -> {
                    val mId = mutation.mailboxId
                    if (mId != null) {
                        database.mailDao().removeMailboxMembership(mId, mutation.messageId)
                    } else {
                        database.mailDao().membershipsForMessage(mutation.messageId).forEach {
                            database.mailDao().removeMailboxMembership(it.mailboxId, mutation.messageId)
                        }
                    }
                }
                is MailMutation.Label -> if (mutation.add) database.mailDao().upsertLabels(listOf(MessageLabelEntity(mutation.messageId, mutation.label)))
                else database.mailDao().removeLabel(mutation.messageId, mutation.label)
            }
            database.pendingMutationDao().insert(
                PendingMutationEntity(
                    mutationId = UUID.randomUUID().toString(),
                    accountId = mutation.accountId,
                    mailboxId = mutation.mailboxId,
                    messageId = mutation.messageId,
                    targetUid = targetUid,
                    type = mutation.type(),
                    payload = mutation.payload(),
                    state = MutationState.PENDING,
                    createdAtEpochMillis = clock(),
                    previousFlags = previousMembership?.flags.orEmpty(),
                    previousLabels = previousMembership?.labels.orEmpty(),
                ),
            )
        }
    }

    override suspend fun undoPendingArchive(messageId: String): Boolean = database.withTransaction {
        val mutation = database.pendingMutationDao().undoableArchive(messageId) ?: return@withTransaction false
        val mailboxId = mutation.mailboxId ?: return@withTransaction false
        val uid = mutation.targetUid ?: return@withTransaction false
        database.mailDao().upsertMailboxMessages(
            listOf(MailboxMessageEntity(mailboxId, uid, messageId, mutation.previousFlags, mutation.previousLabels)),
        )
        database.pendingMutationDao().delete(mutation.mutationId)
        true
    }

    private suspend fun synchronizeLocked(accountId: String): MailSyncResult {
        val account = database.accountDao().account(accountId)
            ?: return MailSyncResult.Failure(MailSyncError.Protocol)
        database.accountDao().setSyncState(accountId, "SYNCING")
        return try {
            val inboxId = "$accountId:INBOX"
            val checkpoint = database.syncDao().checkpoint(inboxId)
            val cachedMessages = database.mailDao().countMessagesForAccount(accountId)
            val cachedInboxMessages = database.mailDao().countMailboxMessages(inboxId)
            val knownRemoteInboxCount = database.mailDao().inboxMessageCount(inboxId) ?: 0
            val recoverMissingInboxMemberships = cachedMessages > 0 &&
                cachedInboxMessages == 0 && knownRemoteInboxCount > 0
            val startWithLatest = checkpoint == null || cachedMessages == 0 || recoverMissingInboxMemberships
            if (checkpoint != null && startWithLatest) {
                // Older builds walked UID space from 1, which can spend many retries in
                // empty ranges for long-lived Gmail accounts. Re-seed empty or detached
                // Inbox caches from the newest message sequence numbers so mail appears fast.
                database.syncDao().deleteCheckpoint(inboxId)
                if (cachedMessages == 0 || recoverMissingInboxMemberships) {
                    database.notificationStateDao().delete(accountId)
                }
            }
            val snapshot = credentialStore.withCredential(accountId) { password ->
                if (startWithLatest) {
                    imapClient.fetchLatestInbox(account.email, password, limit = INITIAL_MAIL_LIMIT)
                } else {
                    imapClient.fetchInboxPage(
                        email = account.email,
                        password = password,
                        afterUid = checkpoint?.highestKnownUid ?: 0,
                        limit = BATCH_SIZE,
                    )
                }
            } ?: return fail(accountId, MailSyncError.MissingCredential)
            val newMessages = persistSnapshot(accountId, snapshot)
            if (newMessages.isNotEmpty()) onNewMessages(newMessages.map { it.toListItem(accountId, snapshot.inbox.uidValidity) })
            mutationExecutor.flush(accountId, account.email)

            // Prefetch recent message bodies (up to 12) so inbox list immediately displays rich previews
            val cacheSettings = database.cacheConfigDao().get(accountId)?.toSettings() ?: MailCacheSettings()
            val recentToPrefetch = if (cacheSettings.prefetchUnreadBodies) snapshot.messages.filter { "\\Seen" !in it.flags }.take(12) else emptyList()
            credentialStore.withCredential(accountId) { password ->
                for (meta in recentToPrefetch) {
                    val mId = meta.canonicalId(accountId, snapshot.inbox.uidValidity)
                    if (database.mailDao().bodyDownloadState(mId) != com.glassmail.core.database.DownloadState.AVAILABLE) {
                        runCatching {
                            val parsed = imapClient.fetchMessageBody(account.email, password, "INBOX", meta.uid)
                            val bodyToStore = parsed.plainText ?: parsed.htmlText.orEmpty()
                            database.mailDao().updateMessageBody(
                                messageId = mId,
                                body = bodyToStore,
                                preview = parsed.previewSnippet,
                                contentKind = if (parsed.htmlText != null) "HTML" else "PLAIN",
                                downloadState = com.glassmail.core.database.DownloadState.AVAILABLE,
                            )
                        }
                    }
                }
            }
            runCatching { refreshStorageQuota(accountId) }
            enforceCacheLimits(accountId)
            if (!snapshot.hasMoreUids) runCatching { synchronizeRemoteDrafts(account) }

            MailSyncResult.Success(
                messageCount = snapshot.messages.size,
                gmailExtensionsEnabled = snapshot.supportsGmailExtensions,
                hasMore = snapshot.hasMoreUids,
            )
        } catch (error: CancellationException) {
            throw error
        } catch (_: ImapException.Authentication) {
            fail(accountId, MailSyncError.Authentication)
        } catch (_: ImapException.Transport) {
            fail(accountId, MailSyncError.Network)
        } catch (_: ImapException.Protocol) {
            fail(accountId, MailSyncError.Protocol)
        }
    }

    private suspend fun fail(accountId: String, error: MailSyncError): MailSyncResult.Failure {
        database.accountDao().setSyncState(accountId, "ERROR_${error.javaClass.simpleName}")
        return MailSyncResult.Failure(error)
    }

    private suspend fun synchronizeRemoteDrafts(account: AccountEntity) {
        val remoteDrafts = credentialStore.withCredential(account.accountId) { password ->
            imapClient.fetchRemoteDrafts(account.email, password)
        } ?: return
        remoteDrafts.forEach { remote ->
            val localId = remote.draftId ?: "remote-${account.accountId.filter { it.isLetterOrDigit() || it in "._-" }}-${remote.uid}"
            val existing = database.draftDao().observeDraft(localId).first()?.toDraft()
            val remoteTime = remote.updatedAtEpochMillis.takeIf { it > 0L } ?: clock()
            if (existing == null || (existing.status == DraftStatus.DRAFT && existing.updatedAtEpochMillis < remoteTime)) {
                database.draftDao().upsert(
                    MailDraft(
                        draftId = localId,
                        accountId = account.accountId,
                        to = remote.to,
                        cc = remote.cc,
                        bcc = remote.bcc,
                        subject = remote.subject,
                        body = remote.body,
                        inReplyTo = remote.inReplyTo,
                        references = remote.references,
                        status = DraftStatus.DRAFT,
                        updatedAtEpochMillis = remoteTime,
                        attachments = existing?.attachments.orEmpty(),
                    ).toEntity(),
                )
            }
        }
    }

    private suspend fun persistSnapshot(accountId: String, snapshot: GmailInboxSnapshot): List<com.glassmail.core.model.ImapMessageMetadata> {
        val state = database.notificationStateDao().state(accountId)
        val ids = snapshot.messages.map { it.canonicalId(accountId, snapshot.inbox.uidValidity) }
        val existing = if (state?.baselineEstablished == true) database.mailDao().messageIds(ids).toSet() else emptySet()
        val inboxId = "$accountId:INBOX"
        snapshot.messages.chunked(BATCH_SIZE).forEachIndexed { index, batch ->
            persistBatch(
                accountId = accountId,
                inboxId = inboxId,
                snapshot = snapshot,
                batch = batch,
                isFinalBatch = index == snapshot.messages.chunked(BATCH_SIZE).lastIndex,
            )
        }
        if (snapshot.messages.isEmpty()) {
            persistBatch(accountId, inboxId, snapshot, emptyList(), isFinalBatch = true)
        }
        database.notificationStateDao().upsert(NotificationStateEntity(accountId, baselineEstablished = true))
        return if (state?.baselineEstablished == true) snapshot.messages.filterNot { it.canonicalId(accountId, snapshot.inbox.uidValidity) in existing } else emptyList()
    }

    private suspend fun persistBatch(
        accountId: String,
        inboxId: String,
        snapshot: GmailInboxSnapshot,
        batch: List<com.glassmail.core.model.ImapMessageMetadata>,
        isFinalBatch: Boolean,
    ) {
        database.withTransaction {
            val previousCheckpoint = database.syncDao().checkpoint(inboxId)
            val uidValidityChanged = previousCheckpoint != null && previousCheckpoint.uidValidity != snapshot.inbox.uidValidity
            val mailboxes = snapshot.mailboxes.map { mailbox ->
                MailboxEntity(
                    mailboxId = "$accountId:${mailbox.name}",
                    accountId = accountId,
                    remoteName = mailbox.name,
                    uidValidity = if (mailbox.name.equals("INBOX", true)) snapshot.inbox.uidValidity else 0,
                    uidNext = if (mailbox.name.equals("INBOX", true)) snapshot.inbox.uidNext else 0,
                    messageCount = if (mailbox.name.equals("INBOX", true)) snapshot.inbox.messageCount else 0,
                )
            }
            database.mailDao().upsertMailboxes(mailboxes)
            if (uidValidityChanged) database.mailDao().clearMailboxMembership(inboxId)
            val batchIds = batch.map { it.canonicalId(accountId, snapshot.inbox.uidValidity) }
            val existingBodies = if (batchIds.isNotEmpty()) {
                database.mailDao().existingBodyStates(batchIds).associateBy { it.messageId }
            } else {
                emptyMap()
            }
            val messages = batch.map { message ->
                val mId = message.canonicalId(accountId, snapshot.inbox.uidValidity)
                val existing = existingBodies[mId]
                MessageEntity(
                    messageId = mId,
                    accountId = accountId,
                    gmailMessageId = message.gmailMessageId,
                    gmailThreadId = message.gmailThreadId,
                    subject = message.subject,
                    sender = message.sender,
                    sentAtEpochMillis = message.sentAtEpochMillis,
                    sizeBytes = message.sizeBytes,
                    category = message.resolveCategory(),
                    preview = existing?.preview,
                    body = existing?.body,
                    contentKind = existing?.contentKind ?: "PLAIN",
                    bodyDownloadState = existing?.bodyDownloadState ?: com.glassmail.core.database.DownloadState.NOT_FETCHED,
                    listUnsubscribe = message.listUnsubscribe,
                    listUnsubscribePost = message.listUnsubscribePost,
                )
            }
            database.mailDao().upsertMessages(messages)
            database.mailDao().upsertMailboxMessages(batch.map { message ->
                val messageId = message.canonicalId(accountId, snapshot.inbox.uidValidity)
                val resolvedFlags = reconcilePendingFlags(message.flags, database.pendingMutationDao().activeForMessage(messageId))
                MailboxMessageEntity(
                    mailboxId = inboxId,
                    uid = message.uid,
                    messageId = messageId,
                    flags = resolvedFlags.sorted().joinToString(" "),
                    labels = message.labels.sorted().joinToString("\u001F"),
                )
            })
            database.mailDao().upsertLabels(batch.flatMap { message ->
                message.labels.map { label ->
                    MessageLabelEntity(message.canonicalId(accountId, snapshot.inbox.uidValidity), label)
                }
            })
            database.syncDao().upsertCheckpoint(
                SyncCheckpointEntity(
                    mailboxId = inboxId,
                    accountId = accountId,
                    uidValidity = snapshot.inbox.uidValidity,
                    // Persist the requested range boundary, rather than only returned messages.
                    // IMAP UIDs are sparse; an empty range must still make durable progress.
                    highestKnownUid = maxOf(
                        previousCheckpoint?.takeIf { !uidValidityChanged }?.highestKnownUid ?: 0,
                        snapshot.requestedThroughUid,
                        batch.maxOfOrNull { it.uid } ?: 0,
                    ),
                    syncGeneration = (previousCheckpoint?.syncGeneration ?: 0) + if (uidValidityChanged) 1 else 0,
                    lastSuccessfulSyncEpochMillis = if (isFinalBatch) clock() else previousCheckpoint?.lastSuccessfulSyncEpochMillis,
                ),
            )
            if (isFinalBatch) database.accountDao().markSyncSuccess(
                accountId = accountId,
                state = "IDLE",
                gmailExtensionsEnabled = snapshot.supportsGmailExtensions,
                timestamp = clock(),
            )
        }
    }

    private companion object {
        const val BATCH_SIZE = 200
        const val INITIAL_MAIL_LIMIT = 50
        const val DEBUG_ACCOUNT_ID = "debug-fixture"
        const val DAY_MILLIS = 24L * 60 * 60 * 1000
        val CACHE_MESSAGE_PRESETS = setOf(50, 100, 200, 500, 1_000, 2_000, 5_000)
        val CACHE_ATTACHMENT_PRESETS = setOf(100, 250, 500, 1_000, 2_000)
    }

    private fun attachmentPath(attachment: AttachmentEntity): File? {
        val root = attachmentRoot ?: return null
        val accountId = attachment.messageId.split(':').getOrNull(1) ?: return null
        val safeName = sanitizeAttachmentName(attachment.fileName.orEmpty())
        return File(root, "attachments/$accountId/${attachment.attachmentId.hashCode().toUInt().toString(16)}-$safeName")
    }

    private suspend fun updateFlags(messageId: String, mailboxId: String?, transform: (Set<String>) -> Set<String>) {
        val memberships = database.mailDao().membershipsForMessage(messageId)
            .filter { mailboxId == null || it.mailboxId == mailboxId }
        database.mailDao().upsertMailboxMessages(memberships.map { membership ->
            membership.copy(flags = transform(membership.flags.toFlagSet()).sorted().joinToString(" "))
        })
    }
}

private fun CacheConfigEntity.toSettings() = MailCacheSettings(offlineMessageCount, attachmentCacheLimitMb, autoEvictReadOlderThanDays, prefetchUnreadBodies)
private fun MailCacheSettings.toEntity(accountId: String) = CacheConfigEntity(accountId, offlineMessageCount, attachmentCacheLimitMb, autoEvictReadOlderThanDays, prefetchUnreadBodies)

private fun com.glassmail.core.model.ImapMessageMetadata.canonicalId(accountId: String, uidValidity: Long): String =
    gmailMessageId?.let { "gmail:$accountId:$it" } ?: "imap:$accountId:$uidValidity:$uid"

private fun com.glassmail.core.model.ImapMessageMetadata.toListItem(accountId: String, uidValidity: Long) = MailListItem(
    messageId = canonicalId(accountId, uidValidity), threadId = gmailThreadId, sender = sender.orEmpty(),
    subject = subject.orEmpty(), preview = "New message", sentAtEpochMillis = sentAtEpochMillis,
    unread = "\\Seen" !in flags, starred = "\\Flagged" in flags, labels = labels.toList(), hasAttachment = false,
    category = resolveCategory(),
)

private fun MailMutation.type(): String = when (this) {
    is MailMutation.MarkRead -> if (read) "MARK_READ" else "MARK_UNREAD"
    is MailMutation.Star -> if (starred) "STAR" else "UNSTAR"
    is MailMutation.Archive -> "ARCHIVE"
    is MailMutation.Delete -> "DELETE"
    is MailMutation.Label -> if (add) "ADD_LABEL" else "REMOVE_LABEL"
}

private fun MailMutation.payload(): String? = (this as? MailMutation.Label)?.label

private fun Set<String>.withFlag(flag: String, enabled: Boolean): Set<String> = if (enabled) this + flag else this - flag

private fun String.toFlagSet(): Set<String> = split(' ').filter(String::isNotBlank).toSet()

private fun String.toLabels(): List<String> = split('\u001F', ' ').filter(String::isNotBlank).distinct()

private fun List<String>.encodeList(): String = joinToString("\u001F")
private fun String.decodeList(): List<String> = split('\u001F').filter(String::isNotBlank)

private fun MailDraft.toEntity() = DraftEntity(draftId, accountId, to.encodeList(), cc.encodeList(), bcc.encodeList(), subject, body, inReplyTo, references.encodeList(), status.name, updatedAtEpochMillis, attachments.encodeDraftAttachments())
private fun DraftEntity.toDraft() = MailDraft(draftId, accountId, toAddresses.decodeList(), ccAddresses.decodeList(), bccAddresses.decodeList(), subject, body, inReplyTo, references.decodeList(), runCatching { DraftStatus.valueOf(status) }.getOrDefault(DraftStatus.DRAFT), updatedAtEpochMillis, attachments.decodeDraftAttachments())

private fun List<DraftAttachment>.encodeDraftAttachments(): String = joinToString("\u001E") {
    listOf(it.uri, it.fileName, it.mimeType, it.sizeBytes.toString()).joinToString("\u001F")
}

private fun String.decodeDraftAttachments(): List<DraftAttachment> = split('\u001E').mapNotNull { encoded ->
    val fields = encoded.split('\u001F')
    if (fields.size != 4) return@mapNotNull null
    DraftAttachment(fields[0], fields[1], fields[2], fields[3].toLongOrNull() ?: return@mapNotNull null)
}

private fun com.glassmail.core.database.MailboxMessageRow.toListItem() = MailListItem(
    messageId, gmailThreadId, sender.orEmpty(), subject.orEmpty(), preview.orEmpty(), sentAtEpochMillis,
    unread = "\\Seen" !in flags.toFlagSet(), starred = "\\Flagged" in flags.toFlagSet(), labels.toLabels(), hasAttachment,
    category = category,
)

private fun List<com.glassmail.core.database.MailboxMessageRow>.toThreadItems(): List<MailListItem> =
    groupBy { row -> row.gmailThreadId?.takeIf(String::isNotBlank) ?: row.messageId }
        .values
        .map { messages ->
            val latest = messages.maxWithOrNull(compareBy<com.glassmail.core.database.MailboxMessageRow> { it.sentAtEpochMillis ?: Long.MIN_VALUE }.thenBy { it.messageId })!!
            latest.toListItem().copy(
                unread = messages.any { "\\Seen" !in it.flags.toFlagSet() },
                starred = messages.any { "\\Flagged" in it.flags.toFlagSet() },
                labels = messages.flatMap { it.labels.toLabels() }.distinct(),
                hasAttachment = messages.any { it.hasAttachment },
                messageCount = messages.size,
                participantCount = messages.mapNotNull { it.sender?.trim()?.takeIf(String::isNotBlank) }.distinctBy(String::lowercase).size.coerceAtLeast(1),
                threadMessageIds = messages.map { it.messageId },
            )
        }
        .sortedByDescending { it.sentAtEpochMillis ?: Long.MIN_VALUE }

private fun com.glassmail.core.model.ImapMessageMetadata.resolveCategory(): String {
    labels.firstNotNullOfOrNull { label ->
        MailCategory.all.firstOrNull { label.equals("\\Category$it", ignoreCase = true) }
    }?.let { return it }

    val normalizedSender = sender.orEmpty().lowercase()
    val host = normalizedSender.substringAfter('@', "").substringBefore('>').substringBefore(' ')
    val normalizedSubject = subject.orEmpty().lowercase()
    val normalizedListId = listId.orEmpty().lowercase()
    val listMail = precedence.equals("list", ignoreCase = true) || normalizedListId.isNotBlank()
    return when {
        host == "facebook.com" || host.endsWith(".facebook.com") || host == "linkedin.com" || host.endsWith(".linkedin.com") || host == "instagram.com" || host.endsWith(".instagram.com") || host == "twitter.com" || host.endsWith(".twitter.com") || host == "x.com" || host.endsWith(".x.com") -> MailCategory.SOCIAL
        listMail || "discussion" in normalizedSubject || "new reply" in normalizedSubject -> MailCategory.FORUMS
        precedence.equals("bulk", ignoreCase = true) || hasListUnsubscribe -> MailCategory.PROMOTIONS
        normalizedSender.contains("no-reply") || normalizedSender.contains("noreply") || "security alert" in normalizedSubject || "verification code" in normalizedSubject || "receipt" in normalizedSubject || "shipping update" in normalizedSubject -> MailCategory.UPDATES
        "sale" in normalizedSubject || "discount" in normalizedSubject || "special offer" in normalizedSubject || "newsletter" in normalizedSubject -> MailCategory.PROMOTIONS
        else -> MailCategory.PRIMARY
    }
}

private fun String.toFtsMatchExpression(): String? {
    val tokens = Regex("[\\p{L}\\p{N}_]+")
        .findAll(lowercase())
        .map { it.value }
        .distinct()
        .toList()
    return tokens.takeIf { it.isNotEmpty() }?.joinToString(" AND ") { "\"$it\"*" }
}

private fun com.glassmail.core.database.MessageDetailRow.toMailMessage() = MailMessage(
    messageId, gmailThreadId, sender.orEmpty(), subject.orEmpty(), preview.orEmpty(), body,
    contentKind == "HTML", sentAtEpochMillis, "\\Seen" !in flags.toFlagSet(),
    "\\Flagged" in flags.toFlagSet(), labels.toLabels(), listUnsubscribe = listUnsubscribe, listUnsubscribePost = listUnsubscribePost,
)

private fun fixtureMessage(index: Int): MessageEntity {
    val senders = listOf("Ada Lovelace", "Grace Hopper", "Linus Torvalds", "Margaret Hamilton", "Katherine Johnson")
    val sender = senders[index % senders.size]
    val long = if (index % 11 == 0) " — a deliberately long subject to exercise truncation and accessibility with a realistic amount of descriptive text" else ""
    val subject = listOf("Quarterly update", "Design review", "Travel itinerary", "Build status", "Welcome to GlassMail")[index % 5] + long
    val html = index % 4 == 0
    val preview = "Deterministic fixture $index: this local message is available offline for inbox, search, and reader testing."
    return MessageEntity(
        messageId = "debug:$index", accountId = "debug-fixture", gmailMessageId = "debug-$index", gmailThreadId = "thread-${index / 3}",
        subject = subject, sender = sender, sentAtEpochMillis = 1_735_689_600_000L - index * 60_000L, sizeBytes = 1024L + index,
        category = when {
            index % 17 == 0 -> MailCategory.SOCIAL
            index % 13 == 0 -> MailCategory.PROMOTIONS
            index % 11 == 0 -> MailCategory.UPDATES
            index % 7 == 0 -> MailCategory.FORUMS
            else -> MailCategory.PRIMARY
        },
        preview = preview, body = if (html) "<p>$preview</p><p>Remote images are blocked in this local preview.</p>" else preview, contentKind = if (html) "HTML" else "PLAIN",
    )
}

private fun reconcilePendingFlags(serverFlags: Set<String>, mutations: List<PendingMutationEntity>): Set<String> =
    mutations.fold(serverFlags) { flags, mutation ->
        when (mutation.type) {
            "MARK_READ" -> flags.withFlag("\\Seen", true)
            "MARK_UNREAD" -> flags.withFlag("\\Seen", false)
            "STAR" -> flags.withFlag("\\Flagged", true)
            "UNSTAR" -> flags.withFlag("\\Flagged", false)
            "DELETE" -> flags.withFlag("\\Deleted", true)
            else -> flags
        }
    }
