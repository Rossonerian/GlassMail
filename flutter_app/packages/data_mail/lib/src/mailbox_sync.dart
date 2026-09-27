import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:glassmail_core_database/glassmail_core_database.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

const int maxUidSlotsPerPage = 200;

abstract interface class InboxPageSource {
  /// Fetches at most [maxUidSlotsPerPage] UID slots from INBOX.
  ///
  /// When [expectedUidValidity] differs from the selected mailbox, the source
  /// must restart the page at UID 1. [credentialUtf8] is borrowed and must not
  /// be retained after this future completes.
  Future<GmailInboxSnapshot> fetchPage({
    required String email,
    required Uint8List credentialUtf8,
    required int afterUid,
    required int? expectedUidValidity,
    int limit = maxUidSlotsPerPage,
  });
}

typedef ImapClientConnector = Future<ImapClient> Function();

/// Gmail IMAP adapter for one bounded INBOX UID page.
final class ImapInboxPageSource implements InboxPageSource {
  ImapInboxPageSource({ImapClientConnector? connect})
      : _connect = connect ?? ImapClient.connect;

  final ImapClientConnector _connect;

  @override
  Future<GmailInboxSnapshot> fetchPage({
    required String email,
    required Uint8List credentialUtf8,
    required int afterUid,
    required int? expectedUidValidity,
    int limit = maxUidSlotsPerPage,
  }) async {
    if (limit < 1 || limit > maxUidSlotsPerPage) {
      throw ArgumentError.value(limit, 'limit', 'Must be in 1..200');
    }
    if (afterUid < 0) throw ArgumentError.value(afterUid, 'afterUid');

    ImapClient? client;
    try {
      client = await _connect();
      final preAuthCapabilities = await client.capability();
      await client.login(email, credentialUtf8);
      final capabilities = {
        ...preAuthCapabilities,
        ...await client.capability(),
      };
      final mailboxes = await client.listMailboxes();
      final inbox = await client.selectMailbox('INBOX');
      final reset = expectedUidValidity != null &&
          expectedUidValidity != inbox.uidValidity;
      final effectiveAfterUid = reset ? 0 : afterUid;
      final firstUid = max(1, effectiveAfterUid + 1);
      final lastUid = min(inbox.uidNext - 1, effectiveAfterUid + limit);
      final rawMessages = lastUid < firstUid
          ? const <ImapUntagged>[]
          : await client.fetchMetadata(
              '$firstUid:$lastUid',
              gmailExtensions: capabilities.contains('X-GM-EXT-1'),
            );

      return GmailInboxSnapshot(
        capabilities: capabilities,
        mailboxes: mailboxes
            .map((mailbox) => ImapMailbox(
                  name: mailbox.name,
                  attributes: mailbox.attributes,
                ))
            .toList(),
        inbox: ImapSelectedMailbox(
          uidValidity: inbox.uidValidity,
          uidNext: inbox.uidNext,
          messageCount: inbox.messageCount,
        ),
        messages: rawMessages
            .map(GmailFetchMetadataMapper.map)
            .whereType<ImapMessageMetadata>()
            .toList(),
        requestedThroughUid: max(0, lastUid),
      );
    } on ImapAuthenticationException {
      rethrow;
    } on ImapTransportException {
      rethrow;
    } on ImapProtocolException {
      rethrow;
    } on SocketException {
      throw const ImapTransportException('IMAP connection failed');
    } on TimeoutException {
      throw const ImapTransportException('IMAP connection timed out');
    } finally {
      await client?.close();
    }
  }
}

/// Bounded latest-page source for a provider's special-use Sent mailbox.
abstract interface class SentMailboxPageSource {
  Future<SentMailboxSnapshot?> fetchLatest({
    required String email,
    required Uint8List credentialUtf8,
    int limit = maxUidSlotsPerPage,
  });
}

final class SentMailboxSnapshot {
  SentMailboxSnapshot({
    required this.remoteName,
    required this.uidValidity,
    required this.uidNext,
    required this.messageCount,
    required this.gmailExtensions,
    required List<ImapMessageMetadata> messages,
  }) : messages = List.unmodifiable(messages);

  final String remoteName;
  final int uidValidity;
  final int uidNext;
  final int messageCount;
  final bool gmailExtensions;
  final List<ImapMessageMetadata> messages;
}

final class ImapSentMailboxPageSource implements SentMailboxPageSource {
  ImapSentMailboxPageSource({ImapClientConnector? connect})
      : _connect = connect ?? ImapClient.connect;

  final ImapClientConnector _connect;

  @override
  Future<SentMailboxSnapshot?> fetchLatest({
    required String email,
    required Uint8List credentialUtf8,
    int limit = maxUidSlotsPerPage,
  }) async {
    if (limit < 1 || limit > maxUidSlotsPerPage) {
      throw ArgumentError.value(limit, 'limit', 'Must be in 1..200');
    }
    ImapClient? client;
    try {
      client = await _connect();
      final preAuthCapabilities = await client.capability();
      await client.login(email, credentialUtf8);
      final capabilities = {
        ...preAuthCapabilities,
        ...await client.capability(),
      };
      final mailboxes = await client.listMailboxes();
      final sent = mailboxes
              .where((mailbox) => mailbox.attributes
                  .any((attribute) => attribute.toLowerCase() == r'\sent'))
              .firstOrNull ??
          mailboxes
              .where((mailbox) => const {
                    '[gmail]/sent mail',
                    'sent',
                    'sent items',
                  }.contains(mailbox.name.toLowerCase()))
              .firstOrNull;
      if (sent == null) return null;

      final selected = await client.selectMailbox(sent.name);
      final lastUid = selected.uidNext - 1;
      final firstUid = max(1, lastUid - limit + 1);
      final responses = lastUid < firstUid
          ? const <ImapUntagged>[]
          : await client.fetchMetadata(
              '$firstUid:$lastUid',
              gmailExtensions: capabilities.contains('X-GM-EXT-1'),
            );
      return SentMailboxSnapshot(
        remoteName: sent.name,
        uidValidity: selected.uidValidity,
        uidNext: selected.uidNext,
        messageCount: selected.messageCount,
        gmailExtensions: capabilities.contains('X-GM-EXT-1'),
        messages: responses
            .map(GmailFetchMetadataMapper.map)
            .whereType<ImapMessageMetadata>()
            .toList(growable: false),
      );
    } on ImapAuthenticationException {
      rethrow;
    } on ImapTransportException {
      rethrow;
    } on ImapProtocolException {
      rethrow;
    } on SocketException {
      throw const ImapTransportException('IMAP connection failed');
    } on TimeoutException {
      throw const ImapTransportException('IMAP connection timed out');
    } finally {
      await client?.close();
    }
  }
}

abstract interface class TrashMailboxPageSource {
  Future<TrashMailboxSnapshot?> fetchLatest({
    required String email,
    required Uint8List credentialUtf8,
    int limit = maxUidSlotsPerPage,
  });
}

final class TrashMailboxSnapshot {
  TrashMailboxSnapshot({
    required this.remoteName,
    required this.uidValidity,
    required this.uidNext,
    required this.messageCount,
    required this.gmailExtensions,
    required List<ImapMessageMetadata> messages,
  }) : messages = List.unmodifiable(messages);

  final String remoteName;
  final int uidValidity;
  final int uidNext;
  final int messageCount;
  final bool gmailExtensions;
  final List<ImapMessageMetadata> messages;
}

final class ImapTrashMailboxPageSource implements TrashMailboxPageSource {
  ImapTrashMailboxPageSource({ImapClientConnector? connect})
      : _connect = connect ?? ImapClient.connect;

  final ImapClientConnector _connect;

  @override
  Future<TrashMailboxSnapshot?> fetchLatest({
    required String email,
    required Uint8List credentialUtf8,
    int limit = maxUidSlotsPerPage,
  }) async {
    if (limit < 1 || limit > maxUidSlotsPerPage) {
      throw ArgumentError.value(limit, 'limit', 'Must be in 1..200');
    }
    ImapClient? client;
    try {
      client = await _connect();
      final preAuthCapabilities = await client.capability();
      await client.login(email, credentialUtf8);
      final capabilities = {
        ...preAuthCapabilities,
        ...await client.capability(),
      };
      final mailboxes = await client.listMailboxes();
      final trash = mailboxes
              .where((mailbox) => mailbox.attributes
                  .any((attribute) => attribute.toLowerCase() == r'\trash'))
              .firstOrNull ??
          mailboxes
              .where((mailbox) => const {
                    '[gmail]/trash',
                    'trash',
                    'bin',
                  }.contains(mailbox.name.toLowerCase()))
              .firstOrNull;
      if (trash == null) return null;

      final selected = await client.selectMailbox(trash.name);
      final lastUid = selected.uidNext - 1;
      final firstUid = max(1, lastUid - limit + 1);
      final responses = lastUid < firstUid
          ? const <ImapUntagged>[]
          : await client.fetchMetadata(
              '$firstUid:$lastUid',
              gmailExtensions: capabilities.contains('X-GM-EXT-1'),
            );
      return TrashMailboxSnapshot(
        remoteName: trash.name,
        uidValidity: selected.uidValidity,
        uidNext: selected.uidNext,
        messageCount: selected.messageCount,
        gmailExtensions: capabilities.contains('X-GM-EXT-1'),
        messages: responses
            .map(GmailFetchMetadataMapper.map)
            .whereType<ImapMessageMetadata>()
            .toList(growable: false),
      );
    } on ImapAuthenticationException {
      rethrow;
    } on ImapTransportException {
      rethrow;
    } on ImapProtocolException {
      rethrow;
    } on SocketException {
      throw const ImapTransportException('IMAP connection failed');
    } on TimeoutException {
      throw const ImapTransportException('IMAP connection timed out');
    } finally {
      await client?.close();
    }
  }
}

abstract final class GmailFetchMetadataMapper {
  static ImapMessageMetadata? map(ImapUntagged response) {
    final values = response.values;
    if (values.length < 3 || values[1].atomValue?.toUpperCase() != 'FETCH') {
      return null;
    }
    final fields = values[2].listValue;
    final uid = int.tryParse(fields.attribute('UID')?.atomValue ?? '');
    if (uid == null || uid <= 0) return null;

    final envelope = fields.attribute('ENVELOPE')?.listValue ?? const [];
    final subject = MimeDecoder.decodeMimeWords(_stringAt(envelope, 1));
    final from = _addressAt(_listAt(envelope, 2));
    final headerIndex = fields.indexWhere(
      (value) => value.atomValue?.toUpperCase().startsWith('BODY[') ?? false,
    );
    final headerLiteral =
        headerIndex < 0 ? null : fields[headerIndex + 1].literalValue;
    final headers = _parseSelectedHeaders(headerLiteral ?? const []);
    final labels = fields
            .attribute('X-GM-LABELS')
            ?.listValue
            .map((value) => value.atomValue)
            .whereType<String>()
            .toSet() ??
        const <String>{};

    return ImapMessageMetadata(
      uid: uid,
      flags: fields
              .attribute('FLAGS')
              ?.listValue
              .map((value) => value.atomValue)
              .whereType<String>()
              .toSet() ??
          const <String>{},
      gmailMessageId: fields.attribute('X-GM-MSGID')?.atomValue,
      gmailThreadId: fields.attribute('X-GM-THRID')?.atomValue,
      labels: labels,
      subject: subject,
      sender: from,
      sentAtEpochMillis: _parseImapDate(_stringAt(envelope, 0)),
      sizeBytes: int.tryParse(fields.attribute('RFC822.SIZE')?.atomValue ?? ''),
      hasListUnsubscribe: (headers['list-unsubscribe'] ?? '').isNotEmpty,
      precedence: headers['precedence'],
      listId: headers['list-id'],
      listUnsubscribe: headers['list-unsubscribe'],
      listUnsubscribePost: headers['list-unsubscribe-post'],
    );
  }

  static String? _stringAt(List<ImapValue> values, int index) =>
      index >= 0 && index < values.length ? values[index].atomValue : null;

  static List<ImapValue> _listAt(List<ImapValue> values, int index) =>
      index >= 0 && index < values.length ? values[index].listValue : const [];

  static String? _addressAt(List<ImapValue> addresses) {
    for (final address in addresses) {
      final fields = address.listValue;
      if (fields.length < 4) continue;
      final personal = MimeDecoder.decodeMimeWords(fields[0].atomValue)
          .trim()
          .replaceAll(RegExp(r'^"|"$'), '');
      final mailbox = fields[2].atomValue;
      final host = fields[3].atomValue;
      final email = [mailbox, host]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join('@');
      if (personal.isNotEmpty && email.isNotEmpty) {
        return '$personal <$email>';
      }
      if (personal.isNotEmpty) return personal;
      if (email.isNotEmpty) return email;
    }
    return null;
  }

  static Map<String, String> _parseSelectedHeaders(List<int> bytes) {
    final raw = utf8.decode(bytes, allowMalformed: true);
    final result = <String, String>{};
    String? name;
    final value = StringBuffer();
    void flush() {
      if (name != null) result[name] = value.toString().trim();
      value.clear();
    }

    for (final line in raw.split(RegExp(r'\r?\n'))) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (name != null) value.write(' ${line.trim()}');
        continue;
      }
      flush();
      final colon = line.indexOf(':');
      if (colon > 0) {
        name = line.substring(0, colon).trim().toLowerCase();
        value.write(line.substring(colon + 1).trim());
      } else {
        name = null;
      }
    }
    flush();
    return result;
  }

  static int? _parseImapDate(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d{1,2})-([A-Za-z]{3})-(\d{4}) (\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2})$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final month = months[match[2]!.toLowerCase()];
    if (month == null) return null;
    final local = DateTime.utc(
      int.parse(match[3]!),
      month,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    );
    final offset = int.parse(match[8]!) * 60 + int.parse(match[9]!);
    return local
        .subtract(Duration(minutes: match[7] == '+' ? offset : -offset))
        .millisecondsSinceEpoch;
  }
}

typedef NewMailCallback = FutureOr<void> Function(List<MailListItem> messages);

/// Persists one serial, bounded UID page at a time before advertising progress.
final class MailboxSyncCoordinator {
  MailboxSyncCoordinator({
    required GlassMailDatabase database,
    required CredentialStore credentialStore,
    required InboxPageSource source,
    int Function()? clock,
    NewMailCallback? onNewMessages,
    Future<void> Function(String accountId)? flushPendingMutations,
  })  : _database = database,
        _credentialStore = credentialStore,
        _source = source,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _onNewMessages = onNewMessages,
        _flushPendingMutations = flushPendingMutations;

  final GlassMailDatabase _database;
  final CredentialStore _credentialStore;
  final InboxPageSource _source;
  final int Function() _clock;
  final NewMailCallback? _onNewMessages;
  final Future<void> Function(String accountId)? _flushPendingMutations;
  final Map<String, Future<void>> _accountTails = {};

  Future<MailSyncResult> synchronize(String accountId) =>
      _serialized(accountId, () => _synchronize(accountId));

  Future<MailSyncResult> _synchronize(String accountId) async {
    final account = await _database.accountById(accountId);
    if (account == null) return const MailSyncFailure(MailSyncError.protocol);

    await _database.setAccountSyncState(accountId, 'SYNCING');
    final mailboxId = '$accountId:INBOX';
    final previousCheckpoint = await _database.checkpoint(mailboxId);
    try {
      final snapshot = await _credentialStore.withCredential(
        accountId,
        (credential) => _source.fetchPage(
          email: account.email,
          credentialUtf8: credential,
          afterUid: previousCheckpoint?.highestKnownUid ?? 0,
          expectedUidValidity: previousCheckpoint?.uidValidity,
        ),
      );
      if (snapshot == null) {
        await _database.setAccountSyncState(
            accountId, 'ERROR_MISSING_CREDENTIAL');
        return const MailSyncFailure(MailSyncError.missingCredential);
      }

      final result = await _commitPage(
        accountId: accountId,
        snapshot: snapshot,
        previousCheckpoint: previousCheckpoint,
      );
      if (result is MailSyncSuccess) {
        await _flushPendingMutations?.call(accountId);
      }
      return result;
    } on ImapAuthenticationException {
      await _database.setAccountSyncState(accountId, 'ERROR_AUTHENTICATION');
      return const MailSyncFailure(MailSyncError.authentication);
    } on ImapTransportException {
      await _database.setAccountSyncState(accountId, 'ERROR_NETWORK');
      return const MailSyncFailure(MailSyncError.network);
    } on ImapProtocolException {
      await _database.setAccountSyncState(accountId, 'ERROR_PROTOCOL');
      return const MailSyncFailure(MailSyncError.protocol);
    } on SocketException {
      await _database.setAccountSyncState(accountId, 'ERROR_NETWORK');
      return const MailSyncFailure(MailSyncError.network);
    } on TimeoutException {
      await _database.setAccountSyncState(accountId, 'ERROR_NETWORK');
      return const MailSyncFailure(MailSyncError.network);
    } on FormatException {
      await _database.setAccountSyncState(accountId, 'ERROR_PROTOCOL');
      return const MailSyncFailure(MailSyncError.protocol);
    }
  }

  Future<MailSyncResult> _commitPage({
    required String accountId,
    required GmailInboxSnapshot snapshot,
    required SyncCheckpoint? previousCheckpoint,
  }) async {
    final inbox = snapshot.inbox;
    if (inbox.uidValidity <= 0 ||
        inbox.uidNext < 1 ||
        inbox.messageCount < 0 ||
        snapshot.requestedThroughUid < 0 ||
        snapshot.requestedThroughUid > inbox.uidNext - 1) {
      await _database.setAccountSyncState(accountId, 'ERROR_PROTOCOL');
      return const MailSyncFailure(MailSyncError.protocol);
    }

    final reset = previousCheckpoint != null &&
        previousCheckpoint.uidValidity != inbox.uidValidity;
    final priorUid = reset ? 0 : previousCheckpoint?.highestKnownUid ?? 0;
    if (snapshot.requestedThroughUid > priorUid + maxUidSlotsPerPage) {
      await _database.setAccountSyncState(accountId, 'ERROR_PROTOCOL');
      return const MailSyncFailure(MailSyncError.protocol);
    }
    final seenUids = <int>{};
    for (final message in snapshot.messages) {
      if (message.uid <= 0 ||
          message.uid > snapshot.requestedThroughUid ||
          !seenUids.add(message.uid)) {
        await _database.setAccountSyncState(accountId, 'ERROR_PROTOCOL');
        return const MailSyncFailure(MailSyncError.protocol);
      }
    }

    final messageIds = snapshot.messages
        .map((message) =>
            canonicalMessageId(accountId, inbox.uidValidity, message))
        .toList(growable: false);
    final existingIds = (await _database.messageIds(messageIds)).toSet();
    final notificationState =
        await _database.notificationStateForAccount(accountId);
    final shouldNotify = notificationState?.baselineEstablished == 1;
    final newMessages = shouldNotify
        ? snapshot.messages
            .where((message) => !existingIds.contains(
                  canonicalMessageId(accountId, inbox.uidValidity, message),
                ))
            .map(
                (message) => _toListItem(accountId, inbox.uidValidity, message))
            .toList(growable: false)
        : const <MailListItem>[];

    final mailboxRows = snapshot.mailboxes.map((mailbox) {
      final isInbox = mailbox.name.toUpperCase() == 'INBOX';
      return MailboxesCompanion.insert(
        mailboxId: isInbox ? '$accountId:INBOX' : '$accountId:${mailbox.name}',
        accountId: accountId,
        remoteName: isInbox ? 'INBOX' : mailbox.name,
        uidValidity: isInbox ? inbox.uidValidity : 0,
        uidNext: isInbox ? inbox.uidNext : 0,
        messageCount: isInbox ? inbox.messageCount : 0,
      );
    }).toList();
    if (!snapshot.mailboxes
        .any((mailbox) => mailbox.name.toUpperCase() == 'INBOX')) {
      mailboxRows.add(MailboxesCompanion.insert(
        mailboxId: '$accountId:INBOX',
        accountId: accountId,
        remoteName: 'INBOX',
        uidValidity: inbox.uidValidity,
        uidNext: inbox.uidNext,
        messageCount: inbox.messageCount,
      ));
    }

    final messageRows = <MessagesCompanion>[];
    final membershipRows = <MailboxMessagesCompanion>[];
    for (final message in snapshot.messages) {
      final messageId =
          canonicalMessageId(accountId, inbox.uidValidity, message);
      messageRows.add(MessagesCompanion.insert(
        messageId: messageId,
        accountId: accountId,
        gmailMessageId: Value(message.gmailMessageId),
        gmailThreadId: Value(message.gmailThreadId),
        subject: Value(message.subject),
        sender: Value(message.sender),
        sentAtEpochMillis: Value(message.sentAtEpochMillis),
        sizeBytes: Value(message.sizeBytes),
        category: Value(_resolveCategory(message)),
        listUnsubscribe: Value(message.listUnsubscribe),
        listUnsubscribePost: Value(message.listUnsubscribePost),
        contentKind: 'PLAIN',
        bodyDownloadState: 'NOT_FETCHED',
      ));
      membershipRows.add(MailboxMessagesCompanion.insert(
        mailboxId: '$accountId:INBOX',
        uid: message.uid,
        messageId: messageId,
        flags: (message.flags.toList()..sort()).join(' '),
        labels: (message.labels.toList()..sort()).join('\u001f'),
      ));
    }

    final now = _clock();
    final previousGeneration = previousCheckpoint?.syncGeneration ?? 0;
    await _database.commitMailboxSnapshot(
      mailbox: MailboxesCompanion.insert(
        mailboxId: '$accountId:INBOX',
        accountId: accountId,
        remoteName: 'INBOX',
        uidValidity: inbox.uidValidity,
        uidNext: inbox.uidNext,
        messageCount: inbox.messageCount,
      ),
      messageRows: messageRows,
      memberships: membershipRows,
      checkpoint: SyncCheckpointsCompanion.insert(
        mailboxId: '$accountId:INBOX',
        accountId: accountId,
        uidValidity: inbox.uidValidity,
        highestKnownUid: max(
          reset ? 0 : previousCheckpoint?.highestKnownUid ?? 0,
          max(
            snapshot.requestedThroughUid,
            snapshot.messages
                .fold<int>(0, (high, message) => max(high, message.uid)),
          ),
        ),
        syncGeneration: previousGeneration + (reset ? 1 : 0),
        lastSuccessfulSyncEpochMillis: Value(now),
      ),
      replaceMembership: reset,
      notificationState: NotificationStateCompanion.insert(
        accountId: accountId,
        baselineEstablished: 1,
      ),
      gmailExtensionsEnabled: snapshot.supportsGmailExtensions,
      successfulSyncTimestamp: now,
    );

    if (newMessages.isNotEmpty && _onNewMessages != null) {
      await _onNewMessages(newMessages);
    }
    return MailSyncSuccess(
      messageCount: snapshot.messages.length,
      gmailExtensionsEnabled: snapshot.supportsGmailExtensions,
      hasMore: snapshot.hasMoreUids,
    );
  }

  Future<T> _serialized<T>(
      String accountId, Future<T> Function() action) async {
    final previous = _accountTails[accountId] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = release.future;
    _accountTails[accountId] = tail;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_accountTails[accountId], tail)) {
        _accountTails.remove(accountId);
      }
    }
  }
}

String canonicalMessageId(
  String accountId,
  int uidValidity,
  ImapMessageMetadata message,
) =>
    message.gmailMessageId == null
        ? 'imap:$accountId:$uidValidity:${message.uid}'
        : 'gmail:$accountId:${message.gmailMessageId}';

MailListItem _toListItem(
  String accountId,
  int uidValidity,
  ImapMessageMetadata message,
) =>
    MailListItem(
      messageId: canonicalMessageId(accountId, uidValidity, message),
      threadId: message.gmailThreadId,
      sender: message.sender ?? '',
      subject: message.subject ?? '',
      preview: 'New message',
      sentAtEpochMillis: message.sentAtEpochMillis,
      unread: !message.flags.contains(r'\Seen'),
      starred: message.flags.contains(r'\Flagged'),
      labels: message.labels.toList(),
      hasAttachment: false,
      category: _resolveCategory(message),
    );

String _resolveCategory(ImapMessageMetadata message) {
  for (final label in message.labels) {
    for (final category in MailCategory.all) {
      if (label.toUpperCase() == r'\CATEGORY' + category) return category;
    }
  }
  final sender = message.sender?.toLowerCase() ?? '';
  final host =
      sender.contains('@') ? sender.split('@').last.split('>').first : '';
  final subject = message.subject?.toLowerCase() ?? '';
  final listMail = message.precedence?.toLowerCase() == 'list' ||
      (message.listId?.isNotEmpty ?? false);
  if ({'facebook.com', 'linkedin.com', 'instagram.com', 'twitter.com', 'x.com'}
      .any((domain) => host == domain || host.endsWith('.$domain'))) {
    return MailCategory.social;
  }
  if (listMail ||
      subject.contains('discussion') ||
      subject.contains('new reply')) {
    return MailCategory.forums;
  }
  if (message.precedence?.toLowerCase() == 'bulk' ||
      message.hasListUnsubscribe) {
    return MailCategory.promotions;
  }
  if (sender.contains('no-reply') ||
      sender.contains('noreply') ||
      ['security alert', 'verification code', 'receipt', 'shipping update']
          .any(subject.contains)) {
    return MailCategory.updates;
  }
  if (['sale', 'discount', 'special offer', 'newsletter']
      .any(subject.contains)) {
    return MailCategory.promotions;
  }
  return MailCategory.primary;
}
