import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:glassmail_data_mail/glassmail_data_mail.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

void main() {
  late GlassMailDatabase database;
  late _MemoryCredentialStore credentials;

  setUp(() async {
    database = GlassMailDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').getSingle();
    await database.saveAccount(AccountsCompanion.insert(
      accountId: 'account-1',
      email: 'owner@example.test',
      createdAtEpochMillis: 1,
      syncState: 'READY',
      gmailExtensionsEnabled: 0,
    ));
    credentials = _MemoryCredentialStore()
      ..values['account-1'] = Uint8List.fromList(utf8.encode('app-password'));
  });

  tearDown(() => database.close());

  test('UID pages checkpoint progress and notify only after the first baseline',
      () async {
    final source = _QueuePageSource([
      _snapshot(
        uidNext: 401,
        requestedThroughUid: 200,
        messages: [
          _message(uid: 7, gmailId: 'first'),
          _message(uid: 198, gmailId: 'second'),
        ],
      ),
      _snapshot(
        uidNext: 401,
        requestedThroughUid: 400,
        messages: [_message(uid: 201, gmailId: 'later')],
      ),
    ]);
    final notifications = <List<MailListItem>>[];
    final flushedAfterCheckpoints = <int?>[];
    final repository = MailboxSyncCoordinator(
      database: database,
      credentialStore: credentials,
      source: source,
      clock: () => 500,
      onNewMessages: notifications.add,
      flushPendingMutations: (accountId) async {
        flushedAfterCheckpoints.add(
            (await database.checkpoint('$accountId:INBOX'))?.highestKnownUid);
      },
    );

    final first = await repository.synchronize('account-1');
    expect(first,
        isA<MailSyncSuccess>().having((r) => r.hasMore, 'hasMore', true));
    expect(await database.messageIds(['gmail:account-1:first']), [
      'gmail:account-1:first',
    ]);
    expect(
        (await database.checkpoint('account-1:INBOX'))?.highestKnownUid, 200);

    final second = await repository.synchronize('account-1');
    expect(second,
        isA<MailSyncSuccess>().having((r) => r.hasMore, 'hasMore', false));
    expect(
        (await database.checkpoint('account-1:INBOX'))?.highestKnownUid, 400);
    expect(source.requests.map((request) => request.afterUid), [0, 200]);
    expect(source.requests.map((request) => request.expectedUidValidity),
        [null, 45]);
    expect(source.requests.map((request) => request.limit), [200, 200]);
    expect(notifications, hasLength(1));
    expect(notifications.single.single.messageId, 'gmail:account-1:later');
    expect(flushedAfterCheckpoints, [200, 400]);
  });

  test('empty sparse UID ranges advance the checkpoint in bounded pages',
      () async {
    final repository = MailboxSyncCoordinator(
      database: database,
      credentialStore: credentials,
      source: _QueuePageSource([
        _snapshot(uidNext: 601, requestedThroughUid: 200),
        _snapshot(uidNext: 601, requestedThroughUid: 400),
        _snapshot(uidNext: 601, requestedThroughUid: 600),
      ]),
    );

    for (var page = 0; page < 3; page++) {
      expect(await repository.synchronize('account-1'), isA<MailSyncSuccess>());
    }

    expect(
        (await database.checkpoint('account-1:INBOX'))?.highestKnownUid, 600);
  });

  test('a UIDVALIDITY reset refetches from the new namespace and replaces UIDs',
      () async {
    final source = _QueuePageSource([
      _snapshot(
        uidValidity: 45,
        uidNext: 41,
        requestedThroughUid: 40,
        messages: [
          _message(uid: 9, gmailId: 'stable'),
          _message(uid: 30),
        ],
      ),
      _snapshot(
        uidValidity: 92,
        uidNext: 4,
        requestedThroughUid: 3,
        messages: [
          _message(uid: 1, gmailId: 'stable'),
          _message(uid: 3, gmailId: 'new'),
        ],
      ),
    ]);
    final repository = MailboxSyncCoordinator(
      database: database,
      credentialStore: credentials,
      source: source,
      clock: () => 700,
    );

    await repository.synchronize('account-1');
    await repository.synchronize('account-1');

    final checkpoint = await database.checkpoint('account-1:INBOX');
    expect(checkpoint?.uidValidity, 92);
    expect(checkpoint?.highestKnownUid, 3);
    expect(checkpoint?.syncGeneration, 1);
    final memberships = await database.select(database.mailboxMessages).get();
    expect(memberships.map((row) => row.messageId).toSet(), {
      'gmail:account-1:stable',
      'gmail:account-1:new',
    });
    expect(source.requests[1].afterUid, 40);
    expect(source.requests[1].expectedUidValidity, 45);
  });

  test('per-account sync calls serialize and the next call reads the new UID',
      () async {
    final gate = Completer<void>();
    final source = _QueuePageSource([
      _snapshot(
          uidNext: 3,
          requestedThroughUid: 1,
          messages: [_message(uid: 1, gmailId: 'one')]),
      _snapshot(
          uidNext: 3,
          requestedThroughUid: 2,
          messages: [_message(uid: 2, gmailId: 'two')]),
    ], firstPageGate: gate);
    final repository = MailboxSyncCoordinator(
      database: database,
      credentialStore: credentials,
      source: source,
    );

    final first = repository.synchronize('account-1');
    await Future<void>.delayed(Duration.zero);
    final second = repository.synchronize('account-1');
    await Future<void>.delayed(Duration.zero);
    expect(source.requests, hasLength(1));
    expect(source.maxActive, 1);

    gate.complete();
    final results = await Future.wait([first, second]);
    expect(results, everyElement(isA<MailSyncSuccess>()));
    expect(source.requests.map((request) => request.afterUid), [0, 1]);
    expect(source.maxActive, 1);
    expect((await database.checkpoint('account-1:INBOX'))?.highestKnownUid, 2);
  });

  test(
      'pending local flags win during commit and archive remains hidden until undo',
      () async {
    final source = _QueuePageSource([
      _snapshot(
          uidNext: 6,
          requestedThroughUid: 5,
          messages: [_message(uid: 5, gmailId: 'queued')]),
    ]);
    final repository = MailboxSyncCoordinator(
      database: database,
      credentialStore: credentials,
      source: source,
      clock: () => 900,
    );
    await repository.synchronize('account-1');

    final queue = PendingMutationQueue(
      database: database,
      credentialStore: credentials,
      transport: _NoopMutationTransport(),
      clock: () => 901,
      mutationIdFactory: () => mutationIds.removeAt(0),
    );
    await queue.applyLocal(const MarkReadMutation(
      accountId: 'account-1',
      messageId: 'gmail:account-1:queued',
      mailboxId: 'account-1:INBOX',
      read: true,
    ));

    await _commitOneStaleMembership(database);
    var membership =
        await database.membershipsForMessage('gmail:account-1:queued');
    expect(membership.single.flags, contains(r'\Seen'));

    await queue.applyLocal(const ArchiveMutation(
      accountId: 'account-1',
      messageId: 'gmail:account-1:queued',
      mailboxId: 'account-1:INBOX',
    ));
    await _commitOneStaleMembership(database);
    expect(await database.membershipsForMessage('gmail:account-1:queued'),
        isEmpty);

    expect(await queue.undoPendingArchive('gmail:account-1:queued'), isTrue);
    membership = await database.membershipsForMessage('gmail:account-1:queued');
    expect(membership.single.flags, contains(r'\Seen'));
  });

  test('metadata mapper decodes envelope, Gmail labels and selected headers',
      () {
    final response = ImapUntagged([
      const ImapAtom('7'),
      const ImapAtom('FETCH'),
      ImapValueList([
        const ImapAtom('UID'),
        const ImapAtom('7'),
        const ImapAtom('FLAGS'),
        ImapValueList([const ImapAtom(r'\Seen')]),
        const ImapAtom('ENVELOPE'),
        ImapValueList([
          const ImapQuoted('17-Jul-1996 02:44:25 -0700'),
          const ImapQuoted('=?UTF-8?B?SGVsbG8=?='),
          ImapValueList([
            ImapValueList([
              const ImapQuoted('Ada'),
              const ImapNil(),
              const ImapAtom('ada'),
              const ImapAtom('example.test'),
            ]),
          ]),
        ]),
        const ImapAtom('RFC822.SIZE'),
        const ImapAtom('256'),
        const ImapAtom('X-GM-MSGID'),
        const ImapAtom('123'),
        const ImapAtom('X-GM-THRID'),
        const ImapAtom('456'),
        const ImapAtom('X-GM-LABELS'),
        ImapValueList([const ImapAtom(r'\Inbox'), const ImapQuoted('Work')]),
        const ImapAtom(
            'BODY[HEADER.FIELDS (LIST-UNSUBSCRIBE LIST-UNSUBSCRIBE-POST PRECEDENCE LIST-ID)]'),
        ImapLiteral(utf8.encode(
            'List-Unsubscribe: <mailto:leave@example.test>\r\nPrecedence: bulk\r\n')),
      ]),
    ]);

    final message = GmailFetchMetadataMapper.map(response)!;
    expect(message.uid, 7);
    expect(message.gmailMessageId, '123');
    expect(message.gmailThreadId, '456');
    expect(message.subject, 'Hello');
    expect(message.sender, 'Ada <ada@example.test>');
    expect(message.labels, {r'\Inbox', 'Work'});
    expect(message.hasListUnsubscribe, isTrue);
    expect(message.precedence, 'bulk');
    expect(message.sentAtEpochMillis,
        DateTime.utc(1996, 7, 17, 9, 44, 25).millisecondsSinceEpoch);
  });

  test('the IMAP page source restarts at UID 1 after UIDVALIDITY changes',
      () async {
    final wire = _TranscriptImapWire();
    final source = ImapInboxPageSource(
      connect: () async => ImapClient(wire),
    );

    final page = await source.fetchPage(
      email: 'owner@example.test',
      credentialUtf8: Uint8List.fromList(utf8.encode('temporary-secret')),
      afterUid: 90,
      expectedUidValidity: 45,
    );

    expect(page.inbox.uidValidity, 92);
    expect(page.requestedThroughUid, 3);
    expect(wire.commands.where((command) => command.contains(' UID FETCH')),
        hasLength(1));
    expect(wire.commands.last, contains(' UID FETCH 1:3 '));
    expect(wire.closed, isTrue);
  });

  test('the IMAP Trash source selects only the special-use Trash mailbox',
      () async {
    final wire = _TranscriptImapWire(includeTrash: true);
    final source = ImapTrashMailboxPageSource(
      connect: () async => ImapClient(wire),
    );

    final page = await source.fetchLatest(
      email: 'owner@example.test',
      credentialUtf8: Uint8List.fromList(utf8.encode('temporary-secret')),
      limit: 2,
    );

    expect(page?.remoteName, '[Gmail]/Trash');
    expect(page?.uidValidity, 92);
    expect(page?.messages, isEmpty);
    expect(wire.commands, contains('G0005 SELECT "[Gmail]/Trash"'));
    expect(
      wire.commands.any((command) => command.contains('UID FETCH 2:3')),
      isTrue,
    );
    expect(wire.closed, isTrue);
  });

  test('mutation transport errors retry network but make rejection permanent',
      () async {
    final coordinator = MailboxSyncCoordinator(
      database: database,
      credentialStore: credentials,
      source: _QueuePageSource([
        _snapshot(
          uidNext: 6,
          requestedThroughUid: 5,
          messages: [_message(uid: 5, gmailId: 'retry')],
        ),
      ]),
    );
    await coordinator.synchronize('account-1');
    final transport = _FailingMutationTransport()
      ..error = const ImapTransportException('offline');
    final queue = PendingMutationQueue(
      database: database,
      credentialStore: credentials,
      transport: transport,
      mutationIdFactory: () => 'retry-op',
      clock: () => 1000,
    );
    await queue.applyLocal(const MarkReadMutation(
      accountId: 'account-1',
      messageId: 'gmail:account-1:retry',
      read: true,
    ));

    await queue.flush('account-1');
    var pending =
        (await database.activeMutationsForAccount('account-1')).single;
    expect(pending.state, 'PENDING');
    expect(pending.retryCount, 1);
    expect(pending.lastErrorCode, 'NETWORK');

    transport.error = const ImapProtocolException('server rejected mutation');
    await queue.flush('account-1');
    pending = (await database.select(database.pendingMutations).get()).single;
    expect(pending.state, 'FAILED_PERMANENT');
    expect(pending.retryCount, 1);
    expect(pending.lastErrorCode, 'SERVER_REJECTED');
  });

  test('message composition hides Bcc and uses a deterministic Message-ID',
      () async {
    final raw = await RawMailComposer.compose(
      _outgoingMail('compose-op'),
      sentAtEpochMillis: 0,
    );
    final text = utf8.decode(raw);
    expect(text, contains('Message-ID: <compose-op@glassmail.local>'));
    expect(text, contains('To: recipient@example.test'));
    expect(text, isNot(contains('Bcc:')));
    expect(text, isNot(contains('hidden@example.test')));
    expect(text, contains('filename="report.pdf"'));
    expect(text, contains('AQID'));
    expect(text, contains('=?UTF-8?B?'));
  });

  test('uncertain SMTP outcomes are durable and never submitted twice',
      () async {
    final transport = _RecordingMailTransport()
      ..error = const SmtpUncertainDeliveryException('final reply lost');
    final queue = OutgoingMailQueue(
      database: database,
      credentialStore: credentials,
      transport: transport,
      clock: () => 2000,
    );
    final draft = _draft('uncertain-op');
    await queue.queue(draft);

    final first =
        await queue.send(_account, draft, _outgoingMail(draft.draftId));
    expect(first, const MailSendFailed(SendMailError.uncertain));
    expect(
        (await database.watchDraft(draft.draftId).first)?.status, 'UNCERTAIN');
    expect(transport.messages, hasLength(1));

    final second =
        await queue.send(_account, draft, _outgoingMail(draft.draftId));
    expect(second, const MailSendFailed(SendMailError.uncertain));
    expect(transport.messages, hasLength(1));
  });

  test(
      'safe network retry reuses the Message-ID and Sent APPEND failure does not resend',
      () async {
    final transport = _RecordingMailTransport()
      ..error = const SmtpTransportException('disconnected before DATA');
    final sentCopy = _FailingSentCopyAppender();
    final queue = OutgoingMailQueue(
      database: database,
      credentialStore: credentials,
      transport: transport,
      sentCopyAppender: sentCopy,
      clock: () => 3000,
    );
    final draft = _draft('retry-op');
    await queue.queue(draft);

    expect(
      await queue.send(_account, draft, _outgoingMail(draft.draftId)),
      const MailSendFailed(SendMailError.network),
    );
    expect((await database.watchDraft(draft.draftId).first)?.status, 'QUEUED');
    transport.error = null;
    expect(await queue.send(_account, draft, _outgoingMail(draft.draftId)),
        isA<MailSent>());
    expect((await database.watchDraft(draft.draftId).first)?.status, 'SENT');
    expect(sentCopy.calls, 1);
    expect(transport.messages, hasLength(2));
    expect(transport.messages[0].toList(), transport.messages[1].toList());
    expect(utf8.decode(transport.messages[1]),
        contains('Message-ID: <retry-op@glassmail.local>'));

    expect(await queue.send(_account, draft, _outgoingMail(draft.draftId)),
        isA<MailSent>());
    expect(transport.messages, hasLength(2));
  });
}

GmailInboxSnapshot _snapshot({
  int uidValidity = 45,
  required int uidNext,
  int messageCount = 0,
  required int requestedThroughUid,
  List<ImapMessageMetadata> messages = const [],
}) =>
    GmailInboxSnapshot(
      capabilities: const {'IMAP4REV1', 'X-GM-EXT-1'},
      mailboxes: [
        ImapMailbox(name: 'INBOX', attributes: {r'\Inbox'}),
      ],
      inbox: ImapSelectedMailbox(
        uidValidity: uidValidity,
        uidNext: uidNext,
        messageCount: messageCount,
      ),
      messages: messages,
      requestedThroughUid: requestedThroughUid,
    );

ImapMessageMetadata _message({
  required int uid,
  String? gmailId,
  Set<String> flags = const {},
}) =>
    ImapMessageMetadata(
      uid: uid,
      flags: flags,
      gmailMessageId: gmailId,
      gmailThreadId: null,
      labels: const {r'\Inbox'},
      subject: 'Subject $uid',
      sender: 'sender@example.test',
      sentAtEpochMillis: 1000 + uid,
      sizeBytes: 128,
    );

Future<void> _commitOneStaleMembership(GlassMailDatabase database) =>
    database.commitMailboxSnapshot(
      mailbox: MailboxesCompanion.insert(
        mailboxId: 'account-1:INBOX',
        accountId: 'account-1',
        remoteName: 'INBOX',
        uidValidity: 45,
        uidNext: 6,
        messageCount: 1,
      ),
      messageRows: [
        MessagesCompanion.insert(
          messageId: 'gmail:account-1:queued',
          accountId: 'account-1',
          gmailMessageId: const Value('queued'),
          subject: const Value('Stale server flags'),
          contentKind: 'PLAIN',
          bodyDownloadState: 'NOT_FETCHED',
        ),
      ],
      memberships: [
        MailboxMessagesCompanion.insert(
          mailboxId: 'account-1:INBOX',
          uid: 5,
          messageId: 'gmail:account-1:queued',
          flags: '',
          labels: r'\Inbox',
        ),
      ],
      checkpoint: SyncCheckpointsCompanion.insert(
        mailboxId: 'account-1:INBOX',
        accountId: 'account-1',
        uidValidity: 45,
        highestKnownUid: 5,
        syncGeneration: 0,
      ),
      replaceMembership: false,
    );

final class _QueuePageSource implements InboxPageSource {
  _QueuePageSource(this.pages, {this.firstPageGate});

  final List<GmailInboxSnapshot> pages;
  final Completer<void>? firstPageGate;
  final requests = <({int afterUid, int? expectedUidValidity, int limit})>[];
  int active = 0;
  int maxActive = 0;
  int _index = 0;

  @override
  Future<GmailInboxSnapshot> fetchPage({
    required String email,
    required Uint8List credentialUtf8,
    required int afterUid,
    required int? expectedUidValidity,
    int limit = maxUidSlotsPerPage,
  }) async {
    requests.add((
      afterUid: afterUid,
      expectedUidValidity: expectedUidValidity,
      limit: limit,
    ));
    active++;
    if (active > maxActive) maxActive = active;
    try {
      if (_index == 0 && firstPageGate != null) await firstPageGate!.future;
      return pages[_index++];
    } finally {
      active--;
    }
  }
}

final class _MemoryCredentialStore implements CredentialStore {
  final values = <String, Uint8List>{};

  @override
  Future<void> delete(String accountId) async {
    values.remove(accountId);
  }

  @override
  Future<T?> withCredential<T>(
    String accountId,
    FutureOr<T> Function(Uint8List credentialUtf8) useCredential,
  ) async {
    final stored = values[accountId];
    if (stored == null) return null;
    final buffer = Uint8List.fromList(stored);
    try {
      return await useCredential(buffer);
    } finally {
      buffer.fillRange(0, buffer.length, 0);
    }
  }

  @override
  Future<void> store(String accountId, List<int> credentialUtf8) async {
    values[accountId] = Uint8List.fromList(credentialUtf8);
    credentialUtf8.fillRange(0, credentialUtf8.length, 0);
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

final class _FailingMutationTransport implements PendingMutationTransport {
  Object? error;

  @override
  Future<void> apply({
    required String email,
    required Uint8List credentialUtf8,
    required PendingMutation mutation,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
  }
}

final class _TranscriptImapWire implements ImapWireConnection {
  _TranscriptImapWire({this.includeTrash = false});

  final bool includeTrash;
  final commands = <String>[];
  final _responses = <ImapResponse>[];
  bool closed = false;

  @override
  Future<void> writeCommand(String command) async {
    commands.add(command);
    final separator = command.indexOf(' ');
    final tag = command.substring(0, separator);
    final operation = command.substring(separator + 1);
    switch (operation.split(' ').first) {
      case 'CAPABILITY':
        _queueOk(tag, [
          ImapUntagged([
            const ImapAtom('CAPABILITY'),
            const ImapAtom('IMAP4rev1'),
            const ImapAtom('X-GM-EXT-1'),
          ]),
        ]);
      case 'LOGIN':
        _queueOk(tag);
      case 'LIST':
        _queueOk(tag, [
          ImapUntagged([
            const ImapAtom('LIST'),
            ImapValueList([const ImapAtom(r'\Inbox')]),
            const ImapQuoted('/'),
            const ImapQuoted('INBOX'),
          ]),
          if (includeTrash)
            ImapUntagged([
              const ImapAtom('LIST'),
              ImapValueList([
                const ImapAtom(r'\HasNoChildren'),
                const ImapAtom(r'\Trash'),
              ]),
              const ImapQuoted('/'),
              const ImapQuoted('[Gmail]/Trash'),
            ]),
        ]);
      case 'SELECT':
        _queueOk(tag, [
          ImapUntagged([const ImapAtom('2'), const ImapAtom('EXISTS')]),
          ImapUntagged([
            const ImapAtom('OK'),
            ImapValueList(
                [const ImapAtom('UIDVALIDITY'), const ImapAtom('92')]),
          ]),
          ImapUntagged([
            const ImapAtom('OK'),
            ImapValueList([const ImapAtom('UIDNEXT'), const ImapAtom('4')]),
          ]),
        ]);
      case 'UID':
        _queueOk(tag);
      default:
        throw StateError('Unexpected IMAP command: $operation');
    }
  }

  void _queueOk(String tag, [Iterable<ImapResponse> before = const []]) {
    _responses
      ..addAll(before)
      ..add(ImapTagged(tag: tag, status: 'OK', values: const []));
  }

  @override
  Future<ImapResponse> readResponse({Duration? timeout}) async {
    if (_responses.isEmpty) throw StateError('No scripted IMAP response');
    return _responses.removeAt(0);
  }

  @override
  Future<void> writeLiteral(Uint8List bytes) async =>
      throw StateError('Unexpected IMAP literal');

  @override
  Future<void> close() async {
    closed = true;
  }
}

final mutationIds = ['read-op', 'archive-op'];

const _account = MailAccount(
  accountId: 'account-1',
  email: 'owner@example.test',
  syncState: 'IDLE',
);

MailDraft _draft(String id, {DraftStatus status = DraftStatus.draft}) =>
    MailDraft(
      draftId: id,
      accountId: 'account-1',
      to: const ['recipient@example.test'],
      subject: 'A test subject',
      body: 'A test body',
      status: status,
    );

OutgoingMail _outgoingMail(String id) => OutgoingMail(
      operationId: id,
      accountId: 'account-1',
      from: 'owner@example.test',
      to: const ['recipient@example.test'],
      bcc: const ['hidden@example.test'],
      subject: 'Hello ✉',
      body: 'A private message',
      attachments: [
        OutgoingAttachment(
          fileName: '../report.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 3,
          openStream: () => Stream.value([1, 2, 3]),
        ),
      ],
    );

final class _RecordingMailTransport implements RawMailTransport {
  Object? error;
  final messages = <Uint8List>[];
  final recipients = <List<String>>[];

  @override
  Future<void> send({
    required String email,
    required Uint8List credentialUtf8,
    required List<String> recipients,
    required Uint8List rawMessage,
  }) async {
    this.recipients.add(List.of(recipients));
    messages.add(Uint8List.fromList(rawMessage));
    final failure = error;
    if (failure != null) throw failure;
  }
}

final class _FailingSentCopyAppender implements SentCopyAppender {
  int calls = 0;

  @override
  Future<void> append({
    required String email,
    required Uint8List credentialUtf8,
    required Uint8List rawMessage,
  }) async {
    calls++;
    throw StateError('The Sent folder is unavailable');
  }
}
