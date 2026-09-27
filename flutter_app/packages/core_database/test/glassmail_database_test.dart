import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show QueryRow, Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late GlassMailDatabase database;
  late Map<String, dynamic> roomSchema;

  setUp(() async {
    final fixture =
        jsonDecode(
              await File('test/fixtures/room_v10_schema.json').readAsString(),
            )
            as Map<String, dynamic>;
    roomSchema = fixture['database'] as Map<String, dynamic>;
    database = GlassMailDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').getSingle();
  });

  tearDown(() => database.close());

  test(
    'fresh schema matches Room v10 table, index, and foreign key metadata',
    () async {
      expect(roomSchema['version'], 10);
      final entities = (roomSchema['entities'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final expectedTables = entities
          .map((entity) => entity['tableName'] as String)
          .toSet();
      final actualTables =
          (await database
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table' "
                    "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'messages_fts_%'",
                  )
                  .get())
              .map((row) => row.data['name'] as String)
              .toSet();
      expect(actualTables, expectedTables);

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.single, 10);

      for (final entity in entities) {
        final table = entity['tableName'] as String;
        if (table == 'messages_fts') {
          await expectFts4(database, entity);
          continue;
        }

        final fields = (entity['fields'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final primaryKey = (entity['primaryKey'] as Map<String, dynamic>)
            .cast<String, dynamic>();
        final primaryColumns = (primaryKey['columnNames'] as List<dynamic>)
            .cast<String>();
        final columns = await database
            .customSelect('PRAGMA table_info("$table")')
            .get();

        expect(
          columns.map((row) => row.data['name']).toList(),
          fields.map((field) => field['columnName']).toList(),
          reason: '$table columns and order',
        );
        for (var i = 0; i < fields.length; i++) {
          final field = fields[i];
          final column = columns[i].data;
          expect(
            column['type'],
            field['affinity'],
            reason: '$table.${field['columnName']} type',
          );
          expect(
            column['notnull'] == 1,
            field['notNull'] == true,
            reason: '$table.${field['columnName']} nullability',
          );
          expect(
            column['dflt_value'],
            field['defaultValue'],
            reason: '$table.${field['columnName']} default',
          );
          final pkPosition = primaryColumns.indexOf(
            field['columnName'] as String,
          );
          expect(
            column['pk'],
            pkPosition < 0 ? 0 : pkPosition + 1,
            reason: '$table.${field['columnName']} primary key position',
          );
        }

        await expectIndices(database, table, entity);
        await expectForeignKeys(database, table, entity);
      }

      expect(
        (await database.customSelect('PRAGMA foreign_key_check').get()),
        isEmpty,
      );
      final integrity = await database
          .customSelect('PRAGMA integrity_check')
          .get();
      expect(integrity.map((row) => row.data.values.single).toList(), ['ok']);
    },
  );

  test(
    'Room FTS4 triggers maintain external content through insert, update, delete',
    () async {
      await insertAccountAndMessage(
        database,
        messageId: 'message-fts',
        subject: 'oldsubjecttoken',
        body: 'bodysearchtoken',
      );
      expect(await ftsCount(database, 'oldsubjecttoken'), 1);

      await database.customStatement(
        "UPDATE messages SET subject = 'newsubjecttoken' "
        "WHERE messageId = 'message-fts'",
      );
      expect(await ftsCount(database, 'oldsubjecttoken'), 0);
      expect(await ftsCount(database, 'newsubjecttoken'), 1);

      await database.customStatement(
        "DELETE FROM messages WHERE messageId = 'message-fts'",
      );
      expect(await ftsCount(database, 'newsubjecttoken'), 0);
    },
  );

  test(
    'account deletion cascades and leaves FTS and SQLite consistent',
    () async {
      await insertAccountAndMessage(
        database,
        messageId: 'message-cascade',
        subject: 'cascadedsearchtoken',
        body: 'bodysearchtoken',
      );
      await database.customStatement('''
      INSERT INTO mailboxes(mailboxId, accountId, remoteName, uidValidity, uidNext, messageCount)
      VALUES ('inbox', 'account-1', 'INBOX', 7, 2, 1)
    ''');
      await database.customStatement('''
      INSERT INTO mailbox_messages(mailboxId, uid, messageId, flags, labels)
      VALUES ('inbox', 1, 'message-cascade', '', '')
    ''');

      await database.customStatement(
        "DELETE FROM accounts WHERE accountId = 'account-1'",
      );

      for (final table in ['mailboxes', 'messages', 'mailbox_messages']) {
        final result = await database
            .customSelect('SELECT COUNT(*) AS count FROM "$table"')
            .getSingle();
        expect(result.data['count'], 0, reason: '$table cascade');
      }
      expect(await ftsCount(database, 'cascadedsearchtoken'), 0);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      final integrity = await database
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      expect(integrity.data.values.single, 'ok');
    },
  );

  test(
    'active mutation queries filter states and order by time then ID',
    () async {
      await insertAccountAndMessage(
        database,
        messageId: 'message-queue',
        subject: 'queue',
        body: 'queue',
      );
      await insertMutation(
        database,
        id: 'later',
        messageId: 'message-queue',
        type: 'STAR',
        state: 'PENDING',
        createdAt: 20,
      );
      await insertMutation(
        database,
        id: 'z-at-same-time',
        messageId: 'message-queue',
        type: 'ARCHIVE',
        state: 'PENDING',
        createdAt: 10,
      );
      await insertMutation(
        database,
        id: 'a-at-same-time',
        messageId: 'message-queue',
        type: 'READ',
        state: 'IN_FLIGHT',
        createdAt: 10,
      );
      await insertMutation(
        database,
        id: 'failed',
        messageId: 'message-queue',
        type: 'DELETE',
        state: 'FAILED',
        createdAt: 1,
      );

      final byAccount = await database.activeMutationsForAccount('account-1');
      final byMessage = await database.activeMutationsForMessage(
        'message-queue',
      );
      expect(byAccount.map((mutation) => mutation.mutationId), [
        'a-at-same-time',
        'z-at-same-time',
        'later',
      ]);
      expect(byMessage.map((mutation) => mutation.mutationId), [
        'a-at-same-time',
        'z-at-same-time',
        'later',
      ]);
    },
  );

  test(
    'undoable archive selects latest pending and state writes are durable',
    () async {
      await insertAccountAndMessage(
        database,
        messageId: 'message-undo',
        subject: 'undo',
        body: 'undo',
      );
      await insertMutation(
        database,
        id: 'older-pending',
        messageId: 'message-undo',
        type: 'ARCHIVE',
        state: 'PENDING',
        createdAt: 10,
      );
      await insertMutation(
        database,
        id: 'newer-pending',
        messageId: 'message-undo',
        type: 'ARCHIVE',
        state: 'PENDING',
        createdAt: 20,
      );
      await insertMutation(
        database,
        id: 'newest-in-flight',
        messageId: 'message-undo',
        type: 'ARCHIVE',
        state: 'IN_FLIGHT',
        createdAt: 30,
      );

      expect(
        (await database.undoableArchiveForMessage('message-undo'))?.mutationId,
        'newer-pending',
      );
      expect(
        await database.updatePendingMutationState(
          mutationId: 'newer-pending',
          state: 'FAILED',
          retryCount: 3,
          errorCode: 'SERVER_UNAVAILABLE',
        ),
        1,
      );
      final updated = await (database.select(
        database.pendingMutations,
      )..where((row) => row.mutationId.equals('newer-pending'))).getSingle();
      expect(updated.state, 'FAILED');
      expect(updated.retryCount, 3);
      expect(updated.lastErrorCode, 'SERVER_UNAVAILABLE');
      expect(
        (await database.undoableArchiveForMessage('message-undo'))?.mutationId,
        'older-pending',
      );

      expect(await database.deletePendingMutation('older-pending'), 1);
      expect(
        (await database.undoableArchiveForMessage('message-undo'))?.mutationId,
        isNull,
      );
    },
  );

  test(
    'Room account, inbox, category, thread and attachment queries are ported',
    () async {
      await insertAccountAndMessage(
        database,
        messageId: 'message-thread-new',
        subject: 'Primary message',
        body: 'body',
      );
      await database.customStatement(
        "UPDATE messages SET gmailThreadId = 'thread-1', sentAtEpochMillis = 100 "
        "WHERE messageId = 'message-thread-new'",
      );
      await database.customStatement('''
      INSERT INTO mailboxes(mailboxId, accountId, remoteName, uidValidity, uidNext, messageCount)
      VALUES ('inbox', 'account-1', 'INBOX', 7, 3, 2)
    ''');
      await database.customStatement('''
      INSERT INTO messages(messageId, accountId, gmailThreadId, subject, sender, preview,
        sentAtEpochMillis, category, contentKind, bodyDownloadState)
      VALUES ('message-thread-old', 'account-1', 'thread-1', 'Social reply',
        'friend@example.test', 'reply', 90, 'SOCIAL', 'PLAIN', 'AVAILABLE')
    ''');
      await database.customStatement('''
      INSERT INTO mailbox_messages(mailboxId, uid, messageId, flags, labels) VALUES
        ('inbox', 2, 'message-thread-new', '', 'INBOX'),
        ('inbox', 1, 'message-thread-old', '\\Seen', 'INBOX')
    ''');
      await database.customStatement('''
      INSERT INTO attachments(attachmentId, messageId, partId, fileName, mimeType,
        sizeBytes, downloadState) VALUES ('attachment-1', 'message-thread-new',
        '2', 'report.pdf', 'application/pdf', 128, 'AVAILABLE')
    ''');

      final categoryRows = await database
          .watchInbox('inbox', category: 'SOCIAL')
          .first;
      expect(categoryRows.map((row) => row.messageId), [
        'message-thread-new',
        'message-thread-old',
      ]);
      expect(categoryRows.first.hasAttachment, isTrue);
      expect(await database.countMessagesForAccount('account-1'), 2);
      expect(await database.countMailboxMessages('inbox'), 2);
      expect(await database.inboxMessageCount('inbox'), 2);
      expect(
        (await database.watchCategoryUnreadCounts('inbox').first)
            .single
            .unreadCount,
        1,
      );
      expect(
        (await database.watchMessage('message-thread-new').first)?.subject,
        'Primary message',
      );
      expect(
        (await database.watchThread('message-thread-old').first).map(
          (row) => row.messageId,
        ),
        ['message-thread-old', 'message-thread-new'],
      );
      expect(
        (await database.watchAttachments('message-thread-new').first)
            .single
            .fileName,
        'report.pdf',
      );
      expect(
        (await database.watchAccountSummary('account-1').first)?.messageCount,
        2,
      );
    },
  );

  test(
    'FTS query binds Unicode quoted phrases and returns matching thread mail',
    () async {
      await insertAccountAndMessage(
        database,
        messageId: 'message-unicode',
        subject: 'Café quotes 東京',
        body: 'naïve résumé',
      );
      await database.customStatement('''
      INSERT INTO mailboxes(mailboxId, accountId, remoteName, uidValidity, uidNext, messageCount)
      VALUES ('inbox', 'account-1', 'INBOX', 7, 2, 1)
    ''');
      await database.customStatement('''
      INSERT INTO mailbox_messages(mailboxId, uid, messageId, flags, labels)
      VALUES ('inbox', 1, 'message-unicode', '', '')
    ''');

      final results = await database.search('inbox', '"café quotes"').first;
      expect(results.map((row) => row.messageId), ['message-unicode']);
      expect(await database.search('inbox', '"résumé 東京"').first, isEmpty);
    },
  );

  test(
    'inbox paging returns stable, newest-first slices over a large mailbox',
    () async {
      await insertAccountAndMessage(
        database,
        messageId: 'large-0000',
        subject: 'message 0',
        body: '',
      );
      await database.customStatement('''
      INSERT INTO mailboxes(mailboxId, accountId, remoteName, uidValidity, uidNext, messageCount)
      VALUES ('inbox', 'account-1', 'INBOX', 7, 701, 700)
    ''');
      final messages = <MessagesCompanion>[];
      final memberships = <MailboxMessagesCompanion>[];
      for (var i = 1; i < 700; i++) {
        final id = 'large-${i.toString().padLeft(4, '0')}';
        messages.add(
          MessagesCompanion.insert(
            messageId: id,
            accountId: 'account-1',
            subject: Value('message $i'),
            sentAtEpochMillis: Value(i),
            contentKind: 'PLAIN',
            bodyDownloadState: 'NOT_FETCHED',
          ),
        );
        memberships.add(
          MailboxMessagesCompanion.insert(
            mailboxId: 'inbox',
            uid: i + 1,
            messageId: id,
            flags: '',
            labels: '',
          ),
        );
      }
      await database.saveMessages(messages);
      await database.saveMailboxMessages(memberships);

      final page = await database
          .watchInbox('inbox', limit: 40, offset: 320)
          .first;
      expect(page, hasLength(40));
      expect(page.first.messageId, 'large-0379');
      expect(page.last.messageId, 'large-0340');
    },
  );

  test('mailbox snapshot transaction rolls back partial sync writes', () async {
    await database.saveAccount(
      AccountsCompanion.insert(
        accountId: 'account-transaction',
        email: 'transaction@example.test',
        createdAtEpochMillis: 1,
        syncState: 'SYNCING',
        gmailExtensionsEnabled: 0,
      ),
    );

    await expectLater(
      database.commitMailboxSnapshot(
        mailbox: MailboxesCompanion.insert(
          mailboxId: 'transaction-inbox',
          accountId: 'account-transaction',
          remoteName: 'INBOX',
          uidValidity: 1,
          uidNext: 2,
          messageCount: 1,
        ),
        messageRows: [
          MessagesCompanion.insert(
            messageId: 'transaction-message',
            accountId: 'account-transaction',
            contentKind: 'PLAIN',
            bodyDownloadState: 'NOT_FETCHED',
          ),
        ],
        memberships: [
          MailboxMessagesCompanion.insert(
            mailboxId: 'transaction-inbox',
            uid: 1,
            messageId: 'missing-message',
            flags: '',
            labels: '',
          ),
        ],
        checkpoint: SyncCheckpointsCompanion.insert(
          mailboxId: 'transaction-inbox',
          accountId: 'account-transaction',
          uidValidity: 1,
          highestKnownUid: 1,
          syncGeneration: 1,
        ),
        replaceMembership: true,
      ),
      throwsA(anything),
    );

    expect(
      await (database.select(
        database.mailboxes,
      )..where((row) => row.mailboxId.equals('transaction-inbox'))).get(),
      isEmpty,
    );
    expect(
      await (database.select(
        database.messages,
      )..where((row) => row.messageId.equals('transaction-message'))).get(),
      isEmpty,
    );
    expect(await ftsCount(database, 'transaction'), 0);
  });

  test('Drift file data survives close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('glassmail-db-');
    final file = File('${directory.path}/restart.db');
    final first = GlassMailDatabase.forTesting(NativeDatabase(file));
    await first.customSelect('SELECT 1').getSingle();
    await first.saveAccount(
      AccountsCompanion.insert(
        accountId: 'restart-account',
        email: 'restart@example.test',
        createdAtEpochMillis: 3,
        syncState: 'READY',
        gmailExtensionsEnabled: 1,
      ),
    );
    await first.close();

    final reopened = GlassMailDatabase.forTesting(NativeDatabase(file));
    await reopened.customSelect('SELECT 1').getSingle();
    expect(
      (await reopened.accountById('restart-account'))?.email,
      'restart@example.test',
    );
    await reopened.close();
    await directory.delete(recursive: true);
  });

  test(
    'portable backup restores data without credentials or pending actions',
    () async {
      await database.saveAccount(
        AccountsCompanion.insert(
          accountId: 'portable-account',
          email: 'portable@example.test',
          createdAtEpochMillis: 1,
          syncState: 'READY',
          gmailExtensionsEnabled: 1,
        ),
      );
      await database.saveMailboxes([
        MailboxesCompanion.insert(
          mailboxId: 'portable-inbox',
          accountId: 'portable-account',
          remoteName: 'INBOX',
          uidValidity: 4,
          uidNext: 2,
          messageCount: 1,
        ),
      ]);
      await database.saveMessages([
        MessagesCompanion.insert(
          messageId: 'portable-message',
          accountId: 'portable-account',
          subject: const Value('portable subject'),
          sender: const Value('sender@example.test'),
          preview: const Value('portable preview'),
          body: const Value('private portable body'),
          contentKind: 'PLAIN',
          bodyDownloadState: 'DOWNLOADED',
        ),
      ]);
      await database.saveMailboxMessages([
        MailboxMessagesCompanion.insert(
          mailboxId: 'portable-inbox',
          uid: 1,
          messageId: 'portable-message',
          flags: r'\Seen',
          labels: 'INBOX',
        ),
      ]);
      await database.saveDraft(
        DraftsCompanion.insert(
          draftId: 'portable-draft',
          accountId: 'portable-account',
          toAddresses: 'to@example.test',
          ccAddresses: '',
          bccAddresses: '',
          subject: 'queued draft',
          body: 'draft body',
          references: '',
          status: 'QUEUED',
          updatedAtEpochMillis: 5,
          attachments: '',
        ),
      );
      await database.insertPendingMutation(
        PendingMutationsCompanion.insert(
          mutationId: 'portable-mutation',
          accountId: 'portable-account',
          messageId: 'portable-message',
          type: 'DELETE',
          state: 'PENDING',
          retryCount: 0,
          createdAtEpochMillis: 6,
        ),
      );

      final backup = await database.exportPortableBackupRows();
      expect(
        (backup['tables']! as Map<String, dynamic>).containsKey(
          'pending_mutations',
        ),
        isFalse,
      );
      final restored = GlassMailDatabase.forTesting(NativeDatabase.memory());
      try {
        await restored.customSelect('SELECT 1').getSingle();
        await restored.restorePortableBackupRows(
          Map<String, dynamic>.from(backup),
        );

        expect(
          (await restored.accountById('portable-account'))?.syncState,
          'NEEDS_CREDENTIAL',
        );
        expect(await ftsCount(restored, 'portable'), 1);
        expect(
          (await (restored.select(restored.drafts)
                    ..where((row) => row.draftId.equals('portable-draft')))
                  .getSingle())
              .status,
          'DRAFT',
        );
        expect(
          await restored.activeMutationsForAccount('portable-account'),
          isEmpty,
        );
        expect(
          await restored.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await restored.close();
      }
    },
  );

  test('portable backup restore refuses a non-empty destination', () async {
    await database.saveAccount(
      AccountsCompanion.insert(
        accountId: 'already-here',
        email: 'existing@example.test',
        createdAtEpochMillis: 1,
        syncState: 'READY',
        gmailExtensionsEnabled: 0,
      ),
    );
    await expectLater(
      database.restorePortableBackupRows(const <String, dynamic>{
        'schemaVersion': 10,
      }),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'draft, checkpoint, notification, cache settings and quota DAOs persist',
    () async {
      await database.saveAccount(
        AccountsCompanion.insert(
          accountId: 'dao-account',
          email: 'dao@example.test',
          createdAtEpochMillis: 1,
          syncState: 'READY',
          gmailExtensionsEnabled: 0,
        ),
      );
      await database.saveMailboxes([
        MailboxesCompanion.insert(
          mailboxId: 'dao-inbox',
          accountId: 'dao-account',
          remoteName: 'INBOX',
          uidValidity: 7,
          uidNext: 2,
          messageCount: 1,
        ),
      ]);
      await database.saveCheckpoint(
        SyncCheckpointsCompanion.insert(
          mailboxId: 'dao-inbox',
          accountId: 'dao-account',
          uidValidity: 7,
          highestKnownUid: 1,
          syncGeneration: 3,
          lastSuccessfulSyncEpochMillis: const Value(99),
        ),
      );
      await database.saveDraft(
        DraftsCompanion.insert(
          draftId: 'draft-1',
          accountId: 'dao-account',
          toAddresses: 'to@example.test',
          ccAddresses: '',
          bccAddresses: '',
          subject: 'draft subject',
          body: 'draft body',
          references: '',
          status: 'DRAFT',
          updatedAtEpochMillis: 120,
          attachments: '',
        ),
      );
      await database.saveNotificationState(
        NotificationStateCompanion.insert(
          accountId: 'dao-account',
          baselineEstablished: 1,
        ),
      );
      await database.saveCacheConfig(
        CacheConfigCompanion.insert(
          accountId: 'dao-account',
          offlineMessageCount: const Value(60),
          prefetchUnreadBodies: const Value(0),
        ),
      );
      await database.saveStorageQuota(
        StorageQuotaCompanion.insert(
          accountId: 'dao-account',
          usedKb: 400,
          limitKb: 900,
          checkedAtEpochMillis: 150,
        ),
      );

      expect((await database.checkpoint('dao-inbox'))?.highestKnownUid, 1);
      expect(
        (await database.watchDrafts('dao-account').first).single.body,
        'draft body',
      );
      expect(
        (await database.watchDraft('draft-1').first)?.subject,
        'draft subject',
      );
      expect(
        (await database.notificationStateForAccount(
          'dao-account',
        ))?.baselineEstablished,
        1,
      );
      expect(
        (await database.cacheConfigForAccount(
          'dao-account',
        ))?.offlineMessageCount,
        60,
      );
      expect(
        (await database.watchCacheConfig('dao-account').first)
            ?.prefetchUnreadBodies,
        0,
      );
      expect(
        (await database.watchStorageQuota('dao-account').first)?.usedKb,
        400,
      );
      expect(await database.deleteCheckpoint('dao-inbox'), 1);
      expect(await database.deleteDraft('draft-1'), 1);
      expect(await database.deleteNotificationState('dao-account'), 1);
    },
  );

  test(
    'queued send claim and undo are conditional atomic transitions',
    () async {
      await database.saveAccount(
        AccountsCompanion.insert(
          accountId: 'send-account',
          email: 'send@example.test',
          createdAtEpochMillis: 1,
          syncState: 'READY',
          gmailExtensionsEnabled: 0,
        ),
      );
      await database.saveDraft(
        DraftsCompanion.insert(
          draftId: 'send-claimed',
          accountId: 'send-account',
          toAddresses: 'to@example.test',
          ccAddresses: '',
          bccAddresses: '',
          subject: 'claimed',
          body: 'body',
          references: '',
          status: 'QUEUED',
          updatedAtEpochMillis: 10,
          attachments: '',
        ),
      );
      await database.saveDraft(
        DraftsCompanion.insert(
          draftId: 'send-undo',
          accountId: 'send-account',
          toAddresses: 'to@example.test',
          ccAddresses: '',
          bccAddresses: '',
          subject: 'undo',
          body: 'body',
          references: '',
          status: 'QUEUED',
          updatedAtEpochMillis: 10,
          attachments: '',
        ),
      );

      expect(
        await database.claimDraftForSend(
          draftId: 'send-claimed',
          expectedStatus: 'DRAFT',
          updatedAtEpochMillis: 20,
        ),
        isFalse,
      );
      expect(
        await database.claimDraftForSend(
          draftId: 'send-claimed',
          expectedStatus: 'QUEUED',
          updatedAtEpochMillis: 20,
        ),
        isTrue,
      );
      expect(
        await database.restoreQueuedDraft(
          draftId: 'send-claimed',
          updatedAtEpochMillis: 30,
        ),
        isFalse,
      );
      expect(
        (await database.watchDraft('send-claimed').first)?.status,
        'SENDING',
      );

      expect(
        await database.restoreQueuedDraft(
          draftId: 'send-undo',
          updatedAtEpochMillis: 30,
        ),
        isTrue,
      );
      expect(
        await database.claimDraftForSend(
          draftId: 'send-undo',
          expectedStatus: 'QUEUED',
          updatedAtEpochMillis: 40,
        ),
        isFalse,
      );
      expect((await database.watchDraft('send-undo').first)?.status, 'DRAFT');
    },
  );

  test('cache eviction preserves unread and starred bodies', () async {
    await insertAccountAndMessage(
      database,
      messageId: 'cache-fresh-read',
      subject: 'fresh',
      body: 'bodyfresh',
    );
    await database.customStatement(
      "UPDATE messages SET sentAtEpochMillis = 100, bodyDownloadState = 'AVAILABLE' "
      "WHERE messageId = 'cache-fresh-read'",
    );
    await database.customStatement('''
      INSERT INTO messages(messageId, accountId, subject, body, sentAtEpochMillis,
        contentKind, bodyDownloadState) VALUES
        ('cache-old-read', 'account-1', 'old', 'bodyold', 10, 'PLAIN', 'AVAILABLE'),
        ('cache-unread', 'account-1', 'unread', 'bodyunread', 5, 'PLAIN', 'AVAILABLE'),
        ('cache-starred', 'account-1', 'starred', 'bodystarred', 4, 'PLAIN', 'AVAILABLE')
    ''');
    await database.customStatement('''
      INSERT INTO mailboxes(mailboxId, accountId, remoteName, uidValidity, uidNext, messageCount)
      VALUES ('inbox', 'account-1', 'INBOX', 7, 5, 4)
    ''');
    await database.customStatement('''
      INSERT INTO mailbox_messages(mailboxId, uid, messageId, flags, labels) VALUES
        ('inbox', 1, 'cache-fresh-read', '\\Seen', ''),
        ('inbox', 2, 'cache-old-read', '\\Seen', ''),
        ('inbox', 3, 'cache-unread', '', ''),
        ('inbox', 4, 'cache-starred', '\\Seen \\Flagged', '')
    ''');

    await database.evictOldReadBodies('account-1', 50);
    expect(await database.bodyDownloadState('cache-old-read'), 'NOT_FETCHED');
    expect(await database.bodyDownloadState('cache-unread'), 'AVAILABLE');
    expect(await database.bodyDownloadState('cache-starred'), 'AVAILABLE');

    await database.updateMessageBody(
      messageId: 'cache-old-read',
      body: 'bodyold',
      preview: 'old',
      contentKind: 'PLAIN',
      downloadState: 'AVAILABLE',
    );
    await database.evictExcessBodies('account-1', 1);
    expect(await database.bodyDownloadState('cache-fresh-read'), 'AVAILABLE');
    expect(await database.bodyDownloadState('cache-old-read'), 'NOT_FETCHED');
    expect(await database.bodyDownloadState('cache-unread'), 'AVAILABLE');
    expect(await database.bodyDownloadState('cache-starred'), 'AVAILABLE');
  });
}

Future<int> ftsCount(GlassMailDatabase database, String term) async {
  final result = await database
      .customSelect(
        'SELECT COUNT(*) AS count FROM messages_fts '
        'WHERE messages_fts MATCH ?',
        variables: [Variable.withString(term)],
      )
      .getSingle();
  return result.data['count'] as int;
}

Future<void> expectFts4(
  GlassMailDatabase database,
  Map<String, dynamic> entity,
) async {
  expect(entity['ftsVersion'], 'FTS4');
  final fields = (entity['fields'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final columns = await database
      .customSelect('PRAGMA table_info("messages_fts")')
      .get();
  expect(
    columns.map((row) => row.data['name']).toList(),
    fields.map((field) => field['columnName']).toList(),
  );
  for (var i = 0; i < fields.length; i++) {
    // SQLite reports no declared type for FTS4 virtual-table columns through
    // table_info, even though Room's exported FTS declaration spells out TEXT.
    expect(fields[i]['affinity'], 'TEXT');
    expect(columns[i].data['type'], isEmpty);
    expect(columns[i].data['notnull'], 0);
    expect(columns[i].data['dflt_value'], isNull);
  }

  final tableSql = await database
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'messages_fts'",
      )
      .getSingle();
  final sql = tableSql.data['sql'] as String;
  expect(sql.toUpperCase(), contains('USING FTS4'));
  expect(sql.toLowerCase(), contains('tokenize=unicode61'));
  expect(sql.toLowerCase(), contains("content='messages'"));
  for (final field in fields) {
    expect(
      sql.toLowerCase(),
      contains('${field['columnName']} text'),
      reason: 'Room FTS declaration for ${field['columnName']}',
    );
  }

  final expectedNames = (entity['contentSyncTriggers'] as List<dynamic>)
      .cast<String>()
      .map(
        (trigger) => RegExp(
          r'CREATE TRIGGER(?: IF NOT EXISTS)?\s+(\w+)',
        ).firstMatch(trigger)!.group(1)!,
      )
      .toSet();
  final triggers = await database
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' "
        "AND tbl_name = 'messages'",
      )
      .get();
  expect(triggers.map((row) => row.data['name']).toSet(), expectedNames);
  for (final trigger in triggers) {
    expect(trigger.data['sql'], isNotEmpty);
  }
}

Future<void> expectIndices(
  GlassMailDatabase database,
  String table,
  Map<String, dynamic> entity,
) async {
  final expected =
      (entity['indices'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
  final listed = await database
      .customSelect('PRAGMA index_list("$table")')
      .get();
  final actualNames = listed
      .map((row) => row.data['name'] as String)
      .where((name) => !name.startsWith('sqlite_autoindex_'))
      .toSet();
  expect(
    actualNames,
    expected.map((index) => index['name']).toSet(),
    reason: '$table named indexes',
  );

  for (final index in expected) {
    final name = index['name'] as String;
    final indexInfo = await database
        .customSelect('PRAGMA index_info("$name")')
        .get();
    expect(
      indexInfo.map((row) => row.data['name']).toList(),
      (index['columnNames'] as List<dynamic>).cast<String>(),
      reason: '$name columns',
    );
    final indexListRow = listed.singleWhere((row) => row.data['name'] == name);
    expect(
      indexListRow.data['unique'] == 1,
      index['unique'],
      reason: '$name uniqueness',
    );
  }
}

Future<void> expectForeignKeys(
  GlassMailDatabase database,
  String table,
  Map<String, dynamic> entity,
) async {
  final expected =
      (entity['foreignKeys'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
  final actual = await database
      .customSelect('PRAGMA foreign_key_list("$table")')
      .get();

  List<String> encodeActual(QueryRow row) => [
    row.data['table'] as String,
    row.data['from'] as String,
    row.data['to'] as String,
    (row.data['on_update'] as String).toUpperCase(),
    (row.data['on_delete'] as String).toUpperCase(),
  ];

  final actualRelations = actual.map(encodeActual).toList()..sort(compareRows);
  final expectedRelations = <List<String>>[];
  for (final key in expected) {
    final columns = (key['columns'] as List<dynamic>).cast<String>();
    final referenced = (key['referencedColumns'] as List<dynamic>)
        .cast<String>();
    for (var i = 0; i < columns.length; i++) {
      expectedRelations.add([
        key['table'] as String,
        columns[i],
        referenced[i],
        (key['onUpdate'] as String).toUpperCase(),
        (key['onDelete'] as String).toUpperCase(),
      ]);
    }
  }
  expectedRelations.sort(compareRows);
  expect(actualRelations, expectedRelations, reason: '$table foreign keys');
}

Future<void> insertAccountAndMessage(
  GlassMailDatabase database, {
  required String messageId,
  required String subject,
  required String body,
}) async {
  await database.customStatement('''
    INSERT INTO accounts(accountId, email, createdAtEpochMillis, syncState, gmailExtensionsEnabled)
    VALUES ('account-1', 'owner@example.test', 1, 'SYNCED', 1)
  ''');
  await database.customStatement('''
    INSERT INTO messages(messageId, accountId, subject, sender, preview, body, contentKind, bodyDownloadState)
    VALUES ('$messageId', 'account-1', '$subject', 'sender@example.test', '', '$body', 'PLAIN', 'DOWNLOADED')
  ''');
}

Future<void> insertMutation(
  GlassMailDatabase database, {
  required String id,
  required String messageId,
  required String type,
  required String state,
  required int createdAt,
}) => database.insertPendingMutation(
  PendingMutationsCompanion.insert(
    mutationId: id,
    accountId: 'account-1',
    messageId: messageId,
    type: type,
    state: state,
    retryCount: 0,
    createdAtEpochMillis: createdAt,
  ),
);

int compareRows(List<String> a, List<String> b) {
  for (var i = 0; i < a.length; i++) {
    final order = a[i].compareTo(b[i]);
    if (order != 0) return order;
  }
  return 0;
}
