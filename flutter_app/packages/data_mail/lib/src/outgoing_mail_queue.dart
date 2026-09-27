import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

abstract interface class RawMailTransport {
  Future<void> send({
    required String email,
    required Uint8List credentialUtf8,
    required List<String> recipients,
    required Uint8List rawMessage,
  });
}

typedef SmtpClientConnector = Future<SmtpClient> Function();

final class SecureSmtpMailTransport implements RawMailTransport {
  SecureSmtpMailTransport({SmtpClientConnector? connect})
    : _connect = connect ?? SmtpClient.connect;

  final SmtpClientConnector _connect;

  @override
  Future<void> send({
    required String email,
    required Uint8List credentialUtf8,
    required List<String> recipients,
    required Uint8List rawMessage,
  }) async {
    final client = await _connect();
    try {
      await client.sendRaw(
        email: email,
        credentialUtf8: credentialUtf8,
        recipients: recipients,
        rawMessage: rawMessage,
      );
    } finally {
      await client.close();
    }
  }
}

abstract interface class SentCopyAppender {
  Future<void> append({
    required String email,
    required Uint8List credentialUtf8,
    required Uint8List rawMessage,
  });
}

typedef SentImapConnector = Future<ImapClient> Function();

final class ImapSentCopyAppender implements SentCopyAppender {
  ImapSentCopyAppender({SentImapConnector? connect})
    : _connect = connect ?? ImapClient.connect;

  final SentImapConnector _connect;

  @override
  Future<void> append({
    required String email,
    required Uint8List credentialUtf8,
    required Uint8List rawMessage,
  }) async {
    final client = await _connect();
    try {
      await client.login(email, credentialUtf8);
      final mailboxes = await client.listMailboxes();
      final sent =
          mailboxes
              .where(
                (mailbox) => mailbox.attributes.any(
                  (attribute) => attribute.toLowerCase() == r'\sent',
                ),
              )
              .map((mailbox) => mailbox.name)
              .firstOrNull ??
          const ['[Gmail]/Sent Mail', 'Sent', 'Sent Items']
              .where(
                (name) => mailboxes.any(
                  (mailbox) => mailbox.name.toLowerCase() == name.toLowerCase(),
                ),
              )
              .firstOrNull;
      if (sent == null) {
        throw const ImapProtocolException(
          'Server did not advertise a Sent mailbox',
        );
      }
      await client.append(sent, rawMessage, flag: r'\Seen');
    } finally {
      await client.close();
    }
  }
}

abstract final class RawMailComposer {
  static Future<Uint8List> compose(
    OutgoingMail mail, {
    int? sentAtEpochMillis,
    bool allowEmptyRecipients = false,
  }) async {
    if (!_validOperationId.hasMatch(mail.operationId) ||
        !validateAddresses([mail.from]) ||
        (!allowEmptyRecipients ||
                mail.to.isNotEmpty ||
                mail.cc.isNotEmpty ||
                mail.bcc.isNotEmpty) &&
            !validateAddresses([...mail.to, ...mail.cc, ...mail.bcc])) {
      throw const FormatException('Invalid sender, recipient, or operation ID');
    }
    _requireHeaderSafe(mail.subject, 'subject');
    _requireHeaderSafe(mail.from, 'from');
    _requireHeaderSafe(mail.inReplyTo ?? '', 'inReplyTo');
    for (final reference in mail.references) {
      _requireHeaderSafe(reference, 'references');
    }
    for (final address in [...mail.to, ...mail.cc, ...mail.bcc]) {
      _requireHeaderSafe(address, 'recipient');
    }

    final attachments = <({OutgoingAttachment attachment, Uint8List bytes})>[];
    final bodyBytes = Uint8List.fromList(utf8.encode(mail.body));
    var estimatedMessageBytes = _foldedBase64Length(bodyBytes.length) + 8192;
    for (final attachment in mail.attachments) {
      if (attachment.sizeBytes < 0) {
        throw const FormatException('Invalid attachment size');
      }
      final bytes = await _readBounded(attachment.openStream());
      estimatedMessageBytes += _foldedBase64Length(bytes.length) + 1024;
      if (estimatedMessageBytes > maxSmtpMessageBytes) {
        throw const FormatException('Message exceeds 24 MiB');
      }
      attachments.add((attachment: attachment, bytes: bytes));
    }

    final timestamp =
        sentAtEpochMillis ?? DateTime.now().millisecondsSinceEpoch;
    final date = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc(),
    );
    final messageId = '<${mail.operationId}@glassmail.local>';
    final headers = <String>[
      'From: ${mail.from}',
      if (mail.to.isNotEmpty) 'To: ${mail.to.join(', ')}',
      if (mail.cc.isNotEmpty) 'Cc: ${mail.cc.join(', ')}',
      'Subject: ${_encodeHeader(mail.subject)}',
      'Date: $date',
      'Message-ID: $messageId',
      if (mail.inReplyTo != null) 'In-Reply-To: ${mail.inReplyTo}',
      if (mail.references.isNotEmpty)
        'References: ${mail.references.join(' ')}',
      'MIME-Version: 1.0',
    ];

    final content = StringBuffer();
    if (attachments.isEmpty) {
      headers.addAll([
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: base64',
      ]);
      content.write(_foldBase64(bodyBytes));
    } else {
      final boundary = 'glassmail_${mail.operationId}';
      headers.add('Content-Type: multipart/mixed; boundary="$boundary"');
      content
        ..write('--$boundary\r\n')
        ..write('Content-Type: text/plain; charset=UTF-8\r\n')
        ..write('Content-Transfer-Encoding: base64\r\n\r\n')
        ..write(_foldBase64(bodyBytes))
        ..write('\r\n');
      for (final item in attachments) {
        final name = sanitizeAttachmentName(item.attachment.fileName);
        final mime = _safeMimeType(item.attachment.mimeType);
        content
          ..write('--$boundary\r\n')
          ..write('Content-Type: $mime; name="$name"\r\n')
          ..write('Content-Disposition: attachment; filename="$name"\r\n')
          ..write('Content-Transfer-Encoding: base64\r\n\r\n')
          ..write(_foldBase64(item.bytes))
          ..write('\r\n');
      }
      content.write('--$boundary--\r\n');
    }

    final output = Uint8List.fromList(
      utf8.encode('${headers.join('\r\n')}\r\n\r\n$content'),
    );
    if (output.length > maxSmtpMessageBytes) {
      throw const FormatException('Message exceeds 24 MiB');
    }
    return output;
  }

  static Future<Uint8List> _readBounded(Stream<List<int>> source) async {
    final builder = BytesBuilder(copy: false);
    var size = 0;
    await for (final chunk in source) {
      size += chunk.length;
      if (size > maxSmtpMessageBytes) {
        throw const FormatException('Attachment exceeds 24 MiB');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static String _foldBase64(List<int> bytes) {
    final encoded = base64.encode(bytes);
    if (encoded.isEmpty) return '';
    final lines = <String>[];
    for (var offset = 0; offset < encoded.length; offset += 76) {
      lines.add(encoded.substring(offset, min(offset + 76, encoded.length)));
    }
    return lines.join('\r\n');
  }

  static int _foldedBase64Length(int byteLength) {
    final encodedLength = ((byteLength + 2) ~/ 3) * 4;
    if (encodedLength == 0) return 0;
    return encodedLength + 2 * ((encodedLength - 1) ~/ 76);
  }

  static String _encodeHeader(String value) {
    if (value.codeUnits.every((unit) => unit >= 0x20 && unit <= 0x7e)) {
      return value;
    }
    return '=?UTF-8?B?${base64.encode(utf8.encode(value))}?=';
  }

  static String _safeMimeType(String value) =>
      RegExp(r'^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$').hasMatch(value)
      ? value
      : 'application/octet-stream';

  static String _formatDate(DateTime value) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String two(int number) => number.toString().padLeft(2, '0');
    return '${weekdays[value.weekday - 1]}, ${two(value.day)} ${months[value.month - 1]} ${value.year} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)} +0000';
  }

  static void _requireHeaderSafe(String value, String name) {
    if (value.contains('\r') ||
        value.contains('\n') ||
        value.contains('\u0000')) {
      throw FormatException('Invalid $name header');
    }
  }

  static final _validOperationId = RegExp(r'^[A-Za-z0-9._-]{1,128}$');
}

/// Stores state before network I/O so a process death after SMTP DATA is never
/// interpreted as permission to send the same operation again.
final class OutgoingMailQueue {
  OutgoingMailQueue({
    required GlassMailDatabase database,
    required CredentialStore credentialStore,
    required RawMailTransport transport,
    SentCopyAppender? sentCopyAppender,
    int Function()? clock,
  }) : _database = database,
       _credentialStore = credentialStore,
       _transport = transport,
       _sentCopyAppender = sentCopyAppender,
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final GlassMailDatabase _database;
  final CredentialStore _credentialStore;
  final RawMailTransport _transport;
  final SentCopyAppender? _sentCopyAppender;
  final int Function() _clock;
  final Map<String, Future<void>> _draftTails = {};

  Future<void> queue(MailDraft draft) =>
      save(_withStatus(draft, DraftStatus.queued));

  Future<void> save(MailDraft draft) async {
    await _database.saveDraft(
      DraftsCompanion.insert(
        draftId: draft.draftId,
        accountId: draft.accountId,
        toAddresses: _encodeList(draft.to),
        ccAddresses: _encodeList(draft.cc),
        bccAddresses: _encodeList(draft.bcc),
        subject: draft.subject,
        body: draft.body,
        inReplyTo: Value(draft.inReplyTo),
        references: _encodeList(draft.references),
        status: draft.status.storageValue,
        updatedAtEpochMillis: draft.updatedAtEpochMillis == 0
            ? _clock()
            : draft.updatedAtEpochMillis,
        attachments: _encodeAttachments(draft.attachments),
      ),
    );
  }

  Future<SendMailResult> send(
    MailAccount account,
    MailDraft draft,
    OutgoingMail mail, {
    bool requireQueued = false,
  }) => _serialized(
    draft.draftId,
    () => _send(account, draft, mail, requireQueued: requireQueued),
  );

  Future<SendMailResult> _send(
    MailAccount account,
    MailDraft requestedDraft,
    OutgoingMail mail, {
    required bool requireQueued,
  }) async {
    if (requestedDraft.accountId != account.accountId ||
        mail.accountId != account.accountId ||
        mail.operationId != requestedDraft.draftId) {
      return const MailSendFailed(SendMailError.invalidMessage);
    }
    final stored = await _database.watchDraft(requestedDraft.draftId).first;
    final draft = stored == null ? requestedDraft : _toMailDraft(stored);
    if (draft.accountId != account.accountId) {
      return const MailSendFailed(SendMailError.invalidMessage);
    }
    if (requireQueued && draft.status != DraftStatus.queued) {
      return const MailSendFailed(SendMailError.invalidMessage);
    }
    if (draft.status == DraftStatus.sending) {
      await save(_withStatus(draft, DraftStatus.uncertain));
      return const MailSendFailed(SendMailError.uncertain);
    }
    if (draft.status == DraftStatus.uncertain) {
      return const MailSendFailed(SendMailError.uncertain);
    }
    if (draft.status == DraftStatus.sent) return const MailSent();

    Uint8List rawMessage;
    try {
      rawMessage = await RawMailComposer.compose(
        mail,
        sentAtEpochMillis: _clock(),
      );
    } on FormatException {
      await save(_withStatus(draft, DraftStatus.failed));
      return const MailSendFailed(SendMailError.invalidMessage);
    }

    final claimed = await _database.claimDraftForSend(
      draftId: draft.draftId,
      expectedStatus: draft.status.storageValue,
      updatedAtEpochMillis: _clock(),
    );
    if (!claimed) {
      final latest = await _database.watchDraft(draft.draftId).first;
      if (latest?.status == DraftStatus.sent.storageValue) {
        return const MailSent();
      }
      return const MailSendFailed(SendMailError.uncertain);
    }
    try {
      final result = await _credentialStore.withCredential<bool>(
        account.accountId,
        (credential) async {
          await _transport.send(
            email: account.email,
            credentialUtf8: credential,
            recipients: [...mail.to, ...mail.cc, ...mail.bcc],
            rawMessage: rawMessage,
          );
          return true;
        },
      );
      if (result != true) {
        await save(_withStatus(draft, DraftStatus.failed));
        return const MailSendFailed(SendMailError.authentication);
      }
    } on SmtpUncertainDeliveryException {
      await save(_withStatus(draft, DraftStatus.uncertain));
      return const MailSendFailed(SendMailError.uncertain);
    } on SmtpAuthenticationException {
      await save(_withStatus(draft, DraftStatus.failed));
      return const MailSendFailed(SendMailError.authentication);
    } on SmtpTransportException {
      await save(_withStatus(draft, DraftStatus.queued));
      return const MailSendFailed(SendMailError.network);
    } on SmtpRejectedException catch (error) {
      final retryable = error.code >= 400 && error.code < 500;
      await save(
        _withStatus(draft, retryable ? DraftStatus.queued : DraftStatus.failed),
      );
      return MailSendFailed(
        retryable ? SendMailError.network : SendMailError.protocol,
      );
    } on SmtpProtocolException {
      await save(_withStatus(draft, DraftStatus.failed));
      return const MailSendFailed(SendMailError.protocol);
    }

    await save(_withStatus(draft, DraftStatus.sent));
    final appender = _sentCopyAppender;
    if (appender != null) {
      try {
        await _credentialStore.withCredential(
          account.accountId,
          (credential) => appender.append(
            email: account.email,
            credentialUtf8: credential,
            rawMessage: rawMessage,
          ),
        );
      } on Object {
        // SMTP acceptance is final; a Sent-copy failure must not resend mail.
      }
    }
    return const MailSent();
  }

  MailDraft _withStatus(MailDraft draft, DraftStatus status) => MailDraft(
    draftId: draft.draftId,
    accountId: draft.accountId,
    to: draft.to,
    cc: draft.cc,
    bcc: draft.bcc,
    subject: draft.subject,
    body: draft.body,
    inReplyTo: draft.inReplyTo,
    references: draft.references,
    status: status,
    updatedAtEpochMillis: _clock(),
    attachments: draft.attachments,
  );

  static MailDraft _toMailDraft(Draft draft) => MailDraft(
    draftId: draft.draftId,
    accountId: draft.accountId,
    to: _decodeList(draft.toAddresses),
    cc: _decodeList(draft.ccAddresses),
    bcc: _decodeList(draft.bccAddresses),
    subject: draft.subject,
    body: draft.body,
    inReplyTo: draft.inReplyTo,
    references: _decodeList(draft.references),
    status: DraftStatus.fromStorageValue(draft.status),
    updatedAtEpochMillis: draft.updatedAtEpochMillis,
    attachments: _decodeAttachments(draft.attachments),
  );

  Future<T> _serialized<T>(String draftId, Future<T> Function() action) async {
    final previous = _draftTails[draftId] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = release.future;
    _draftTails[draftId] = tail;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_draftTails[draftId], tail)) _draftTails.remove(draftId);
    }
  }
}

String _encodeList(List<String> values) => values.join('\u001f');
List<String> _decodeList(String encoded) =>
    encoded.split('\u001f').where((value) => value.isNotEmpty).toList();

String _encodeAttachments(List<DraftAttachment> attachments) => attachments
    .map(
      (attachment) => [
        attachment.uri,
        attachment.fileName,
        attachment.mimeType,
        attachment.sizeBytes.toString(),
      ].join('\u001f'),
    )
    .join('\u001e');

List<DraftAttachment> _decodeAttachments(String encoded) => encoded
    .split('\u001e')
    .map((row) => row.split('\u001f'))
    .where((parts) => parts.length == 4 && int.tryParse(parts[3]) != null)
    .map(
      (parts) => DraftAttachment(
        uri: parts[0],
        fileName: parts[1],
        mimeType: parts[2],
        sizeBytes: int.parse(parts[3]),
      ),
    )
    .toList();
