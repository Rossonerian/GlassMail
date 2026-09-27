import 'dart:convert';

import 'mail_repository.dart';
import 'mail_value.dart';

final class OutgoingMail with MailValueEquality {
  OutgoingMail({
    required this.operationId,
    required this.accountId,
    required this.from,
    required List<String> to,
    List<String> cc = const [],
    List<String> bcc = const [],
    required this.subject,
    required this.body,
    this.inReplyTo,
    List<String> references = const [],
    List<OutgoingAttachment> attachments = const [],
  }) : to = List.unmodifiable(to),
       cc = List.unmodifiable(cc),
       bcc = List.unmodifiable(bcc),
       references = List.unmodifiable(references),
       attachments = List.unmodifiable(attachments);

  final String operationId;
  final String accountId;
  final String from;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String body;
  final String? inReplyTo;
  final List<String> references;
  final List<OutgoingAttachment> attachments;

  @override
  List<Object?> get equalityProps => [
    operationId,
    accountId,
    from,
    to,
    cc,
    bcc,
    subject,
    body,
    inReplyTo,
    references,
    attachments,
  ];
}

final class OutgoingAttachment with MailValueEquality {
  const OutgoingAttachment({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.openStream,
    this.uri,
  });
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final Stream<List<int>> Function() openStream;

  /// Stable local URI, when available, so a queued send can survive restart.
  final String? uri;

  @override
  List<Object?> get equalityProps => [
    fileName,
    mimeType,
    sizeBytes,
    openStream,
    uri,
  ];
}

sealed class SendMailResult {
  const SendMailResult();
}

final class MailSent extends SendMailResult with MailValueEquality {
  const MailSent();

  @override
  List<Object?> get equalityProps => const [];
}

final class MailSendFailed extends SendMailResult with MailValueEquality {
  const MailSendFailed(this.error);
  final SendMailError error;

  @override
  List<Object?> get equalityProps => [error];
}

enum SendMailError {
  authentication,
  network,
  protocol,
  invalidMessage,
  uncertain,
}

abstract interface class MailSender {
  Future<SendMailResult> send(MailAccount account, OutgoingMail mail);
}

abstract interface class DraftRepository {
  Stream<List<MailDraft>> observeDrafts(String accountId);
  Stream<MailDraft?> observeDraft(String draftId);
  Future<void> saveDraft(MailDraft draft);
  Future<void> deleteDraft(String draftId);
  Future<bool> cancelQueuedSend(String draftId) async => false;
}

final class MailDraft with MailValueEquality {
  MailDraft({
    required this.draftId,
    required this.accountId,
    List<String> to = const [],
    List<String> cc = const [],
    List<String> bcc = const [],
    this.subject = '',
    this.body = '',
    this.inReplyTo,
    List<String> references = const [],
    this.status = DraftStatus.draft,
    this.updatedAtEpochMillis = 0,
    List<DraftAttachment> attachments = const [],
  }) : to = List.unmodifiable(to),
       cc = List.unmodifiable(cc),
       bcc = List.unmodifiable(bcc),
       references = List.unmodifiable(references),
       attachments = List.unmodifiable(attachments);

  final String draftId;
  final String accountId;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String body;
  final String? inReplyTo;
  final List<String> references;
  final DraftStatus status;
  final int updatedAtEpochMillis;
  final List<DraftAttachment> attachments;

  @override
  List<Object?> get equalityProps => [
    draftId,
    accountId,
    to,
    cc,
    bcc,
    subject,
    body,
    inReplyTo,
    references,
    status,
    updatedAtEpochMillis,
    attachments,
  ];
}

final class DraftAttachment with MailValueEquality {
  const DraftAttachment({
    required this.uri,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });
  final String uri;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  @override
  List<Object?> get equalityProps => [uri, fileName, mimeType, sizeBytes];
}

enum DraftStatus {
  draft,
  queued,
  sending,
  sent,
  failed,
  uncertain;

  String get storageValue => name.toUpperCase();

  static DraftStatus fromStorageValue(String value) => switch (value) {
    'DRAFT' => DraftStatus.draft,
    'QUEUED' => DraftStatus.queued,
    'SENDING' => DraftStatus.sending,
    'SENT' => DraftStatus.sent,
    'FAILED' => DraftStatus.failed,
    'UNCERTAIN' => DraftStatus.uncertain,
    _ => throw FormatException('Unknown draft status: $value'),
  };
}

String sanitizeAttachmentName(String raw) {
  final name = raw.split(RegExp(r'[/\\]')).last;
  final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
  final bounded = sanitized.length > 120
      ? sanitized.substring(0, 120)
      : sanitized;
  return bounded.trim().isEmpty ? 'attachment' : bounded;
}

int estimatedOutgoingMessageBytes(OutgoingMail mail) =>
    utf8.encode(mail.body).length +
    (mail.attachments.fold<int>(
          0,
          (sum, item) => sum + (item.sizeBytes < 0 ? 0 : item.sizeBytes),
        ) *
        4 ~/
        3) +
    mail.attachments.length * 1024 +
    16384;

List<String> normalizeAddresses(String raw) => raw
    .split(RegExp(r'[,;\n]'))
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .fold(<String>[], (items, value) {
      if (!items.any((item) => item.toLowerCase() == value.toLowerCase())) {
        items.add(value);
      }
      return items;
    });

bool validateAddresses(List<String> addresses) =>
    addresses.isNotEmpty &&
    addresses.every((address) {
      final at = address.indexOf('@');
      final domain = at < 0 ? '' : address.substring(at + 1);
      return address.length <= 254 &&
          at > 0 &&
          at == address.lastIndexOf('@') &&
          domain.contains('.') &&
          !address.contains(RegExp(r'\s'));
    });

String replySubject(String subject) =>
    subject.trim().toLowerCase().startsWith('re:') ? subject : 'Re: $subject';

List<String> replyRecipients(MailMessage message, String ownAddress) =>
    _uniqueRecipients([message.sender], ownAddress);

List<String> replyAllRecipients(
  ReceivedMailHeaders message,
  String ownAddress,
) => _uniqueRecipients([
  ...message.replyTo,
  ...message.to,
  ...message.cc,
], ownAddress);

final class ReceivedMailHeaders with MailValueEquality {
  ReceivedMailHeaders({
    List<String> replyTo = const [],
    List<String> to = const [],
    List<String> cc = const [],
    this.messageId,
    List<String> references = const [],
  }) : replyTo = List.unmodifiable(replyTo),
       to = List.unmodifiable(to),
       cc = List.unmodifiable(cc),
       references = List.unmodifiable(references);

  final List<String> replyTo;
  final List<String> to;
  final List<String> cc;
  final String? messageId;
  final List<String> references;

  @override
  List<Object?> get equalityProps => [replyTo, to, cc, messageId, references];
}

String forwardSubject(String subject) =>
    subject.trim().toLowerCase().startsWith('fwd:') ? subject : 'Fwd: $subject';

List<String> referencesForReply(String? messageId, List<String> references) {
  final result = <String>[];
  for (final reference in [...references, if (messageId != null) messageId]) {
    if (!result.contains(reference)) result.add(reference);
  }
  return result;
}

List<String> _uniqueRecipients(List<String> candidates, String ownAddress) {
  final result = <String>[];
  for (final address in candidates) {
    if (address.trim().isEmpty ||
        address.toLowerCase() == ownAddress.toLowerCase()) {
      continue;
    }
    if (!result.any((item) => item.toLowerCase() == address.toLowerCase())) {
      result.add(address);
    }
  }
  return result;
}
