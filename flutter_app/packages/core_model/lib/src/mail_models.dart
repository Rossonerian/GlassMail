/// Immutable values exchanged with the IMAP/SMTP and synchronization layers.
///
/// These values do not define database encodings. Persisted values are ported
/// separately from the Room v10 schema and DAO source.
final class ImapMailbox {
  ImapMailbox({required this.name, required Set<String> attributes})
      : attributes = Set.unmodifiable(attributes);

  final String name;
  final Set<String> attributes;

  @override
  bool operator ==(Object other) =>
      other is ImapMailbox &&
      name == other.name &&
      _setEquals(attributes, other.attributes);

  @override
  int get hashCode => Object.hash(name, Object.hashAllUnordered(attributes));
}

final class ImapSelectedMailbox {
  const ImapSelectedMailbox({
    required this.uidValidity,
    required this.uidNext,
    required this.messageCount,
  });

  final int uidValidity;
  final int uidNext;
  final int messageCount;

  @override
  bool operator ==(Object other) =>
      other is ImapSelectedMailbox &&
      uidValidity == other.uidValidity &&
      uidNext == other.uidNext &&
      messageCount == other.messageCount;

  @override
  int get hashCode => Object.hash(uidValidity, uidNext, messageCount);
}

final class ImapStorageQuota {
  const ImapStorageQuota({required this.usedKb, required this.limitKb});

  final int usedKb;
  final int limitKb;

  @override
  bool operator ==(Object other) =>
      other is ImapStorageQuota &&
      usedKb == other.usedKb &&
      limitKb == other.limitKb;

  @override
  int get hashCode => Object.hash(usedKb, limitKb);
}

final class ImapRemoteDraft {
  ImapRemoteDraft({
    required this.uid,
    this.uidValidity,
    required this.draftId,
    required List<String> to,
    required List<String> cc,
    required List<String> bcc,
    required this.subject,
    required this.body,
    required this.inReplyTo,
    required List<String> references,
    required this.updatedAtEpochMillis,
  })  : to = List.unmodifiable(to),
        cc = List.unmodifiable(cc),
        bcc = List.unmodifiable(bcc),
        references = List.unmodifiable(references);

  final int uid;
  final int? uidValidity;
  final String? draftId;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String body;
  final String? inReplyTo;
  final List<String> references;
  final int updatedAtEpochMillis;

  @override
  bool operator ==(Object other) =>
      other is ImapRemoteDraft &&
      uid == other.uid &&
      uidValidity == other.uidValidity &&
      draftId == other.draftId &&
      _listEquals(to, other.to) &&
      _listEquals(cc, other.cc) &&
      _listEquals(bcc, other.bcc) &&
      subject == other.subject &&
      body == other.body &&
      inReplyTo == other.inReplyTo &&
      _listEquals(references, other.references) &&
      updatedAtEpochMillis == other.updatedAtEpochMillis;

  @override
  int get hashCode => Object.hash(
        uid,
        uidValidity,
        draftId,
        Object.hashAll(to),
        Object.hashAll(cc),
        Object.hashAll(bcc),
        subject,
        body,
        inReplyTo,
        Object.hashAll(references),
        updatedAtEpochMillis,
      );
}

final class ImapMessageMetadata {
  ImapMessageMetadata({
    required this.uid,
    required Set<String> flags,
    required this.gmailMessageId,
    required this.gmailThreadId,
    required Set<String> labels,
    required this.subject,
    required this.sender,
    required this.sentAtEpochMillis,
    required this.sizeBytes,
    this.hasListUnsubscribe = false,
    this.precedence,
    this.listId,
    this.listUnsubscribe,
    this.listUnsubscribePost,
  })  : flags = Set.unmodifiable(flags),
        labels = Set.unmodifiable(labels);

  final int uid;
  final Set<String> flags;
  final String? gmailMessageId;
  final String? gmailThreadId;
  final Set<String> labels;
  final String? subject;
  final String? sender;
  final int? sentAtEpochMillis;
  final int? sizeBytes;
  final bool hasListUnsubscribe;
  final String? precedence;
  final String? listId;
  final String? listUnsubscribe;
  final String? listUnsubscribePost;

  @override
  bool operator ==(Object other) =>
      other is ImapMessageMetadata &&
      uid == other.uid &&
      _setEquals(flags, other.flags) &&
      gmailMessageId == other.gmailMessageId &&
      gmailThreadId == other.gmailThreadId &&
      _setEquals(labels, other.labels) &&
      subject == other.subject &&
      sender == other.sender &&
      sentAtEpochMillis == other.sentAtEpochMillis &&
      sizeBytes == other.sizeBytes &&
      hasListUnsubscribe == other.hasListUnsubscribe &&
      precedence == other.precedence &&
      listId == other.listId &&
      listUnsubscribe == other.listUnsubscribe &&
      listUnsubscribePost == other.listUnsubscribePost;

  @override
  int get hashCode => Object.hash(
        uid,
        Object.hashAllUnordered(flags),
        gmailMessageId,
        gmailThreadId,
        Object.hashAllUnordered(labels),
        subject,
        sender,
        sentAtEpochMillis,
        sizeBytes,
        hasListUnsubscribe,
        precedence,
        listId,
        listUnsubscribe,
        listUnsubscribePost,
      );
}

final class GmailInboxSnapshot {
  GmailInboxSnapshot({
    required Set<String> capabilities,
    required List<ImapMailbox> mailboxes,
    required this.inbox,
    required List<ImapMessageMetadata> messages,
    this.requestedThroughUid = 0,
  })  : capabilities = Set.unmodifiable(capabilities),
        mailboxes = List.unmodifiable(mailboxes),
        messages = List.unmodifiable(messages);

  final Set<String> capabilities;
  final List<ImapMailbox> mailboxes;
  final ImapSelectedMailbox inbox;
  final List<ImapMessageMetadata> messages;

  /// Last UID requested from the server, including an empty range with UID holes.
  final int requestedThroughUid;

  bool get supportsGmailExtensions => capabilities.contains('X-GM-EXT-1');

  bool get hasMoreUids => requestedThroughUid < inbox.uidNext - 1;

  @override
  bool operator ==(Object other) =>
      other is GmailInboxSnapshot &&
      _setEquals(capabilities, other.capabilities) &&
      _listEquals(mailboxes, other.mailboxes) &&
      inbox == other.inbox &&
      _listEquals(messages, other.messages) &&
      requestedThroughUid == other.requestedThroughUid;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(capabilities),
        Object.hashAll(mailboxes),
        inbox,
        Object.hashAll(messages),
        requestedThroughUid,
      );
}

sealed class MailSyncResult {
  const MailSyncResult();
}

final class MailSyncSuccess extends MailSyncResult {
  const MailSyncSuccess({
    required this.messageCount,
    required this.gmailExtensionsEnabled,
    this.hasMore = false,
  });

  final int messageCount;
  final bool gmailExtensionsEnabled;

  /// True when the committed page left more historical/incremental UIDs.
  final bool hasMore;

  @override
  bool operator ==(Object other) =>
      other is MailSyncSuccess &&
      messageCount == other.messageCount &&
      gmailExtensionsEnabled == other.gmailExtensionsEnabled &&
      hasMore == other.hasMore;

  @override
  int get hashCode =>
      Object.hash(messageCount, gmailExtensionsEnabled, hasMore);
}

final class MailSyncFailure extends MailSyncResult {
  const MailSyncFailure(this.error);

  final MailSyncError error;

  @override
  bool operator ==(Object other) =>
      other is MailSyncFailure && error == other.error;

  @override
  int get hashCode => error.hashCode;
}

enum MailSyncError {
  authentication,
  network,
  protocol,
  missingCredential,
  cancelled,
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
