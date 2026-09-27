import 'dart:async';

import 'package:glassmail_core_model/glassmail_core_model.dart';

import 'mail_value.dart';

abstract interface class MailRepository {
  Stream<List<MailAccount>> observeAccounts();
  Stream<AccountSyncSummary?> observeAccount(String accountId);
  Stream<List<MailListItem>> observeInbox(String accountId);
  Stream<List<MailListItem>> observeSent(String accountId) =>
      Stream.value(const []);
  Stream<List<MailListItem>> observeInboxCategory(
    String accountId,
    String category,
  ) => observeInbox(accountId);
  Stream<Map<String, int>> observeCategoryUnreadCounts(String accountId) =>
      Stream.value(const {});
  Stream<List<MailListItem>> search(String accountId, String query);
  Stream<MailCacheSettings> observeCacheSettings(String accountId) =>
      Stream.value(const MailCacheSettings());
  Stream<StorageQuota?> observeStorageQuota(String accountId) =>
      Stream.value(null);
  Stream<MailMessage?> observeMessage(String messageId);
  Stream<List<MailMessage>> observeThread(String messageId);
  Stream<List<MailMessage>> observeThreadInMailbox(
    String messageId,
    String mailboxId,
  ) => observeThread(messageId);

  Stream<List<MailListItem>> observeUnifiedInbox(
    List<String> accountIds,
    String category,
  ) => _combineLists(
    accountIds.map((id) => observeInboxCategory(id, category)).toList(),
  );

  Stream<Map<String, int>> observeUnifiedCategoryUnreadCounts(
    List<String> accountIds,
  ) => _combineMaps(accountIds.map(observeCategoryUnreadCounts).toList());

  Stream<List<MailListItem>> searchUnified(
    List<String> accountIds,
    String query,
  ) => _combineLists(accountIds.map((id) => search(id, query)).toList());

  Future<void> saveCacheSettings(
    String accountId,
    MailCacheSettings settings,
  ) async {}
  Future<void> enforceCacheLimits(String accountId) async {}
  Future<MailOperationResult<StorageQuota>> refreshStorageQuota(
    String accountId,
  ) async =>
      MailOperationFailure(UnsupportedError('Storage quota is unavailable'));
  Future<void> createAccount(
    String accountId,
    String email, {
    required List<int> credentialUtf8,
    String syncState = 'READY',
  });
  Future<void> updateCredential(
    String accountId,
    List<int> credentialUtf8,
  ) async {
    credentialUtf8.fillRange(0, credentialUtf8.length, 0);
    throw UnsupportedError('Account credential updates are unavailable');
  }

  Future<void> removeAccount(String accountId);
  Future<MailSyncResult> synchronize(String accountId);
  Future<void> applyMutation(MailMutation mutation);
  Future<bool> undoPendingArchive(String messageId) async => false;
  Future<void> seedDebugMailbox(int count);
  Future<void> clearDebugMailbox();
  Future<MailOperationResult<MailMessage>> loadMessageBody(String messageId);
}

abstract interface class AttachmentRepository {
  Future<MailOperationResult<DownloadedAttachment>> downloadAttachment(
    String accountId,
    String attachmentId,
  );
}

/// Portable cache backup contract. Implementations must exclude credentials
/// and mutations that could be replayed against a remote server on restore.
abstract interface class PortableMailBackupRepository {
  Future<Map<String, Object?>> exportBackupData();
  Future<void> restoreBackupData(Map<String, dynamic> backup);
}

/// Provider-safe permanent deletion. Implementations must scope the delete to
/// the selected Trash UID and must never issue a mailbox-wide EXPUNGE.
abstract interface class PermanentMailDeletionRepository {
  Future<void> purgeFromTrash({
    required String accountId,
    required String messageId,
    required String mailboxId,
  });
}

/// Cached, provider Trash access required before a permanent-delete action.
abstract interface class TrashMailboxRepository {
  Stream<List<MailListItem>> observeTrash(String accountId);
  Future<String?> trashMailboxId(String accountId);
}

sealed class MailOperationResult<T> {
  const MailOperationResult();
}

final class MailOperationSuccess<T> extends MailOperationResult<T>
    with MailValueEquality {
  const MailOperationSuccess(this.value);

  final T value;

  @override
  List<Object?> get equalityProps => [value];
}

final class MailOperationFailure<T> extends MailOperationResult<T>
    with MailValueEquality {
  const MailOperationFailure(this.error, {this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  List<Object?> get equalityProps => [error, stackTrace];
}

final class MailAccount with MailValueEquality {
  const MailAccount({
    required this.accountId,
    required this.email,
    required this.syncState,
  });

  final String accountId;
  final String email;
  final String syncState;

  @override
  List<Object?> get equalityProps => [accountId, email, syncState];
}

abstract final class MailCategory {
  static const primary = 'PRIMARY';
  static const social = 'SOCIAL';
  static const promotions = 'PROMOTIONS';
  static const updates = 'UPDATES';
  static const forums = 'FORUMS';
  static const all = [primary, social, promotions, updates, forums];
}

final class MailListItem with MailValueEquality {
  MailListItem({
    required this.messageId,
    required this.threadId,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.sentAtEpochMillis,
    required this.unread,
    required this.starred,
    required List<String> labels,
    required this.hasAttachment,
    this.category = MailCategory.primary,
    this.messageCount = 1,
    this.participantCount = 1,
    List<String>? threadMessageIds,
  }) : labels = List.unmodifiable(labels),
       threadMessageIds = List.unmodifiable(threadMessageIds ?? [messageId]);

  final String messageId;
  final String? threadId;
  final String sender;
  final String subject;
  final String preview;
  final int? sentAtEpochMillis;
  final bool unread;
  final bool starred;
  final List<String> labels;
  final bool hasAttachment;
  final String category;
  final int messageCount;
  final int participantCount;
  final List<String> threadMessageIds;

  @override
  List<Object?> get equalityProps => [
    messageId,
    threadId,
    sender,
    subject,
    preview,
    sentAtEpochMillis,
    unread,
    starred,
    labels,
    hasAttachment,
    category,
    messageCount,
    participantCount,
    threadMessageIds,
  ];
}

final class MailAttachment with MailValueEquality {
  const MailAttachment({
    required this.attachmentId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.downloadState,
  });

  final String attachmentId;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final String downloadState;

  @override
  List<Object?> get equalityProps => [
    attachmentId,
    fileName,
    mimeType,
    sizeBytes,
    downloadState,
  ];
}

final class MailMessage with MailValueEquality {
  MailMessage({
    required this.messageId,
    required this.threadId,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.body,
    required this.html,
    required this.sentAtEpochMillis,
    required this.unread,
    required this.starred,
    required List<String> labels,
    List<MailAttachment> attachments = const [],
    this.listUnsubscribe,
    this.listUnsubscribePost,
  }) : labels = List.unmodifiable(labels),
       attachments = List.unmodifiable(attachments);

  final String messageId;
  final String? threadId;
  final String sender;
  final String subject;
  final String preview;
  final String? body;
  final bool html;
  final int? sentAtEpochMillis;
  final bool unread;
  final bool starred;
  final List<String> labels;
  final List<MailAttachment> attachments;
  final String? listUnsubscribe;
  final String? listUnsubscribePost;

  @override
  List<Object?> get equalityProps => [
    messageId,
    threadId,
    sender,
    subject,
    preview,
    body,
    html,
    sentAtEpochMillis,
    unread,
    starred,
    labels,
    attachments,
    listUnsubscribe,
    listUnsubscribePost,
  ];
}

sealed class MailMutation with MailValueEquality {
  const MailMutation({
    required this.accountId,
    required this.messageId,
    required this.mailboxId,
  });

  final String accountId;
  final String messageId;
  final String? mailboxId;

  @override
  List<Object?> get equalityProps => [accountId, messageId, mailboxId];
}

final class MarkReadMutation extends MailMutation {
  const MarkReadMutation({
    required super.accountId,
    required super.messageId,
    super.mailboxId,
    required this.read,
  });
  final bool read;

  @override
  List<Object?> get equalityProps => [...super.equalityProps, read];
}

final class StarMutation extends MailMutation {
  const StarMutation({
    required super.accountId,
    required super.messageId,
    super.mailboxId,
    required this.starred,
  });
  final bool starred;

  @override
  List<Object?> get equalityProps => [...super.equalityProps, starred];
}

final class ArchiveMutation extends MailMutation {
  const ArchiveMutation({
    required super.accountId,
    required super.messageId,
    required String mailboxId,
  }) : super(mailboxId: mailboxId);
}

final class DeleteMutation extends MailMutation {
  const DeleteMutation({
    required super.accountId,
    required super.messageId,
    super.mailboxId,
  });
}

final class LabelMutation extends MailMutation {
  const LabelMutation({
    required super.accountId,
    required super.messageId,
    super.mailboxId,
    required this.label,
    required this.add,
  });
  final String label;
  final bool add;

  @override
  List<Object?> get equalityProps => [...super.equalityProps, label, add];
}

final class AccountSyncSummary with MailValueEquality {
  const AccountSyncSummary({
    required this.accountId,
    required this.email,
    required this.syncState,
    required this.messageCount,
    required this.gmailExtensionsEnabled,
    required this.lastSyncedAtEpochMillis,
  });

  final String accountId;
  final String email;
  final String syncState;
  final int messageCount;
  final bool gmailExtensionsEnabled;
  final int? lastSyncedAtEpochMillis;

  @override
  List<Object?> get equalityProps => [
    accountId,
    email,
    syncState,
    messageCount,
    gmailExtensionsEnabled,
    lastSyncedAtEpochMillis,
  ];
}

final class MailCacheSettings with MailValueEquality {
  const MailCacheSettings({
    this.offlineMessageCount = 200,
    this.attachmentCacheLimitMb = 500,
    this.autoEvictReadOlderThanDays = 60,
    this.prefetchUnreadBodies = true,
  });

  final int offlineMessageCount;
  final int attachmentCacheLimitMb;
  final int autoEvictReadOlderThanDays;
  final bool prefetchUnreadBodies;

  @override
  List<Object?> get equalityProps => [
    offlineMessageCount,
    attachmentCacheLimitMb,
    autoEvictReadOlderThanDays,
    prefetchUnreadBodies,
  ];
}

final class StorageQuota with MailValueEquality {
  const StorageQuota({
    required this.usedKb,
    required this.limitKb,
    required this.checkedAtEpochMillis,
  });
  final int usedKb;
  final int limitKb;
  final int checkedAtEpochMillis;

  @override
  List<Object?> get equalityProps => [usedKb, limitKb, checkedAtEpochMillis];
}

final class DownloadedAttachment with MailValueEquality {
  const DownloadedAttachment({
    required this.filePath,
    required this.fileName,
    required this.mimeType,
  });
  final String filePath;
  final String fileName;
  final String mimeType;

  @override
  List<Object?> get equalityProps => [filePath, fileName, mimeType];
}

final class SyncAccountUseCase {
  const SyncAccountUseCase(this.repository);
  final MailRepository repository;
  Future<MailSyncResult> call(String accountId) =>
      repository.synchronize(accountId);
}

Stream<List<MailListItem>> _combineLists(
  List<Stream<List<MailListItem>>> streams,
) {
  if (streams.isEmpty) return Stream.value(const []);
  late StreamController<List<MailListItem>> controller;
  final subscriptions = <StreamSubscription<List<MailListItem>>>[];
  final latest = List<List<MailListItem>?>.filled(streams.length, null);
  var done = 0;

  void emitIfReady() {
    if (latest.every((items) => items != null)) {
      final combined = <({MailListItem item, int sourceOrder})>[];
      var sourceOrder = 0;
      for (final items in latest) {
        for (final item in items!) {
          combined.add((item: item, sourceOrder: sourceOrder++));
        }
      }
      combined.sort((a, b) {
        final aTime = a.item.sentAtEpochMillis;
        final bTime = b.item.sentAtEpochMillis;
        final timestampOrder = aTime == null
            ? (bTime == null ? 0 : 1)
            : (bTime == null ? -1 : bTime.compareTo(aTime));
        return timestampOrder != 0
            ? timestampOrder
            : a.sourceOrder.compareTo(b.sourceOrder);
      });
      controller.add(List.unmodifiable(combined.map((entry) => entry.item)));
    }
  }

  controller = StreamController<List<MailListItem>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        final index = i;
        subscriptions.add(
          streams[index].listen(
            (value) {
              latest[index] = value;
              emitIfReady();
            },
            onError: controller.addError,
            onDone: () {
              done++;
              if (done == streams.length) controller.close();
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}

Stream<Map<String, int>> _combineMaps(List<Stream<Map<String, int>>> streams) {
  if (streams.isEmpty) return Stream.value(const {});
  late StreamController<Map<String, int>> controller;
  final subscriptions = <StreamSubscription<Map<String, int>>>[];
  final latest = List<Map<String, int>?>.filled(streams.length, null);
  var done = 0;

  void emitIfReady() {
    if (latest.every((map) => map != null)) {
      final result = <String, int>{};
      for (final map in latest) {
        for (final entry in map!.entries) {
          result.update(
            entry.key,
            (value) => value + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      }
      controller.add(Map.unmodifiable(result));
    }
  }

  controller = StreamController<Map<String, int>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        final index = i;
        subscriptions.add(
          streams[index].listen(
            (value) {
              latest[index] = value;
              emitIfReady();
            },
            onError: controller.addError,
            onDone: () {
              done++;
              if (done == streams.length) controller.close();
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
