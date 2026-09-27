import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'glassmail_database.g.dart';

const _portableBackupColumns = <String, List<String>>{
  'accounts': [
    'accountId',
    'email',
    'createdAtEpochMillis',
    'syncState',
    'gmailExtensionsEnabled',
    'lastSyncedAtEpochMillis',
  ],
  'mailboxes': [
    'mailboxId',
    'accountId',
    'remoteName',
    'uidValidity',
    'uidNext',
    'messageCount',
  ],
  'messages': [
    'messageId',
    'accountId',
    'gmailMessageId',
    'gmailThreadId',
    'subject',
    'sender',
    'sentAtEpochMillis',
    'sizeBytes',
    'category',
    'preview',
    'body',
    'contentKind',
    'bodyDownloadState',
    'listUnsubscribe',
    'listUnsubscribePost',
  ],
  'mailbox_messages': ['mailboxId', 'uid', 'messageId', 'flags', 'labels'],
  'message_labels': ['messageId', 'label'],
  'attachments': [
    'attachmentId',
    'messageId',
    'partId',
    'fileName',
    'mimeType',
    'sizeBytes',
    'downloadState',
    'lastAccessedAtEpochMillis',
  ],
  'cache_config': [
    'accountId',
    'offlineMessageCount',
    'attachmentCacheLimitMb',
    'autoEvictReadOlderThanDays',
    'prefetchUnreadBodies',
  ],
  'storage_quota': ['accountId', 'usedKb', 'limitKb', 'checkedAtEpochMillis'],
  'sync_checkpoints': [
    'mailboxId',
    'accountId',
    'uidValidity',
    'highestKnownUid',
    'syncGeneration',
    'lastSuccessfulSyncEpochMillis',
  ],
  'drafts': [
    'draftId',
    'accountId',
    'toAddresses',
    'ccAddresses',
    'bccAddresses',
    'subject',
    'body',
    'inReplyTo',
    'references',
    'status',
    'updatedAtEpochMillis',
    'attachments',
  ],
  'notification_state': ['accountId', 'baselineEstablished'],
};

@DriftDatabase(
  include: {'room_v10.drift'},
)
class GlassMailDatabase extends _$GlassMailDatabase {
  GlassMailDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  GlassMailDatabase.forTesting(super.executor);

  // These operations mirror the current Room DAOs. Streams are used for
  // queries Room exposes as Flow; single-shot methods mirror suspend queries.

  Future<void> saveAccount(AccountsCompanion account) =>
      into(accounts).insertOnConflictUpdate(account);

  Future<Account?> accountById(String accountId) =>
      (select(accounts)..where((row) => row.accountId.equals(accountId)))
          .getSingleOrNull();

  Stream<List<Account>> watchAccounts() => (select(accounts)
        ..orderBy([(row) => OrderingTerm.asc(row.createdAtEpochMillis)]))
      .watch();

  Stream<List<Mailboxe>> watchMailboxesForAccount(String accountId) =>
      (select(mailboxes)
            ..where((row) => row.accountId.equals(accountId))
            ..orderBy([(row) => OrderingTerm.asc(row.remoteName)]))
          .watch();

  Future<int> deleteAccount(String accountId) =>
      (delete(accounts)..where((row) => row.accountId.equals(accountId))).go();

  Future<bool> claimDraftForSend({
    required String draftId,
    required String expectedStatus,
    required int updatedAtEpochMillis,
  }) async =>
      await (update(drafts)
            ..where((row) =>
                row.draftId.equals(draftId) &
                row.status.equals(expectedStatus)))
          .write(DraftsCompanion(
        status: Value('SENDING'),
        updatedAtEpochMillis: Value(updatedAtEpochMillis),
      )) >
      0;

  Future<bool> restoreQueuedDraft({
    required String draftId,
    required int updatedAtEpochMillis,
  }) async =>
      await (update(drafts)
            ..where((row) =>
                row.draftId.equals(draftId) & row.status.equals('QUEUED')))
          .write(DraftsCompanion(
        status: Value('DRAFT'),
        updatedAtEpochMillis: Value(updatedAtEpochMillis),
      )) >
      0;

  Future<int> setAccountSyncState(String accountId, String state) =>
      (update(accounts)..where((row) => row.accountId.equals(accountId)))
          .write(AccountsCompanion(syncState: Value(state)));

  Future<int> markAccountSyncSuccess({
    required String accountId,
    required String state,
    required bool gmailExtensionsEnabled,
    required int timestamp,
  }) =>
      (update(accounts)..where((row) => row.accountId.equals(accountId))).write(
        AccountsCompanion(
          syncState: Value(state),
          gmailExtensionsEnabled: Value(gmailExtensionsEnabled ? 1 : 0),
          lastSyncedAtEpochMillis: Value(timestamp),
        ),
      );

  Stream<AccountSyncSummaryRow?> watchAccountSummary(String accountId) =>
      customSelect(
        "SELECT a.accountId, a.email, a.syncState, a.gmailExtensionsEnabled, "
        "a.lastSyncedAtEpochMillis, COUNT(mm.uid) AS messageCount "
        "FROM accounts a LEFT JOIN mailboxes b ON b.accountId = a.accountId "
        "AND b.remoteName = 'INBOX' LEFT JOIN mailbox_messages mm "
        'ON mm.mailboxId = b.mailboxId WHERE a.accountId = ? '
        'GROUP BY a.accountId',
        variables: [Variable.withString(accountId)],
        readsFrom: {accounts, mailboxes, mailboxMessages},
      ).watchSingleOrNull().map(
            (row) =>
                row == null ? null : AccountSyncSummaryRow.fromData(row.data),
          );

  Future<int> countMessagesForAccount(String accountId) async =>
      (await customSelect(
        'SELECT COUNT(*) AS count FROM messages WHERE accountId = ?',
        variables: [Variable.withString(accountId)],
        readsFrom: {messages},
      ).getSingle())
          .read<int>('count');

  /// Exports all local mail rows except pending mutations. Mutations are not
  /// replayed after restore because the remote server may already have applied
  /// them before the backup was created.
  Future<Map<String, Object?>> exportPortableBackupRows() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in _portableBackupColumns.entries) {
      final columns = entry.value.map((column) => '"$column"').join(', ');
      final rows = await customSelect(
        'SELECT $columns FROM "${entry.key}"',
      ).get();
      tables[entry.key] = rows
          .map((row) => Map<String, Object?>.from(row.data))
          .toList(growable: false);
    }
    return {'schemaVersion': schemaVersion, 'tables': tables};
  }

  /// Restores into a fresh Flutter store only. The operation is transactional;
  /// account passwords and pending remote operations are deliberately absent.
  Future<void> restorePortableBackupRows(Map<String, dynamic> snapshot) async {
    if (snapshot['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Backup schema ${snapshot['schemaVersion']} is not supported.',
      );
    }
    if ((await watchAccounts().first).isNotEmpty) {
      throw StateError(
        'Remove existing accounts before restoring a GlassMail backup.',
      );
    }
    final rawTables = snapshot['tables'];
    if (rawTables is! Map<String, dynamic> ||
        rawTables.keys
            .toSet()
            .difference(_portableBackupColumns.keys.toSet())
            .isNotEmpty ||
        _portableBackupColumns.keys.any((key) => !rawTables.containsKey(key))) {
      throw const FormatException('Backup table set is invalid.');
    }

    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in _portableBackupColumns.entries) {
      final rawRows = rawTables[entry.key];
      if (rawRows is! List || rawRows.length > 100000) {
        throw FormatException('Backup rows for ${entry.key} are invalid.');
      }
      tables[entry.key] = rawRows.map((rawRow) {
        if (rawRow is! Map<String, dynamic> ||
            rawRow.keys.toSet().difference(entry.value.toSet()).isNotEmpty ||
            entry.value.any((column) => !rawRow.containsKey(column))) {
          throw FormatException('Backup row for ${entry.key} is invalid.');
        }
        for (final value in rawRow.values) {
          if (value != null && value is! String && value is! num) {
            throw FormatException('Backup value for ${entry.key} is invalid.');
          }
        }
        return Map<String, Object?>.from(rawRow);
      }).toList(growable: false);
    }
    if (tables['accounts']!.isEmpty) {
      throw const FormatException('Backup does not contain an account.');
    }

    await transaction(() async {
      for (final entry in _portableBackupColumns.entries) {
        final columns = entry.value;
        final quotedColumns = columns.map((column) => '"$column"').join(', ');
        final placeholders = List.filled(columns.length, '?').join(', ');
        for (final sourceRow in tables[entry.key]!) {
          final row = Map<String, Object?>.from(sourceRow);
          if (entry.key == 'accounts') {
            row['syncState'] = 'NEEDS_CREDENTIAL';
          } else if (entry.key == 'drafts') {
            final status = row['status'];
            if (status == 'QUEUED') row['status'] = 'DRAFT';
            if (status == 'SENDING') row['status'] = 'UNCERTAIN';
          }
          await customStatement(
            'INSERT INTO "${entry.key}" ($quotedColumns) '
            'VALUES ($placeholders)',
            columns.map((column) => row[column]).toList(growable: false),
          );
        }
      }
      final violations = await customSelect('PRAGMA foreign_key_check').get();
      if (violations.isNotEmpty) {
        throw StateError('Backup contains invalid foreign-key references.');
      }
    });
    markTablesUpdated([
      accounts,
      mailboxes,
      messages,
      mailboxMessages,
      messageLabels,
      attachments,
      cacheConfig,
      storageQuota,
      syncCheckpoints,
      drafts,
      notificationState,
    ]);
  }

  Future<void> saveMailboxes(Iterable<MailboxesCompanion> rows) async {
    await batch(
        (batch) => batch.insertAllOnConflictUpdate(mailboxes, rows.toList()));
  }

  Future<String?> mailboxRemoteName(String mailboxId) async =>
      (await (selectOnly(mailboxes)
                ..addColumns([mailboxes.remoteName])
                ..where(mailboxes.mailboxId.equals(mailboxId)))
              .getSingleOrNull())
          ?.read(mailboxes.remoteName);

  Future<void> saveMessages(Iterable<MessagesCompanion> rows) async {
    await batch(
        (batch) => batch.insertAllOnConflictUpdate(messages, rows.toList()));
  }

  Future<int> evictExcessBodies(String accountId, int keepCount) =>
      customUpdate(
        "UPDATE messages SET body = NULL, contentKind = 'PLAIN', "
        "bodyDownloadState = 'NOT_FETCHED' WHERE accountId = ? "
        'AND body IS NOT NULL AND messageId IN (SELECT m.messageId FROM messages m '
        'WHERE m.accountId = ? AND m.body IS NOT NULL '
        "AND NOT EXISTS (SELECT 1 FROM mailbox_messages mm WHERE mm.messageId = m.messageId "
        "AND instr(mm.flags, char(92) || 'Seen') = 0) "
        "AND NOT EXISTS (SELECT 1 FROM mailbox_messages mm WHERE mm.messageId = m.messageId "
        "AND instr(mm.flags, char(92) || 'Flagged') > 0) "
        'ORDER BY m.sentAtEpochMillis DESC LIMIT -1 OFFSET ?)',
        variables: [
          Variable.withString(accountId),
          Variable.withString(accountId),
          Variable.withInt(keepCount),
        ],
        updates: {messages},
      );

  Future<int> evictOldReadBodies(String accountId, int beforeEpochMillis) =>
      customUpdate(
        "UPDATE messages SET body = NULL, contentKind = 'PLAIN', "
        "bodyDownloadState = 'NOT_FETCHED' WHERE accountId = ? "
        'AND body IS NOT NULL AND sentAtEpochMillis < ? '
        'AND NOT EXISTS (SELECT 1 FROM mailbox_messages mm '
        'WHERE mm.messageId = messages.messageId AND '
        "(instr(mm.flags, char(92) || 'Seen') = 0 OR "
        "instr(mm.flags, char(92) || 'Flagged') > 0))",
        variables: [
          Variable.withString(accountId),
          Variable.withInt(beforeEpochMillis),
        ],
        updates: {messages},
      );

  Future<int> updateMessageBody({
    required String messageId,
    required String? body,
    required String? preview,
    required String contentKind,
    required String downloadState,
  }) =>
      (update(messages)..where((row) => row.messageId.equals(messageId))).write(
        MessagesCompanion(
          body: Value(body),
          preview: Value(preview),
          contentKind: Value(contentKind),
          bodyDownloadState: Value(downloadState),
        ),
      );

  Future<String?> bodyDownloadState(String messageId) async =>
      (await (selectOnly(messages)
                ..addColumns([messages.bodyDownloadState])
                ..where(messages.messageId.equals(messageId)))
              .getSingleOrNull())
          ?.read(messages.bodyDownloadState);

  Future<List<MessageBodyStateRow>> existingBodyStates(
    Iterable<String> messageIds,
  ) async {
    final ids = messageIds.toList();
    if (ids.isEmpty) return const [];
    final rows =
        await (select(messages)..where((row) => row.messageId.isIn(ids))).get();
    return rows
        .map((row) => MessageBodyStateRow(
              row.messageId,
              row.preview,
              row.body,
              row.contentKind,
              row.bodyDownloadState,
            ))
        .toList();
  }

  Future<int> countMailboxMessages(String mailboxId) async =>
      (await customSelect(
        'SELECT COUNT(*) AS count FROM mailbox_messages WHERE mailboxId = ?',
        variables: [Variable.withString(mailboxId)],
        readsFrom: {mailboxMessages},
      ).getSingle())
          .read<int>('count');

  Future<int?> inboxMessageCount(String mailboxId) async =>
      (await (selectOnly(mailboxes)
                ..addColumns([mailboxes.messageCount])
                ..where(mailboxes.mailboxId.equals(mailboxId)))
              .getSingleOrNull())
          ?.read(mailboxes.messageCount);

  Future<void> saveMailboxMessages(
      Iterable<MailboxMessagesCompanion> rows) async {
    await batch((batch) =>
        batch.insertAllOnConflictUpdate(mailboxMessages, rows.toList()));
  }

  Future<void> saveLabels(Iterable<MessageLabelsCompanion> rows) async {
    await batch((batch) =>
        batch.insertAllOnConflictUpdate(messageLabels, rows.toList()));
  }

  Future<int> removeLabel(String messageId, String label) =>
      (delete(messageLabels)
            ..where((row) =>
                row.messageId.equals(messageId) & row.label.equals(label)))
          .go();

  Future<void> saveAttachments(Iterable<AttachmentsCompanion> rows) async {
    await batch(
        (batch) => batch.insertAllOnConflictUpdate(attachments, rows.toList()));
  }

  Future<Attachment?> attachmentById(String attachmentId) =>
      (select(attachments)
            ..where((row) => row.attachmentId.equals(attachmentId))
            ..limit(1))
          .getSingleOrNull();

  Future<int> setAttachmentDownloadState(String attachmentId, String state) =>
      (update(attachments)
            ..where((row) => row.attachmentId.equals(attachmentId)))
          .write(AttachmentsCompanion(downloadState: Value(state)));

  Future<int> setAttachmentDownloadStates(
          Iterable<String> attachmentIds, String state) =>
      (update(attachments)
            ..where((row) => row.attachmentId.isIn(attachmentIds)))
          .write(AttachmentsCompanion(downloadState: Value(state)));

  Future<int> markAttachmentAccessed(String attachmentId, int timestamp) =>
      (update(attachments)
            ..where((row) => row.attachmentId.equals(attachmentId)))
          .write(AttachmentsCompanion(
              lastAccessedAtEpochMillis: Value(timestamp)));

  Future<List<Attachment>> cachedAttachments(String accountId) => customSelect(
        'SELECT a.* FROM attachments a JOIN messages m ON m.messageId = a.messageId '
        "WHERE m.accountId = ? AND a.downloadState = 'AVAILABLE' "
        'ORDER BY a.lastAccessedAtEpochMillis ASC',
        variables: [Variable.withString(accountId)],
        readsFrom: {attachments, messages},
      ).map((row) => attachments.map(row.data)).get();

  Future<int> clearMailboxMembership(String mailboxId) =>
      (delete(mailboxMessages)..where((row) => row.mailboxId.equals(mailboxId)))
          .go();

  Future<int> removeMailboxMembership(String mailboxId, String messageId) =>
      (delete(mailboxMessages)
            ..where((row) =>
                row.mailboxId.equals(mailboxId) &
                row.messageId.equals(messageId)))
          .go();

  Future<List<MailboxMessage>> membershipsForMessage(String messageId) =>
      (select(mailboxMessages)..where((row) => row.messageId.equals(messageId)))
          .get();

  Future<List<String>> messageIds(Iterable<String> messageIds) async {
    final ids = messageIds.toList();
    if (ids.isEmpty) return const [];
    final rows =
        await (select(messages)..where((row) => row.messageId.isIn(ids))).get();
    return rows.map((row) => row.messageId).toList();
  }

  Stream<List<MailboxMessageRow>> watchInbox(
    String mailboxId, {
    String? category,
    int? limit,
    int offset = 0,
  }) {
    final categoryFilter = category == null
        ? ''
        : 'AND (m.category = ? OR EXISTS(SELECT 1 FROM messages categorized '
            'WHERE categorized.accountId = m.accountId '
            'AND categorized.gmailThreadId = m.gmailThreadId '
            'AND categorized.category = ?))';
    final paging = limit == null ? '' : 'LIMIT ? OFFSET ?';
    return customSelect(
      'SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, '
      'm.sentAtEpochMillis, mm.flags, mm.labels, '
      'EXISTS(SELECT 1 FROM attachments a WHERE a.messageId = m.messageId) '
      'AS hasAttachment, m.category FROM mailbox_messages mm '
      'JOIN messages m ON m.messageId = mm.messageId '
      'WHERE mm.mailboxId = ? $categoryFilter '
      'ORDER BY m.sentAtEpochMillis DESC, mm.uid DESC $paging',
      variables: [
        Variable.withString(mailboxId),
        if (category != null) ...[
          Variable.withString(category),
          Variable.withString(category),
        ],
        if (limit != null) Variable.withInt(limit),
        if (limit != null) Variable.withInt(offset),
      ],
      readsFrom: {mailboxMessages, messages, attachments},
    ).watch().map((rows) =>
        rows.map((row) => MailboxMessageRow.fromData(row.data)).toList());
  }

  Stream<List<CategoryUnreadCountRow>> watchCategoryUnreadCounts(
    String mailboxId,
  ) =>
      customSelect(
        'SELECT m.category, COUNT(*) AS unreadCount FROM mailbox_messages mm '
        'JOIN messages m ON m.messageId = mm.messageId '
        'WHERE mm.mailboxId = ? '
        "AND instr(mm.flags, char(92) || 'Seen') = 0 GROUP BY m.category",
        variables: [Variable.withString(mailboxId)],
        readsFrom: {mailboxMessages, messages},
      ).watch().map(
            (rows) => rows
                .map((row) => CategoryUnreadCountRow.fromData(row.data))
                .toList(),
          );

  Stream<MessageDetailRow?> watchMessage(String messageId) => customSelect(
        'SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, '
        'm.body, m.contentKind, m.sentAtEpochMillis, mm.flags, mm.labels, '
        'm.listUnsubscribe, m.listUnsubscribePost FROM messages m '
        'JOIN mailbox_messages mm ON mm.messageId = m.messageId '
        'WHERE m.messageId = ? LIMIT 1',
        variables: [Variable.withString(messageId)],
        readsFrom: {messages, mailboxMessages},
      ).watch().map((rows) =>
          rows.isEmpty ? null : MessageDetailRow.fromData(rows.first.data));

  Stream<List<MessageDetailRow>> watchThread(
    String messageId, {
    String? mailboxId,
  }) {
    final mailboxFilter = mailboxId == null ? '' : 'AND mm.mailboxId = ? ';
    return customSelect(
      'SELECT DISTINCT m.messageId, m.gmailThreadId, m.sender, m.subject, '
      'm.preview, m.body, m.contentKind, m.sentAtEpochMillis, mm.flags, '
      'mm.labels, m.listUnsubscribe, m.listUnsubscribePost '
      'FROM messages m JOIN mailbox_messages mm ON mm.messageId = m.messageId '
      'WHERE (m.messageId = ? OR (m.gmailThreadId IS NOT NULL '
      "AND m.gmailThreadId != '' AND m.gmailThreadId = (SELECT target.gmailThreadId "
      'FROM messages target WHERE target.messageId = ? '
      "AND target.gmailThreadId IS NOT NULL AND target.gmailThreadId != ''))) "
      '$mailboxFilter ORDER BY m.sentAtEpochMillis ASC',
      variables: [
        Variable.withString(messageId),
        Variable.withString(messageId),
        if (mailboxId != null) Variable.withString(mailboxId),
      ],
      readsFrom: {messages, mailboxMessages},
    ).watch().map((rows) =>
        rows.map((row) => MessageDetailRow.fromData(row.data)).toList());
  }

  Stream<List<Attachment>> watchAttachments(String messageId) =>
      (select(attachments)
            ..where((row) => row.messageId.equals(messageId))
            ..orderBy([(row) => OrderingTerm.asc(row.partId)]))
          .watch();

  Stream<List<MailboxMessageRow>> search(String mailboxId, String ftsQuery) =>
      customSelect(
        'WITH matched_threads AS (SELECT DISTINCT m.gmailThreadId FROM '
        'messages_fts JOIN messages m ON m.rowid = messages_fts.rowid '
        'WHERE messages_fts MATCH ? AND m.gmailThreadId IS NOT NULL), '
        'matched_messages AS (SELECT m.messageId FROM messages_fts '
        'JOIN messages m ON m.rowid = messages_fts.rowid '
        'WHERE messages_fts MATCH ?) '
        'SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, '
        'm.sentAtEpochMillis, mm.flags, mm.labels, '
        'EXISTS(SELECT 1 FROM attachments a WHERE a.messageId = m.messageId) '
        'AS hasAttachment, m.category FROM messages m '
        'JOIN mailbox_messages mm ON mm.messageId = m.messageId '
        'WHERE mm.mailboxId = ? AND (m.messageId IN matched_messages '
        'OR m.gmailThreadId IN matched_threads) '
        'ORDER BY m.sentAtEpochMillis DESC LIMIT 500',
        variables: [
          Variable.withString(ftsQuery),
          Variable.withString(ftsQuery),
          Variable.withString(mailboxId),
        ],
        readsFrom: {messages, mailboxMessages, attachments},
      ).watch().map((rows) =>
          rows.map((row) => MailboxMessageRow.fromData(row.data)).toList());

  /// Searches every normalized token. FTS4 defaults multi-term queries to OR,
  /// so separate parameterized MATCH queries are intersected for AND behavior.
  Stream<List<MailboxMessageRow>> searchTerms(
    String mailboxId,
    List<String> ftsTerms,
  ) {
    if (ftsTerms.isEmpty) return Stream.value(const []);
    final matchedRows = List.filled(
      ftsTerms.length,
      'SELECT rowid FROM messages_fts WHERE messages_fts MATCH ?',
    ).join(' INTERSECT ');
    return customSelect(
      'WITH matched_rows AS ($matchedRows), '
      'matched_threads AS (SELECT DISTINCT m.gmailThreadId FROM messages m '
      'JOIN matched_rows hit ON hit.rowid = m.rowid '
      'WHERE m.gmailThreadId IS NOT NULL), '
      'matched_messages AS (SELECT m.messageId FROM messages m '
      'JOIN matched_rows hit ON hit.rowid = m.rowid) '
      'SELECT m.messageId, m.gmailThreadId, m.sender, m.subject, m.preview, '
      'm.sentAtEpochMillis, mm.flags, mm.labels, '
      'EXISTS(SELECT 1 FROM attachments a WHERE a.messageId = m.messageId) '
      'AS hasAttachment, m.category FROM messages m '
      'JOIN mailbox_messages mm ON mm.messageId = m.messageId '
      'WHERE mm.mailboxId = ? AND (m.messageId IN matched_messages '
      'OR m.gmailThreadId IN matched_threads) '
      'ORDER BY m.sentAtEpochMillis DESC LIMIT 500',
      variables: [
        ...ftsTerms.map(Variable.withString),
        Variable.withString(mailboxId),
      ],
      readsFrom: {messages, mailboxMessages, attachments},
    ).watch().map((rows) =>
        rows.map((row) => MailboxMessageRow.fromData(row.data)).toList());
  }

  Future<void> commitMailboxSnapshot({
    required MailboxesCompanion mailbox,
    required Iterable<MessagesCompanion> messageRows,
    required Iterable<MailboxMessagesCompanion> memberships,
    required SyncCheckpointsCompanion checkpoint,
    required bool replaceMembership,
    NotificationStateCompanion? notificationState,
    bool? gmailExtensionsEnabled,
    int? successfulSyncTimestamp,
  }) =>
      transaction(() async {
        final rows = messageRows.toList();
        final ids = rows.map((row) => row.messageId.value).toList();
        final existingBodies = {
          for (final body in await existingBodyStates(ids))
            body.messageId: body,
        };
        final preservedRows = rows.map((row) {
          final existing = existingBodies[row.messageId.value];
          if (existing == null) return row;
          return row.copyWith(
            preview: Value(existing.preview),
            body: Value(existing.body),
            contentKind: Value(existing.contentKind),
            bodyDownloadState: Value(existing.bodyDownloadState),
          );
        }).toList();

        final mergedMemberships = <MailboxMessagesCompanion>[];
        final labelsByMessage = <String, Set<String>>{};
        for (final membership in memberships) {
          final mailboxId = membership.mailboxId.value;
          final messageId = membership.messageId.value;
          final flags = membership.flags.value
              .split(' ')
              .where((flag) => flag.isNotEmpty)
              .toSet();
          final labels = membership.labels.value
              .split('\u001f')
              .where((label) => label.isNotEmpty)
              .toSet();
          var hiddenByPendingRemoval = false;
          final pending = await activeMutationsForMessage(messageId);
          for (final mutation in pending.where((mutation) =>
              mutation.mailboxId == null || mutation.mailboxId == mailboxId)) {
            switch (mutation.type) {
              case 'MARK_READ':
                flags.add(r'\Seen');
              case 'MARK_UNREAD':
                flags.remove(r'\Seen');
              case 'STAR':
                flags.add(r'\Flagged');
              case 'UNSTAR':
                flags.remove(r'\Flagged');
              case 'ARCHIVE':
              case 'DELETE':
                hiddenByPendingRemoval = true;
              case 'ADD_LABEL':
                if (mutation.payload != null) labels.add(mutation.payload!);
              case 'REMOVE_LABEL':
                if (mutation.payload != null) labels.remove(mutation.payload!);
            }
          }
          labelsByMessage.putIfAbsent(messageId, () => {}).addAll(labels);
          if (!hiddenByPendingRemoval) {
            mergedMemberships.add(membership.copyWith(
              flags: Value((flags.toList()..sort()).join(' ')),
              labels: Value((labels.toList()..sort()).join('\u001f')),
            ));
          }
        }

        await into(mailboxes).insertOnConflictUpdate(mailbox);
        await batch((batch) => batch.insertAllOnConflictUpdate(
              messages,
              preservedRows,
            ));
        if (replaceMembership) {
          await (delete(mailboxMessages)
                ..where((row) => row.mailboxId.equals(mailbox.mailboxId.value)))
              .go();
        }
        await batch((batch) => batch.insertAllOnConflictUpdate(
              mailboxMessages,
              mergedMemberships,
            ));
        if (ids.isNotEmpty) {
          await (delete(messageLabels)..where((row) => row.messageId.isIn(ids)))
              .go();
          final labelRows = [
            for (final entry in labelsByMessage.entries)
              for (final label in entry.value)
                MessageLabelsCompanion.insert(
                  messageId: entry.key,
                  label: label,
                ),
          ];
          if (labelRows.isNotEmpty) {
            await batch((batch) => batch.insertAllOnConflictUpdate(
                  messageLabels,
                  labelRows,
                ));
          }
        }
        await into(syncCheckpoints).insertOnConflictUpdate(checkpoint);
        if (notificationState != null) {
          await into(this.notificationState)
              .insertOnConflictUpdate(notificationState);
        }
        if (gmailExtensionsEnabled != null && successfulSyncTimestamp != null) {
          await markAccountSyncSuccess(
            accountId: mailbox.accountId.value,
            state: 'IDLE',
            gmailExtensionsEnabled: gmailExtensionsEnabled,
            timestamp: successfulSyncTimestamp,
          );
        }
      });

  Stream<CacheConfigData?> watchCacheConfig(String accountId) =>
      (select(cacheConfig)..where((row) => row.accountId.equals(accountId)))
          .watchSingleOrNull();

  Future<CacheConfigData?> cacheConfigForAccount(String accountId) =>
      (select(cacheConfig)..where((row) => row.accountId.equals(accountId)))
          .getSingleOrNull();

  Future<void> saveCacheConfig(CacheConfigCompanion config) =>
      into(cacheConfig).insertOnConflictUpdate(config);

  Stream<StorageQuotaData?> watchStorageQuota(String accountId) =>
      (select(storageQuota)..where((row) => row.accountId.equals(accountId)))
          .watchSingleOrNull();

  Future<void> saveStorageQuota(StorageQuotaCompanion quota) =>
      into(storageQuota).insertOnConflictUpdate(quota);

  Future<SyncCheckpoint?> checkpoint(String mailboxId) =>
      (select(syncCheckpoints)..where((row) => row.mailboxId.equals(mailboxId)))
          .getSingleOrNull();

  Future<int> deleteCheckpoint(String mailboxId) =>
      (delete(syncCheckpoints)..where((row) => row.mailboxId.equals(mailboxId)))
          .go();

  Future<void> saveCheckpoint(SyncCheckpointsCompanion checkpoint) =>
      into(syncCheckpoints).insertOnConflictUpdate(checkpoint);

  Stream<List<Draft>> watchDrafts(String accountId) => (select(drafts)
        ..where((row) => row.accountId.equals(accountId))
        ..orderBy([(row) => OrderingTerm.desc(row.updatedAtEpochMillis)]))
      .watch();

  Stream<Draft?> watchDraft(String draftId) =>
      (select(drafts)..where((row) => row.draftId.equals(draftId)))
          .watchSingleOrNull();

  Future<void> saveDraft(DraftsCompanion draft) =>
      into(drafts).insertOnConflictUpdate(draft);

  Future<int> deleteDraft(String draftId) =>
      (delete(drafts)..where((row) => row.draftId.equals(draftId))).go();

  Future<NotificationStateData?> notificationStateForAccount(
          String accountId) =>
      (select(notificationState)
            ..where((row) => row.accountId.equals(accountId)))
          .getSingleOrNull();

  Future<void> saveNotificationState(NotificationStateCompanion state) =>
      into(notificationState).insertOnConflictUpdate(state);

  Future<int> deleteNotificationState(String accountId) =>
      (delete(notificationState)
            ..where((row) => row.accountId.equals(accountId)))
          .go();

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await _createFts4();
        },
        onUpgrade: (migrator, from, to) async {
          throw StateError(
            'No Flutter database upgrade from schema $from to $to is defined. '
            'The Flutter store is fresh-only; Room databases are not imported.',
          );
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> insertPendingMutation(PendingMutationsCompanion mutation) =>
      into(pendingMutations).insert(mutation);

  Future<List<PendingMutation>> activeMutationsForAccount(String accountId) =>
      (select(pendingMutations)
            ..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.state.isIn(const ['PENDING', 'IN_FLIGHT']),
            )
            ..orderBy([
              (row) => OrderingTerm.asc(row.createdAtEpochMillis),
              (row) => OrderingTerm.asc(row.mutationId),
            ]))
          .get();

  Future<List<PendingMutation>> activeMutationsForMessage(String messageId) =>
      (select(pendingMutations)
            ..where(
              (row) =>
                  row.messageId.equals(messageId) &
                  row.state.isIn(const ['PENDING', 'IN_FLIGHT']),
            )
            ..orderBy([
              (row) => OrderingTerm.asc(row.createdAtEpochMillis),
              (row) => OrderingTerm.asc(row.mutationId),
            ]))
          .get();

  Future<int> updatePendingMutationState({
    required String mutationId,
    required String state,
    required int retryCount,
    required String? errorCode,
  }) =>
      (update(pendingMutations)
            ..where((row) => row.mutationId.equals(mutationId)))
          .write(
        PendingMutationsCompanion(
          state: Value(state),
          retryCount: Value(retryCount),
          lastErrorCode: Value(errorCode),
        ),
      );

  Future<int> deletePendingMutation(String mutationId) =>
      (delete(pendingMutations)
            ..where((row) => row.mutationId.equals(mutationId)))
          .go();

  Future<PendingMutation?> undoableArchiveForMessage(String messageId) =>
      (select(pendingMutations)
            ..where(
              (row) =>
                  row.messageId.equals(messageId) &
                  row.type.equals('ARCHIVE') &
                  row.state.equals('PENDING'),
            )
            ..orderBy([
              (row) => OrderingTerm.desc(row.createdAtEpochMillis),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<void> _createFts4() async {
    await customStatement('''
      CREATE VIRTUAL TABLE messages_fts USING FTS4(
        subject TEXT, sender TEXT, preview TEXT, body TEXT,
        tokenize=unicode61,
        content='messages'
      )
    ''');
    await customStatement('''
      CREATE TRIGGER room_fts_content_sync_messages_fts_BEFORE_UPDATE
      BEFORE UPDATE ON messages
      BEGIN
        DELETE FROM messages_fts WHERE docid = OLD.rowid;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER room_fts_content_sync_messages_fts_BEFORE_DELETE
      BEFORE DELETE ON messages
      BEGIN
        DELETE FROM messages_fts WHERE docid = OLD.rowid;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER room_fts_content_sync_messages_fts_AFTER_UPDATE
      AFTER UPDATE ON messages
      BEGIN
        INSERT INTO messages_fts(docid, subject, sender, preview, body)
        VALUES (NEW.rowid, NEW.subject, NEW.sender, NEW.preview, NEW.body);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER room_fts_content_sync_messages_fts_AFTER_INSERT
      AFTER INSERT ON messages
      BEGIN
        INSERT INTO messages_fts(docid, subject, sender, preview, body)
        VALUES (NEW.rowid, NEW.subject, NEW.sender, NEW.preview, NEW.body);
      END
    ''');
  }

  static QueryExecutor _openConnection() => driftDatabase(
        name: 'glassmail_flutter.db',
        native: DriftNativeOptions(
            databaseDirectory: getApplicationSupportDirectory),
      );
}

final class AccountSyncSummaryRow {
  const AccountSyncSummaryRow({
    required this.accountId,
    required this.email,
    required this.syncState,
    required this.gmailExtensionsEnabled,
    required this.lastSyncedAtEpochMillis,
    required this.messageCount,
  });

  factory AccountSyncSummaryRow.fromData(Map<String, Object?> data) =>
      AccountSyncSummaryRow(
        accountId: data['accountId']! as String,
        email: data['email']! as String,
        syncState: data['syncState']! as String,
        gmailExtensionsEnabled: data['gmailExtensionsEnabled']! as int != 0,
        lastSyncedAtEpochMillis: data['lastSyncedAtEpochMillis'] as int?,
        messageCount: data['messageCount']! as int,
      );

  final String accountId;
  final String email;
  final String syncState;
  final bool gmailExtensionsEnabled;
  final int? lastSyncedAtEpochMillis;
  final int messageCount;
}

final class MailboxMessageRow {
  const MailboxMessageRow({
    required this.messageId,
    required this.gmailThreadId,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.sentAtEpochMillis,
    required this.flags,
    required this.labels,
    required this.hasAttachment,
    required this.category,
  });

  factory MailboxMessageRow.fromData(Map<String, Object?> data) =>
      MailboxMessageRow(
        messageId: data['messageId']! as String,
        gmailThreadId: data['gmailThreadId'] as String?,
        sender: data['sender'] as String?,
        subject: data['subject'] as String?,
        preview: data['preview'] as String?,
        sentAtEpochMillis: data['sentAtEpochMillis'] as int?,
        flags: data['flags']! as String,
        labels: data['labels']! as String,
        hasAttachment: data['hasAttachment']! as int != 0,
        category: data['category']! as String,
      );

  final String messageId;
  final String? gmailThreadId;
  final String? sender;
  final String? subject;
  final String? preview;
  final int? sentAtEpochMillis;
  final String flags;
  final String labels;
  final bool hasAttachment;
  final String category;
}

final class CategoryUnreadCountRow {
  const CategoryUnreadCountRow(this.category, this.unreadCount);

  factory CategoryUnreadCountRow.fromData(Map<String, Object?> data) =>
      CategoryUnreadCountRow(
        data['category']! as String,
        data['unreadCount']! as int,
      );

  final String category;
  final int unreadCount;
}

final class MessageDetailRow {
  const MessageDetailRow({
    required this.messageId,
    required this.gmailThreadId,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.body,
    required this.contentKind,
    required this.sentAtEpochMillis,
    required this.flags,
    required this.labels,
    required this.listUnsubscribe,
    required this.listUnsubscribePost,
  });

  factory MessageDetailRow.fromData(Map<String, Object?> data) =>
      MessageDetailRow(
        messageId: data['messageId']! as String,
        gmailThreadId: data['gmailThreadId'] as String?,
        sender: data['sender'] as String?,
        subject: data['subject'] as String?,
        preview: data['preview'] as String?,
        body: data['body'] as String?,
        contentKind: data['contentKind']! as String,
        sentAtEpochMillis: data['sentAtEpochMillis'] as int?,
        flags: data['flags']! as String,
        labels: data['labels']! as String,
        listUnsubscribe: data['listUnsubscribe'] as String?,
        listUnsubscribePost: data['listUnsubscribePost'] as String?,
      );

  final String messageId;
  final String? gmailThreadId;
  final String? sender;
  final String? subject;
  final String? preview;
  final String? body;
  final String contentKind;
  final int? sentAtEpochMillis;
  final String flags;
  final String labels;
  final String? listUnsubscribe;
  final String? listUnsubscribePost;
}

final class MessageBodyStateRow {
  const MessageBodyStateRow(
    this.messageId,
    this.preview,
    this.body,
    this.contentKind,
    this.bodyDownloadState,
  );

  final String messageId;
  final String? preview;
  final String? body;
  final String contentKind;
  final String bodyDownloadState;
}
