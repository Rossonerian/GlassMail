import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'imap_protocol.dart';
import 'mime_decoder.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';

const int maxImapAppendBytes = 32 * 1024 * 1024;
const Duration defaultImapConnectTimeout = Duration(seconds: 15);
const Duration defaultImapReadTimeout = Duration(seconds: 30);

final class ImapAuthenticationException implements Exception {
  const ImapAuthenticationException();

  @override
  String toString() => 'IMAP authentication failed';
}

final class ImapTransportException implements Exception {
  const ImapTransportException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ImapTransportException: $message';
}

abstract interface class ImapWireConnection {
  Future<ImapResponse> readResponse({Duration? timeout});
  Future<void> writeCommand(String command);
  Future<void> writeLiteral(Uint8List bytes);
  Future<void> close();
}

/// A single serialized IMAP session. Socket TLS uses Dart's default trust and
/// hostname verification; no bad-certificate callback or override is exposed.
final class ImapClient {
  ImapClient(this._wire);

  final ImapWireConnection _wire;
  int _commandNumber = 1;
  bool _closed = false;
  String? _selectedMailboxName;

  static Future<ImapClient> connect({
    String host = 'imap.gmail.com',
    int port = 993,
    Duration connectTimeout = defaultImapConnectTimeout,
    Duration readTimeout = defaultImapReadTimeout,
  }) async {
    final wire = await _SecureSocketImapWire.connect(
      host: host,
      port: port,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
    );
    final client = ImapClient(wire);
    try {
      final greeting = await wire.readResponse(timeout: readTimeout);
      if (greeting is! ImapUntagged ||
          greeting.values.firstOrNull?.atomValue?.toUpperCase() != 'OK') {
        throw const ImapProtocolException('IMAP server rejected connection');
      }
      return client;
    } on Object {
      await wire.close();
      rethrow;
    }
  }

  Future<void> login(String email, Uint8List credentialUtf8) async {
    final password = utf8.decode(credentialUtf8, allowMalformed: false);
    try {
      await _execute(
        'LOGIN ${_quote(email)} ${_quote(password)}',
        authenticationCommand: true,
      );
    } finally {
      // The immutable String remains subject to Dart GC; only caller-owned byte
      // buffers can be cleared deterministically.
    }
  }

  Future<Set<String>> capability() async {
    final responses = await _execute('CAPABILITY');
    return responses
        .whereType<ImapUntagged>()
        .where(
          (response) =>
              response.values.firstOrNull?.atomValue?.toUpperCase() ==
              'CAPABILITY',
        )
        .expand((response) => response.values.skip(1))
        .map((value) => value.atomValue?.toUpperCase())
        .whereType<String>()
        .toSet();
  }

  Future<List<ImapMailboxRecord>> listMailboxes() async {
    final responses = await _execute('LIST "" "*"');
    return responses
        .whereType<ImapUntagged>()
        .map((response) {
          final values = response.values;
          if (values.firstOrNull?.atomValue?.toUpperCase() != 'LIST' ||
              values.length < 4) {
            return null;
          }
          return ImapMailboxRecord(
            attributes: values[1]
                .listValue
                .map((value) => value.atomValue)
                .whereType<String>()
                .toSet(),
            delimiter: values[2].atomValue,
            name: values[3].atomValue ??
                utf8.decode(values[3].literalValue ?? const []),
          );
        })
        .whereType<ImapMailboxRecord>()
        .toList(growable: false);
  }

  Future<ImapSelectedMailboxRecord> selectMailbox(String mailbox) async {
    final responses = await _execute('SELECT ${_quote(mailbox)}');
    int? uidValidity;
    int? uidNext;
    var messageCount = 0;
    for (final response in responses.whereType<ImapUntagged>()) {
      final values = response.values;
      if (values.length >= 2 &&
          values[1].atomValue?.toUpperCase() == 'EXISTS') {
        messageCount = int.tryParse(values[0].atomValue ?? '') ?? messageCount;
      }
      for (final value in values) {
        final code = value.listValue;
        uidValidity ??= int.tryParse(
          code.attribute('UIDVALIDITY')?.atomValue ?? '',
        );
        uidNext ??= int.tryParse(code.attribute('UIDNEXT')?.atomValue ?? '');
      }
    }
    if (uidValidity == null || uidNext == null) {
      throw const ImapProtocolException(
        'SELECT response missing UIDVALIDITY or UIDNEXT',
      );
    }
    _selectedMailboxName = mailbox;
    return ImapSelectedMailboxRecord(
      uidValidity: uidValidity,
      uidNext: uidNext,
      messageCount: messageCount,
    );
  }

  Future<List<ImapUntagged>> fetchMetadata(
    String uidRange, {
    required bool gmailExtensions,
  }) async {
    if (!_validUidRange.hasMatch(uidRange) || uidRange.length > 1024) {
      throw ArgumentError.value(uidRange, 'uidRange', 'Invalid UID set');
    }
    final fields = StringBuffer(
      'UID FLAGS ENVELOPE INTERNALDATE RFC822.SIZE',
    );
    if (gmailExtensions) {
      fields.write(' X-GM-MSGID X-GM-THRID X-GM-LABELS');
    }
    fields.write(
      ' BODY.PEEK[HEADER.FIELDS (LIST-UNSUBSCRIBE LIST-UNSUBSCRIBE-POST PRECEDENCE LIST-ID)]',
    );
    final responses = await _execute('UID FETCH $uidRange ($fields)');
    return responses
        .whereType<ImapUntagged>()
        .where(
          (response) =>
              response.values.length > 1 &&
              response.values[1].atomValue?.toUpperCase() == 'FETCH',
        )
        .toList(growable: false);
  }

  Future<Uint8List> fetchBodyPart(int uid, String partId) async {
    if (uid <= 0 || !_validPartId.hasMatch(partId)) {
      throw ArgumentError('Invalid attachment reference');
    }
    final responses = await _execute('UID FETCH $uid (BODY.PEEK[$partId])');
    return _firstFetchLiteral(responses, 'Attachment payload missing');
  }

  Future<ParsedMessageBody> fetchMessageBody(int uid) async {
    if (uid <= 0) throw ArgumentError.value(uid, 'uid');
    final responses = await _execute('UID FETCH $uid (BODY.PEEK[])');
    final rawMessage = _firstFetchLiteral(
      responses,
      'Message body payload missing',
    );
    return MimeDecoder.parseRfc822(rawMessage);
  }

  Future<Uint8List> fetchRawMessage(int uid) async {
    if (uid <= 0) throw ArgumentError.value(uid, 'uid');
    final responses = await _execute('UID FETCH $uid (BODY.PEEK[])');
    return _firstFetchLiteral(responses, 'Message body payload missing');
  }

  Future<List<ImapRemoteDraft>> fetchRemoteDrafts({int limit = 100}) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Must be in 1..500');
    }
    final mailboxes = await listMailboxes();
    final mailbox = mailboxes
            .where((entry) => entry.attributes
                .any((attribute) => attribute.toLowerCase() == r'\drafts'))
            .map((entry) => entry.name)
            .firstOrNull ??
        const ['[Gmail]/Drafts', 'Drafts', 'Draft']
            .where((name) => mailboxes.any(
                  (entry) => entry.name.toLowerCase() == name.toLowerCase(),
                ))
            .firstOrNull;
    if (mailbox == null) return const [];
    final selected = await selectMailbox(mailbox);
    final searchResponses = await _execute('UID SEARCH ALL');
    final uids = <int>{};
    for (final response in searchResponses.whereType<ImapUntagged>()) {
      if (response.values.firstOrNull?.atomValue?.toUpperCase() != 'SEARCH') {
        continue;
      }
      for (final value in response.values.skip(1)) {
        final uid = int.tryParse(value.atomValue ?? '');
        if (uid != null && uid > 0) uids.add(uid);
      }
    }
    final selectedUids = uids.toList()..sort((a, b) => b.compareTo(a));
    final result = <ImapRemoteDraft>[];
    for (final uid in selectedUids.take(limit)) {
      final responses = await _execute(
        'UID FETCH $uid (UID INTERNALDATE BODY.PEEK[])',
      );
      final raw = _firstFetchLiteral(responses, 'Draft body payload missing');
      final parsed = MimeDecoder.parseRfc822(raw);
      final header = parsed.headers;
      final messageId = header['message-id'];
      final stableId = RegExp(
        r'<([^<>@]+)@glassmail\.local>',
        caseSensitive: false,
      ).firstMatch(messageId ?? '')?.group(1);
      final internalDate = responses
          .whereType<ImapUntagged>()
          .where((response) =>
              response.values.length > 2 &&
              response.values[1].atomValue?.toUpperCase() == 'FETCH')
          .map((response) =>
              response.values[2].listValue.attribute('INTERNALDATE')?.atomValue)
          .whereType<String>()
          .firstOrNull;
      result.add(ImapRemoteDraft(
        uid: uid,
        uidValidity: selected.uidValidity,
        draftId: stableId,
        to: _parseAddressList(header['to']),
        cc: _parseAddressList(header['cc']),
        bcc: _parseAddressList(header['bcc']),
        subject: MimeDecoder.decodeMimeWords(header['subject']),
        body: parsed.plainText ?? parsed.htmlText ?? '',
        inReplyTo: header['in-reply-to'],
        references: _parseReferences(header['references']),
        updatedAtEpochMillis: _parseImapDate(internalDate) ??
            DateTime.tryParse(header['date'] ?? '')?.millisecondsSinceEpoch ??
            0,
      ));
    }
    return result;
  }

  /// Appends the replacement first, then removes older copies with the same
  /// stable Message-ID. If APPEND fails, the prior remote draft remains intact.
  Future<void> replaceRemoteDraft(
    String draftId,
    Uint8List rawMessage, {
    required String draftsMailbox,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(draftId)) {
      throw ArgumentError.value(draftId, 'draftId');
    }
    final capabilities = await capability();
    if (!capabilities.contains('UIDPLUS')) {
      throw const ImapProtocolException(
        'Server does not support safe remote draft replacement',
      );
    }
    final before = await _draftUids(draftId);
    await append(draftsMailbox, rawMessage, flag: r'\Draft');
    final after = await _draftUids(draftId);
    final newUid = after.difference(before).fold<int?>(
        null, (best, uid) => best == null || uid > best ? uid : best);
    if (newUid == null) {
      throw const ImapProtocolException(
        'Draft APPEND completed without a discoverable new UID',
      );
    }
    final stale = after.where((uid) => uid != newUid).toList()..sort();
    if (stale.isNotEmpty) {
      final uidSet = stale.join(',');
      await _execute('UID STORE $uidSet +FLAGS.SILENT (\\Deleted)');
      await _execute('UID EXPUNGE $uidSet');
    }
  }

  Future<void> storeGmailLabel(
    int uid,
    String label, {
    required bool add,
  }) async {
    if (uid <= 0) throw ArgumentError.value(uid, 'uid');
    final operation = add ? '+' : '-';
    await _execute(
      'UID STORE $uid $operation'
      'X-GM-LABELS.SILENT (${_quote(label)})',
    );
  }

  Future<void> applyMutation({
    required int uid,
    required String type,
    String? label,
  }) async {
    if (uid <= 0) throw ArgumentError.value(uid, 'uid');
    final command = switch (type) {
      'MARK_READ' => 'UID STORE $uid +FLAGS.SILENT (\\Seen)',
      'MARK_UNREAD' => 'UID STORE $uid -FLAGS.SILENT (\\Seen)',
      'STAR' => 'UID STORE $uid +FLAGS.SILENT (\\Flagged)',
      'UNSTAR' => 'UID STORE $uid -FLAGS.SILENT (\\Flagged)',
      'DELETE' => 'UID STORE $uid +X-GM-LABELS.SILENT (\\Trash)',
      'ARCHIVE' => 'UID STORE $uid -X-GM-LABELS.SILENT (\\Inbox)',
      'ADD_LABEL' =>
        'UID STORE $uid +X-GM-LABELS.SILENT (${_quote(_requiredLabel(label))})',
      'REMOVE_LABEL' =>
        'UID STORE $uid -X-GM-LABELS.SILENT (${_quote(_requiredLabel(label))})',
      _ => throw ArgumentError.value(type, 'type', 'Unsupported mutation'),
    };
    await _execute(command);
  }

  Future<void> append(String mailbox, Uint8List rawMessage,
      {String flag = r'\Seen'}) async {
    if (rawMessage.isEmpty || rawMessage.length > maxImapAppendBytes) {
      throw ArgumentError.value(rawMessage.length, 'rawMessage.length');
    }
    if (flag != r'\Seen' && flag != r'\Draft') {
      throw ArgumentError.value(flag, 'flag');
    }
    final tag = _nextTag();
    await _wire.writeCommand(
      '$tag APPEND ${_quote(mailbox)} ($flag) {${rawMessage.length}}',
    );
    final response = await _wire.readResponse();
    switch (response) {
      case ImapContinuation():
        break;
      case ImapTagged(:final status):
        throw ImapProtocolException('IMAP APPEND was rejected ($status)');
      case ImapUntagged():
        throw const ImapProtocolException(
          'Unexpected response before IMAP APPEND literal',
        );
    }
    await _wire.writeLiteral(rawMessage);
    await _readCommandCompletion(tag);
  }

  /// Deletes only this GlassMail draft, and only when the server supports the
  /// UIDPLUS UID EXPUNGE command. A plain EXPUNGE could remove unrelated mail.
  Future<void> deleteDraft(String draftId) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(draftId)) {
      throw ArgumentError.value(draftId, 'draftId');
    }
    final messageId = '<$draftId@glassmail.local>';
    final responses = await _execute(
      'UID SEARCH HEADER MESSAGE-ID ${_quote(messageId)}',
    );
    final matching = <int>{};
    for (final response in responses.whereType<ImapUntagged>()) {
      if (response.values.firstOrNull?.atomValue?.toUpperCase() != 'SEARCH') {
        continue;
      }
      for (final value in response.values.skip(1)) {
        final uid = int.tryParse(value.atomValue ?? '');
        if (uid != null && uid > 0) matching.add(uid);
      }
    }
    for (final uid in matching) {
      await deleteDraftUid(uid);
    }
  }

  Future<void> deleteDraftUid(int uid) async {
    if (uid <= 0) throw ArgumentError.value(uid, 'uid');
    final capabilities = await capability();
    if (!capabilities.contains('UIDPLUS')) {
      throw const ImapProtocolException(
        'Server does not support safe draft deletion',
      );
    }
    await _execute('UID STORE $uid +FLAGS.SILENT (\\Deleted)');
    await _execute('UID EXPUNGE $uid');
  }

  /// Permanently removes one UID after verifying that the selected mailbox is
  /// advertised by the server as Trash and that UIDPLUS is available.
  Future<void> permanentlyDeleteTrashUid(
    int uid, {
    required String mailbox,
  }) async {
    if (uid <= 0) throw ArgumentError.value(uid, 'uid');
    if (_selectedMailboxName != mailbox) {
      throw const ImapProtocolException(
        'Permanent delete requires the selected Trash mailbox',
      );
    }
    final trashExists = (await listMailboxes()).any(
      (item) =>
          item.name == mailbox &&
          item.attributes
              .any((attribute) => attribute.toUpperCase() == r'\TRASH'),
    );
    if (!trashExists) {
      throw const ImapProtocolException(
        'Server did not identify this mailbox as Trash',
      );
    }
    if (!(await capability()).contains('UIDPLUS')) {
      throw const ImapProtocolException(
        'Server does not support safe single-message permanent deletion',
      );
    }
    await _execute('UID STORE $uid +FLAGS.SILENT (\\Deleted)');
    await _execute('UID EXPUNGE $uid');
  }

  Future<ImapStorageQuotaRecord?> storageQuota(String mailbox) async {
    final responses = await _execute('GETQUOTAROOT ${_quote(mailbox)}');
    for (final response in responses.whereType<ImapUntagged>()) {
      if (response.values.firstOrNull?.atomValue?.toUpperCase() != 'QUOTA') {
        continue;
      }
      for (final value in response.values.skip(2)) {
        final values = value.listValue;
        for (var index = 0; index + 2 < values.length; index++) {
          if (values[index].atomValue?.toUpperCase() == 'STORAGE') {
            final used = int.tryParse(values[index + 1].atomValue ?? '');
            final limit = int.tryParse(values[index + 2].atomValue ?? '');
            if (used != null && limit != null && used >= 0 && limit > 0) {
              return ImapStorageQuotaRecord(usedKb: used, limitKb: limit);
            }
          }
        }
      }
    }
    return null;
  }

  Future<void> idle({
    required Duration window,
    required Future<void> Function() onMailboxChanged,
  }) async {
    if (window <= Duration.zero || window > const Duration(minutes: 25)) {
      throw ArgumentError.value(window, 'window');
    }
    final tag = _nextTag();
    await _wire.writeCommand('$tag IDLE');
    final continuation = await _wire.readResponse(
      timeout: defaultImapReadTimeout,
    );
    if (continuation is! ImapContinuation) {
      throw const ImapProtocolException('Server rejected IMAP IDLE');
    }

    final done = Completer<void>();
    final timer = Timer(window, () async {
      try {
        await _wire.writeCommand('DONE');
        done.complete();
      } on Object catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    try {
      while (!done.isCompleted) {
        final response = await _wire.readResponse(timeout: window);
        switch (response) {
          case ImapUntagged(:final values):
            if (values.length > 1 &&
                values[1].atomValue?.toUpperCase() == 'EXISTS') {
              await onMailboxChanged();
            }
            if (values.firstOrNull?.atomValue?.toUpperCase() == 'BYE') {
              throw const ImapProtocolException('Server ended IMAP IDLE');
            }
          case ImapTagged(tag: final responseTag, status: final status):
            if (responseTag != tag) {
              throw const ImapProtocolException(
                'Unexpected IMAP IDLE command tag',
              );
            }
            if (status.toUpperCase() != 'OK') {
              throw ImapProtocolException(
                'Server ended IMAP IDLE with $status',
              );
            }
            done.complete();
          case ImapContinuation():
            break;
        }
      }
      await done.future;
    } finally {
      timer.cancel();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _wire.close();
  }

  Future<List<ImapResponse>> _execute(
    String command, {
    bool authenticationCommand = false,
  }) async {
    _ensureOpen();
    if (command.contains('\r') || command.contains('\n')) {
      throw const ImapProtocolException('IMAP command contains a line break');
    }
    final tag = _nextTag();
    await _wire.writeCommand('$tag $command');
    final responses = <ImapResponse>[];
    while (true) {
      final response = await _wire.readResponse();
      switch (response) {
        case ImapContinuation():
          throw const ImapProtocolException('Unexpected IMAP continuation');
        case ImapUntagged(:final values):
          if (values.firstOrNull?.atomValue?.toUpperCase() == 'BYE') {
            throw const ImapProtocolException('IMAP server disconnected');
          }
          responses.add(response);
        case ImapTagged(tag: final responseTag, status: final status):
          if (responseTag != tag) {
            throw const ImapProtocolException('Unexpected IMAP command tag');
          }
          switch (status.toUpperCase()) {
            case 'OK':
              return responses;
            case 'NO' || 'BAD':
              if (authenticationCommand) {
                throw const ImapAuthenticationException();
              }
              throw const ImapProtocolException('IMAP command was rejected');
            default:
              throw const ImapProtocolException(
                'Unknown IMAP completion status',
              );
          }
      }
    }
  }

  Future<void> _readCommandCompletion(String tag) async {
    while (true) {
      switch (await _wire.readResponse()) {
        case ImapContinuation():
          throw const ImapProtocolException(
            'Unexpected IMAP APPEND continuation',
          );
        case ImapUntagged(:final values):
          if (values.firstOrNull?.atomValue?.toUpperCase() == 'BYE') {
            throw const ImapProtocolException('IMAP server disconnected');
          }
          break;
        case ImapTagged(tag: final responseTag, status: final status):
          if (responseTag != tag) {
            throw const ImapProtocolException('Unexpected IMAP command tag');
          }
          if (status.toUpperCase() != 'OK') {
            throw ImapProtocolException('IMAP APPEND was rejected ($status)');
          }
          return;
      }
    }
  }

  String _nextTag() => 'G${(_commandNumber++).toString().padLeft(4, '0')}';

  void _ensureOpen() {
    if (_closed) throw const ImapProtocolException('IMAP session is closed');
  }

  static Uint8List _firstFetchLiteral(
    List<ImapResponse> responses,
    String missingMessage,
  ) {
    for (final response in responses.whereType<ImapUntagged>()) {
      if (response.values.length > 2 &&
          response.values[1].atomValue?.toUpperCase() == 'FETCH') {
        for (final value in response.values[2].listValue) {
          final bytes = value.literalValue;
          if (bytes != null) return bytes;
        }
      }
    }
    throw ImapProtocolException(missingMessage);
  }

  static String _quote(String value) {
    if (value.runes.any((character) => character < 0x20 || character == 0x7f)) {
      throw const ImapProtocolException('IMAP value contains a control byte');
    }
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  static String _requiredLabel(String? value) {
    if (value == null) {
      throw const ImapProtocolException('Missing Gmail label');
    }
    return value;
  }

  Future<Set<int>> _draftUids(String draftId) async {
    final messageId = '<$draftId@glassmail.local>';
    final responses = await _execute(
      'UID SEARCH HEADER MESSAGE-ID ${_quote(messageId)}',
    );
    final uids = <int>{};
    for (final response in responses.whereType<ImapUntagged>()) {
      if (response.values.firstOrNull?.atomValue?.toUpperCase() != 'SEARCH') {
        continue;
      }
      for (final value in response.values.skip(1)) {
        final uid = int.tryParse(value.atomValue ?? '');
        if (uid != null && uid > 0) uids.add(uid);
      }
    }
    return uids;
  }

  static List<String> _parseAddressList(String? value) {
    if (value == null || value.trim().isEmpty) return const [];
    final angleAddresses = RegExp(r'<([^<>]+)>')
        .allMatches(value)
        .map((match) => match.group(1)!.trim())
        .where((address) => address.contains('@'))
        .toList(growable: false);
    if (angleAddresses.isNotEmpty) return angleAddresses;
    return value
        .split(RegExp(r'[,;]'))
        .map((address) => address.trim())
        .where((address) => address.contains('@'))
        .toList(growable: false);
  }

  static List<String> _parseReferences(String? value) => value == null
      ? const []
      : RegExp(r'<[^<>]+>')
          .allMatches(value)
          .map((match) => match.group(0)!)
          .toList(growable: false);

  static int? _parseImapDate(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d{1,2})-([A-Za-z]{3})-(\d{4}) (\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2})$',
    ).firstMatch(value.trim().replaceAll('"', ''));
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
    final date = DateTime.utc(
      int.parse(match[3]!),
      month,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    );
    final offsetMinutes = int.parse(match[8]!) * 60 + int.parse(match[9]!);
    return date
        .subtract(
            Duration(minutes: match[7] == '+' ? offsetMinutes : -offsetMinutes))
        .millisecondsSinceEpoch;
  }

  static final _validUidRange = RegExp(
    r'^(?:\d+|\*)(?::(?:\d+|\*))?(?:,(?:\d+|\*)(?::(?:\d+|\*))?)*$',
  );
  static final _validPartId = RegExp(r'^[0-9.]+$');
}

final class ImapMailboxRecord {
  ImapMailboxRecord({
    required Set<String> attributes,
    required this.delimiter,
    required this.name,
  }) : attributes = Set.unmodifiable(attributes);

  final Set<String> attributes;
  final String? delimiter;
  final String name;
}

final class ImapSelectedMailboxRecord {
  const ImapSelectedMailboxRecord({
    required this.uidValidity,
    required this.uidNext,
    required this.messageCount,
  });

  final int uidValidity;
  final int uidNext;
  final int messageCount;
}

final class ImapStorageQuotaRecord {
  const ImapStorageQuotaRecord({required this.usedKb, required this.limitKb});

  final int usedKb;
  final int limitKb;
}

final class _SecureSocketImapWire implements ImapWireConnection {
  _SecureSocketImapWire._(this._socket, this._reader, this._readTimeout);

  final SecureSocket _socket;
  final ImapResponseReader _reader;
  final Duration _readTimeout;
  bool _closed = false;

  static Future<_SecureSocketImapWire> connect({
    required String host,
    required int port,
    required Duration connectTimeout,
    required Duration readTimeout,
  }) async {
    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: connectTimeout,
      );
      return _SecureSocketImapWire._(
        socket,
        ImapResponseReader(socket),
        readTimeout,
      );
    } on HandshakeException catch (error) {
      throw ImapTransportException('IMAP TLS handshake failed', error);
    } on SocketException catch (error) {
      throw ImapTransportException('IMAP connection failed', error);
    } on TimeoutException catch (error) {
      throw ImapTransportException('IMAP connection timed out', error);
    }
  }

  @override
  Future<ImapResponse> readResponse({Duration? timeout}) async {
    try {
      return await _reader.readResponse().timeout(timeout ?? _readTimeout);
    } on TimeoutException catch (error) {
      await close();
      throw ImapTransportException('IMAP response timed out', error);
    } on SocketException catch (error) {
      await close();
      throw ImapTransportException('IMAP read failed', error);
    } on HandshakeException catch (error) {
      await close();
      throw ImapTransportException('IMAP TLS failed', error);
    }
  }

  @override
  Future<void> writeCommand(String command) async {
    if (_closed) throw const ImapTransportException('IMAP socket is closed');
    _socket.add(utf8.encode('$command\r\n'));
    try {
      await _socket.flush();
    } on SocketException catch (error) {
      await close();
      throw ImapTransportException('IMAP write failed', error);
    }
  }

  @override
  Future<void> writeLiteral(Uint8List bytes) async {
    if (_closed) throw const ImapTransportException('IMAP socket is closed');
    _socket
      ..add(bytes)
      ..add(const [0x0d, 0x0a]);
    try {
      await _socket.flush();
    } on SocketException catch (error) {
      await close();
      throw ImapTransportException('IMAP literal write failed', error);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _reader.cancel();
    await _socket.close();
  }
}
