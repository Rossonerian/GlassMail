import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart'
    hide StorageQuota;
import 'package:glassmail_core_imap/glassmail_core_imap.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:glassmail_data_mail/glassmail_data_mail.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

void main() {
  late GlassMailDatabase database;
  late _MemoryCredentials credentials;
  late Directory attachmentRoot;

  setUp(() async {
    database = GlassMailDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').getSingle();
    credentials = _MemoryCredentials();
    attachmentRoot = await Directory.systemTemp.createTemp('glassmail-cache-');
  });

  tearDown(() async {
    await database.close();
    if (await attachmentRoot.exists()) {
      await attachmentRoot.delete(recursive: true);
    }
  });

  test(
    'account credential setup is reversible and settings stay account scoped',
    () async {
      final repository = _repository(
        database: database,
        credentials: credentials,
        attachmentRoot: attachmentRoot,
        source: _Pages([]),
        content: _FakeContent(),
      );
      final password = Uint8List.fromList(utf8.encode('throwaway-test-secret'));

      await repository.createAccount(
        'account-a',
        'a@example.test',
        credentialUtf8: password,
      );

      expect(password, everyElement(0));
      expect(
        await credentials.withCredential('account-a', utf8.decode),
        'throwaway-test-secret',
      );
      expect(await repository.observeAccounts().first, [
        const MailAccount(
          accountId: 'account-a',
          email: 'a@example.test',
          syncState: 'READY',
        ),
      ]);
      expect(
        await repository.observeCacheSettings('account-a').first,
        const MailCacheSettings(),
      );

      final replacement = Uint8List.fromList(
        utf8.encode('replacement-test-secret'),
      );
      await repository.updateCredential('account-a', replacement);
      expect(replacement, everyElement(0));
      expect(
        await credentials.withCredential('account-a', utf8.decode),
        'replacement-test-secret',
      );

      await repository.removeAccount('account-a');

      expect(await database.accountById('account-a'), isNull);
      expect(
        await credentials.withCredential('account-a', (_) => 'present'),
        isNull,
      );
    },
  );

  test(
    'sync wires inbox, body, attachment, quota, search and category streams',
    () async {
      final content = _FakeContent();
      final remoteDrafts = _FakeDrafts()
        ..drafts = [
          ImapRemoteDraft(
            uid: 44,
            draftId: 'remote-draft-44',
            to: const ['reader@example.test'],
            cc: const [],
            bcc: const [],
            subject: 'Recovered remote draft',
            body: 'Remote copy',
            inReplyTo: null,
            references: const [],
            updatedAtEpochMillis: 9000,
          ),
        ];
      final repository = _repository(
        database: database,
        credentials: credentials,
        attachmentRoot: attachmentRoot,
        source: _Pages([
          GmailInboxSnapshot(
            capabilities: const {'IMAP4REV1', 'X-GM-EXT-1'},
            mailboxes: [
              ImapMailbox(name: 'INBOX', attributes: {r'\Inbox'}),
            ],
            inbox: const ImapSelectedMailbox(
              uidValidity: 18,
              uidNext: 2,
              messageCount: 1,
            ),
            messages: [
              ImapMessageMetadata(
                uid: 1,
                flags: const {},
                gmailMessageId: 'stable-message',
                gmailThreadId: 'thread-1',
                labels: const {r'\Inbox'},
                subject: 'Quasar blueprint',
                sender: 'Ada <ada@example.test>',
                sentAtEpochMillis: 1000,
                sizeBytes: 512,
              ),
            ],
            requestedThroughUid: 1,
          ),
        ]),
        content: content,
        remoteDraftSource: remoteDrafts,
        clock: () => 10000,
      );
      await repository.createAccount(
        'account-a',
        'a@example.test',
        credentialUtf8: Uint8List.fromList(utf8.encode('password')),
      );

      expect(await repository.synchronize('account-a'), isA<MailSyncSuccess>());

      final inbox = await repository.observeInbox('account-a').first;
      expect(inbox.single.messageId, 'gmail:account-a:stable-message');
      expect(inbox.single.unread, isTrue);
      expect(inbox.single.threadId, 'thread-1');
      final queryResult = await repository.search('account-a', 'quasar').first;
      expect(queryResult.single.subject, 'Quasar blueprint');
      expect(
        await repository.search('account-a', 'quasar blueprint').first,
        hasLength(1),
      );
      expect(await repository.observeCategoryUnreadCounts('account-a').first, {
        MailCategory.primary: 1,
      });
      expect(content.bodyRequests, 1, reason: 'unread prefetch is enabled');
      expect(content.bodyMailbox, 'INBOX');

      final message = await repository
          .observeMessage(inbox.single.messageId)
          .first;
      expect(message?.body, 'The attachment is a small PDF.');
      expect(message?.attachments.single.fileName, 'report.pdf');
      final attachmentId = message!.attachments.single.attachmentId;
      expect((await database.attachmentById(attachmentId))?.partId, '2');
      final transfer = await repository.downloadAttachment(
        'account-a',
        attachmentId,
      );
      expect(transfer, isA<MailOperationSuccess<DownloadedAttachment>>());
      final downloaded =
          (transfer as MailOperationSuccess<DownloadedAttachment>).value;
      expect(await File(downloaded.filePath).readAsBytes(), [1, 2, 3, 4]);
      expect(content.attachmentPart, '2');
      expect(
        await repository.observeStorageQuota('account-a').first,
        const StorageQuota(
          usedKb: 12,
          limitKb: 500,
          checkedAtEpochMillis: 10000,
        ),
      );
      expect(
        (await repository.observeDraft('remote-draft-44').first)?.subject,
        'Recovered remote draft',
      );

      final draft = MailDraft(
        draftId: 'draft-local',
        accountId: 'account-a',
        to: const ['reader@example.test'],
        subject: 'Local draft',
        body: 'Saved on device',
        updatedAtEpochMillis: 10000,
      );
      await repository.saveDraft(draft);
      expect(await repository.observeDraft('draft-local').first, draft);
      await repository.deleteDraft('draft-local');
      expect(await repository.observeDraft('draft-local').first, isNull);
      expect(remoteDrafts.deletedDraftIds, ['draft-local']);
    },
  );

  test(
    'sync imports a bounded Sent page and fetches from its remote mailbox',
    () async {
      final content = _FakeContent();
      final repository = _repository(
        database: database,
        credentials: credentials,
        attachmentRoot: attachmentRoot,
        source: _Pages([
          GmailInboxSnapshot(
            capabilities: const {'IMAP4REV1'},
            mailboxes: [
              ImapMailbox(name: 'INBOX', attributes: {r'\Inbox'}),
            ],
            inbox: const ImapSelectedMailbox(
              uidValidity: 18,
              uidNext: 1,
              messageCount: 0,
            ),
            messages: const [],
            requestedThroughUid: 0,
          ),
        ]),
        sentSource: _SentPage(
          SentMailboxSnapshot(
            remoteName: '[Gmail]/Sent Mail',
            uidValidity: 88,
            uidNext: 52,
            messageCount: 51,
            gmailExtensions: true,
            messages: [
              ImapMessageMetadata(
                uid: 51,
                flags: const {r'\Seen'},
                gmailMessageId: 'sent-51',
                gmailThreadId: 'sent-thread',
                labels: const {r'\Sent'},
                subject: 'Sent from another device',
                sender: 'a@example.test',
                sentAtEpochMillis: 5000,
                sizeBytes: 120,
              ),
            ],
          ),
        ),
        content: content,
      );
      await repository.createAccount(
        'account-a',
        'a@example.test',
        credentialUtf8: Uint8List.fromList(utf8.encode('password')),
      );

      await repository.synchronize('account-a');

      final sent = await repository.observeSent('account-a').first;
      expect(sent.map((item) => item.subject), ['Sent from another device']);
      final sentThread = await repository
          .observeThreadInMailbox(sent.single.messageId, 'account-a:SENT')
          .first;
      expect(sentThread.map((message) => message.subject), [
        'Sent from another device',
      ]);
      expect(
        await repository
            .observeThreadInMailbox(sent.single.messageId, 'account-a:INBOX')
            .first,
        isEmpty,
      );
      await repository.loadMessageBody(sent.single.messageId);
      expect(content.bodyMailbox, '[Gmail]/Sent Mail');
    },
  );

  test(
    'sync caches the latest Trash page for review and single-message purge',
    () async {
      final repository = _repository(
        database: database,
        credentials: credentials,
        attachmentRoot: attachmentRoot,
        source: _Pages([
          GmailInboxSnapshot(
            capabilities: const {'IMAP4REV1'},
            mailboxes: [
              ImapMailbox(name: 'INBOX', attributes: {r'\Inbox'}),
            ],
            inbox: const ImapSelectedMailbox(
              uidValidity: 18,
              uidNext: 1,
              messageCount: 0,
            ),
            messages: const [],
            requestedThroughUid: 0,
          ),
        ]),
        trashSource: _TrashPage(
          TrashMailboxSnapshot(
            remoteName: '[Gmail]/Trash',
            uidValidity: 44,
            uidNext: 7,
            messageCount: 6,
            gmailExtensions: true,
            messages: [
              ImapMessageMetadata(
                uid: 6,
                flags: const {},
                gmailMessageId: 'trashed-6',
                gmailThreadId: 'trash-thread',
                labels: const {r'\Trash'},
                subject: 'A message in Trash',
                sender: 'sender@example.test',
                sentAtEpochMillis: 6000,
                sizeBytes: 120,
              ),
            ],
          ),
        ),
        content: _FakeContent(),
      );
      await repository.createAccount(
        'account-a',
        'a@example.test',
        credentialUtf8: Uint8List.fromList(utf8.encode('password')),
      );

      await repository.synchronize('account-a');

      final trash = await repository.observeTrash('account-a').first;
      expect(trash.map((item) => item.subject), ['A message in Trash']);
      expect(
        await repository.trashMailboxId('account-a'),
        'account-a:[Gmail]/Trash',
      );
      final thread = await repository
          .observeThreadInMailbox(
            trash.single.messageId,
            'account-a:[Gmail]/Trash',
          )
          .first;
      expect(thread.single.subject, 'A message in Trash');
    },
  );

  test(
    'portable repository backup restores cached and draft attachments',
    () async {
      final repository = _repository(
        database: database,
        credentials: credentials,
        attachmentRoot: attachmentRoot,
        source: _Pages([
          GmailInboxSnapshot(
            capabilities: const {'IMAP4REV1'},
            mailboxes: [
              ImapMailbox(name: 'INBOX', attributes: {r'\Inbox'}),
            ],
            inbox: const ImapSelectedMailbox(
              uidValidity: 18,
              uidNext: 2,
              messageCount: 1,
            ),
            messages: [
              ImapMessageMetadata(
                uid: 1,
                flags: const {},
                gmailMessageId: 'backup-message',
                gmailThreadId: 'backup-thread',
                labels: const {r'\Inbox'},
                subject: 'Backup attachment',
                sender: 'sender@example.test',
                sentAtEpochMillis: 1000,
                sizeBytes: 120,
              ),
            ],
            requestedThroughUid: 1,
          ),
        ]),
        content: _FakeContent(),
        clock: () => 10000,
      );
      await repository.createAccount(
        'backup-account',
        'backup@example.test',
        credentialUtf8: Uint8List.fromList(utf8.encode('test-password')),
      );
      await repository.synchronize('backup-account');
      final item =
          (await repository.observeInbox('backup-account').first).single;
      final attachment =
          (await repository.observeMessage(item.messageId).first)!
              .attachments
              .single;
      final download = await repository.downloadAttachment(
        'backup-account',
        attachment.attachmentId,
      );
      final downloaded =
          (download as MailOperationSuccess<DownloadedAttachment>).value;
      await repository.saveDraft(
        MailDraft(
          draftId: 'backup-draft',
          accountId: 'backup-account',
          subject: 'Draft with local file',
          attachments: [
            DraftAttachment(
              uri: Uri.file(downloaded.filePath).toString(),
              fileName: downloaded.fileName,
              mimeType: downloaded.mimeType,
              sizeBytes: 4,
            ),
          ],
        ),
      );

      final exported = await repository.exportBackupData();
      final exportedDatabase = exported['database']! as Map<String, dynamic>;
      final exportedTables =
          exportedDatabase['tables']! as Map<String, dynamic>;
      expect(exportedTables['accounts'], isNotEmpty);
      final restoredDatabase = GlassMailDatabase.forTesting(
        NativeDatabase.memory(),
      );
      final restoredRoot = await Directory.systemTemp.createTemp(
        'glassmail-restore-',
      );
      final restoredCredentials = _MemoryCredentials();
      final restoredRepository = _repository(
        database: restoredDatabase,
        credentials: restoredCredentials,
        attachmentRoot: restoredRoot,
        source: _Pages([]),
        content: _FakeContent(),
      );
      try {
        await restoredDatabase.customSelect('SELECT 1').getSingle();
        await restoredRepository.restoreBackupData(
          Map<String, dynamic>.from(exported),
        );

        expect(await restoredDatabase.accountById('backup-account'), isNotNull);
        expect(
          (await restoredRepository.observeAccounts().first).single.syncState,
          'NEEDS_CREDENTIAL',
        );
        expect(
          await restoredCredentials.withCredential(
            'backup-account',
            (_) => true,
          ),
          isNull,
        );
        final restoredDraft = await restoredRepository
            .observeDraft('backup-draft')
            .first;
        expect(restoredDraft, isNotNull);
        final restoredDraftPath = Uri.parse(
          restoredDraft!.attachments.single.uri,
        ).toFilePath();
        expect(restoredDraftPath, isNot(downloaded.filePath));
        expect(await File(restoredDraftPath).readAsBytes(), [1, 2, 3, 4]);

        final restoredAttachment = await restoredRepository.downloadAttachment(
          'backup-account',
          attachment.attachmentId,
        );
        expect(
          restoredAttachment,
          isA<MailOperationSuccess<DownloadedAttachment>>(),
        );
        expect(
          await File(
            (restoredAttachment as MailOperationSuccess<DownloadedAttachment>)
                .value
                .filePath,
          ).readAsBytes(),
          [1, 2, 3, 4],
        );
      } finally {
        await restoredDatabase.close();
        if (await restoredRoot.exists()) {
          await restoredRoot.delete(recursive: true);
        }
      }
    },
  );
}

LocalFirstMailRepository _repository({
  required GlassMailDatabase database,
  required _MemoryCredentials credentials,
  required Directory attachmentRoot,
  required InboxPageSource source,
  required MailContentSource content,
  MailDraftRemoteSource? remoteDraftSource,
  SentMailboxPageSource? sentSource,
  TrashMailboxPageSource? trashSource,
  int Function()? clock,
}) {
  final mutations = PendingMutationQueue(
    database: database,
    credentialStore: credentials,
    transport: _NoopMutationTransport(),
    clock: clock,
  );
  final outgoing = OutgoingMailQueue(
    database: database,
    credentialStore: credentials,
    transport: _NoopRawTransport(),
    clock: clock,
  );
  return LocalFirstMailRepository(
    database: database,
    credentialStore: credentials,
    mutationQueue: mutations,
    outgoingQueue: outgoing,
    inboxSource: source,
    sentMailboxSource: sentSource,
    trashMailboxSource: trashSource,
    contentSource: content,
    remoteDraftSource: remoteDraftSource ?? _FakeDrafts(),
    attachmentRoot: () async => attachmentRoot,
    clock: clock,
  );
}

final class _SentPage implements SentMailboxPageSource {
  _SentPage(this.snapshot);
  final SentMailboxSnapshot? snapshot;

  @override
  Future<SentMailboxSnapshot?> fetchLatest({
    required String email,
    required Uint8List credentialUtf8,
    int limit = maxUidSlotsPerPage,
  }) async => snapshot;
}

final class _TrashPage implements TrashMailboxPageSource {
  _TrashPage(this.snapshot);
  final TrashMailboxSnapshot? snapshot;

  @override
  Future<TrashMailboxSnapshot?> fetchLatest({
    required String email,
    required Uint8List credentialUtf8,
    int limit = maxUidSlotsPerPage,
  }) async => snapshot;
}

final class _Pages implements InboxPageSource {
  _Pages(this.pages);
  final List<GmailInboxSnapshot> pages;
  int _index = 0;

  @override
  Future<GmailInboxSnapshot> fetchPage({
    required String email,
    required Uint8List credentialUtf8,
    required int afterUid,
    required int? expectedUidValidity,
    int limit = maxUidSlotsPerPage,
  }) async => pages[_index++];
}

final class _FakeContent implements MailContentSource {
  int bodyRequests = 0;
  String? bodyMailbox;
  String? attachmentPart;

  @override
  Future<ParsedMessageBody> fetchBody({
    required String email,
    required Uint8List credentialUtf8,
    required String mailbox,
    required int uid,
  }) async {
    bodyRequests++;
    bodyMailbox = mailbox;
    return ParsedMessageBody(
      plainText: 'The attachment is a small PDF.',
      htmlText: null,
      previewSnippet: 'The attachment is a small PDF.',
      attachments: const [
        ParsedAttachmentInfo(
          partId: '2',
          fileName: 'report.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 4,
        ),
      ],
    );
  }

  @override
  Future<Uint8List> fetchAttachment({
    required String email,
    required Uint8List credentialUtf8,
    required String mailbox,
    required int uid,
    required String partId,
  }) async {
    attachmentPart = partId;
    return Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  Future<ImapStorageQuotaRecord?> fetchQuota({
    required String email,
    required Uint8List credentialUtf8,
  }) async => const ImapStorageQuotaRecord(usedKb: 12, limitKb: 500);
}

final class _FakeDrafts implements MailDraftRemoteSource {
  List<ImapRemoteDraft> drafts = const [];
  final saved = <MailDraft>[];
  final deletedDraftIds = <String>[];

  @override
  Future<List<ImapRemoteDraft>> fetch({
    required String email,
    required Uint8List credentialUtf8,
  }) async => drafts;

  @override
  Future<void> save({
    required String email,
    required Uint8List credentialUtf8,
    required MailDraft draft,
  }) async {
    saved.add(draft);
  }

  @override
  Future<void> delete({
    required String email,
    required Uint8List credentialUtf8,
    required String draftId,
    int? remoteUid,
    int? remoteUidValidity,
  }) async {
    deletedDraftIds.add(draftId);
  }
}

final class _MemoryCredentials implements CredentialStore {
  final values = <String, Uint8List>{};

  @override
  Future<void> store(String accountId, List<int> credentialUtf8) async {
    values[accountId] = Uint8List.fromList(credentialUtf8);
    credentialUtf8.fillRange(0, credentialUtf8.length, 0);
  }

  @override
  Future<T?> withCredential<T>(
    String accountId,
    FutureOr<T> Function(Uint8List credentialUtf8) useCredential,
  ) async {
    final stored = values[accountId];
    if (stored == null) return null;
    final copy = Uint8List.fromList(stored);
    try {
      return await useCredential(copy);
    } finally {
      copy.fillRange(0, copy.length, 0);
    }
  }

  @override
  Future<void> delete(String accountId) async {
    values.remove(accountId);
  }
}

final class _NoopMutationTransport implements PendingMutationTransport {
  @override
  Future<void> apply({
    required String email,
    required Uint8List credentialUtf8,
    required PendingMutation mutation,
  }) async {}
}

final class _NoopRawTransport implements RawMailTransport {
  @override
  Future<void> send({
    required String email,
    required Uint8List credentialUtf8,
    required List<String> recipients,
    required Uint8List rawMessage,
  }) async {}
}
