import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart'
    hide StorageQuota;
import 'package:glassmail_core_imap/glassmail_core_imap.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';
import 'package:path_provider/path_provider.dart';

import 'mailbox_sync.dart';
import 'outgoing_mail_queue.dart';
import 'pending_mutation_queue.dart';
import 'remote_draft_source.dart';

typedef ImapContentConnector = Future<ImapClient> Function();

/// Transport boundary for lazily loaded bodies, attachments and server quota.
abstract interface class MailContentSource {
  Future<ParsedMessageBody> fetchBody({
    required String email,
    required Uint8List credentialUtf8,
    required String mailbox,
    required int uid,
  });

  Future<Uint8List> fetchAttachment({
    required String email,
    required Uint8List credentialUtf8,
    required String mailbox,
    required int uid,
    required String partId,
  });

  Future<ImapStorageQuotaRecord?> fetchQuota({
    required String email,
    required Uint8List credentialUtf8,
  });
}

final class ImapMailContentSource implements MailContentSource {
  ImapMailContentSource({ImapContentConnector? connect})
      : _connect = connect ?? ImapClient.connect;

  final ImapContentConnector _connect;

  @override
  Future<ParsedMessageBody> fetchBody({
    required String email,
    required Uint8List credentialUtf8,
    required String mailbox,
    required int uid,
  }) async {
    final client = await _connect();
    try {
      await client.login(email, credentialUtf8);
      await client.selectMailbox(mailbox);
      return await client.fetchMessageBody(uid);
    } finally {
      await client.close();
    }
  }

  @override
  Future<Uint8List> fetchAttachment({
    required String email,
    required Uint8List credentialUtf8,
    required String mailbox,
    required int uid,
    required String partId,
  }) async {
    final client = await _connect();
    try {
      await client.login(email, credentialUtf8);
      await client.selectMailbox(mailbox);
      return await client.fetchBodyPart(uid, partId);
    } finally {
      await client.close();
    }
  }

  @override
  Future<ImapStorageQuotaRecord?> fetchQuota({
    required String email,
    required Uint8List credentialUtf8,
  }) async {
    final client = await _connect();
    try {
      await client.login(email, credentialUtf8);
      return await client.storageQuota('INBOX');
    } finally {
      await client.close();
    }
  }
}

typedef AttachmentRootProvider = Future<Directory> Function();

/// Drift-backed implementation of the domain repositories and transport
/// orchestration. The database remains the durable source of truth.
final class LocalFirstMailRepository
    implements
        MailRepository,
        AttachmentRepository,
        PortableMailBackupRepository,
        PermanentMailDeletionRepository,
        TrashMailboxRepository,
        DraftRepository,
        MailSender {
  LocalFirstMailRepository({
    required GlassMailDatabase database,
    required CredentialStore credentialStore,
    required PendingMutationQueue mutationQueue,
    required OutgoingMailQueue outgoingQueue,
    InboxPageSource? inboxSource,
    SentMailboxPageSource? sentMailboxSource,
    MailContentSource? contentSource,
    MailDraftRemoteSource? remoteDraftSource,
    TrashMailboxPageSource? trashMailboxSource,
    AttachmentRootProvider? attachmentRoot,
    Future<void> Function(String accountId)? onAccountAdded,
    Future<void> Function(String accountId)? onAccountRemoved,
    ImapContentConnector? imapConnector,
    NewMailCallback? onNewMessages,
    int Function()? clock,
  })  : _database = database,
        _credentialStore = credentialStore,
        _mutationQueue = mutationQueue,
        _outgoingQueue = outgoingQueue,
        _sentMailboxSource = sentMailboxSource,
        _contentSource = contentSource ??
            ImapMailContentSource(connect: imapConnector ?? ImapClient.connect),
        _remoteDraftSource = remoteDraftSource ?? ImapMailDraftRemoteSource(),
        _trashMailboxSource = trashMailboxSource,
        _attachmentRoot = attachmentRoot ?? getApplicationSupportDirectory,
        _imapConnector = imapConnector ?? ImapClient.connect,
        _onAccountAdded = onAccountAdded,
        _onAccountRemoved = onAccountRemoved,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _sync = MailboxSyncCoordinator(
          database: database,
          credentialStore: credentialStore,
          source: inboxSource ?? ImapInboxPageSource(),
          clock: clock,
          onNewMessages: onNewMessages,
          flushPendingMutations: mutationQueue.flush,
        );

  static const debugAccountId = 'debug-fixture';
  static const _attachmentLimitBytes = 8 * 1024 * 1024;

  final GlassMailDatabase _database;
  final CredentialStore _credentialStore;
  final PendingMutationQueue _mutationQueue;
  final OutgoingMailQueue _outgoingQueue;
  final SentMailboxPageSource? _sentMailboxSource;
  final MailContentSource _contentSource;
  final MailDraftRemoteSource _remoteDraftSource;
  final TrashMailboxPageSource? _trashMailboxSource;
  final AttachmentRootProvider _attachmentRoot;
  final ImapContentConnector _imapConnector;
  final Future<void> Function(String accountId)? _onAccountAdded;
  final Future<void> Function(String accountId)? _onAccountRemoved;
  final int Function() _clock;

  static const _backupDataLimitBytes = 48 * 1024 * 1024;

  @override
  Future<Map<String, Object?>> exportBackupData() async {
    final database = await _database.exportPortableBackupRows();
    final estimatedTextBytes = _estimateJsonStringBytes(database);
    if (estimatedTextBytes > _backupDataLimitBytes) {
      throw StateError('Local mail data is too large for a portable backup.');
    }

    final root = await _attachmentRoot();
    final attachmentsDirectory = Directory('${root.path}/attachments');
    final files = <String, String>{};
    var fileBytes = 0;
    if (await attachmentsDirectory.exists()) {
      await for (final entity in attachmentsDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || entity.path.endsWith('.part')) continue;
        final relative = entity.path.substring(root.path.length + 1);
        _validateBackupAttachmentPath(relative);
        final length = await entity.length();
        fileBytes += length;
        if (estimatedTextBytes + fileBytes * 4 ~/ 3 > _backupDataLimitBytes) {
          throw StateError(
            'Cached attachments are too large for a portable backup.',
          );
        }
        files[relative] = base64Encode(await entity.readAsBytes());
      }
    }
    return {
      'format': 'glassmail.local-data.v1',
      'database': database,
      'files': files,
    };
  }

  @override
  Future<void> restoreBackupData(Map<String, dynamic> backup) async {
    if (backup['format'] != 'glassmail.local-data.v1') {
      throw const FormatException('Unsupported GlassMail backup data.');
    }
    final database = backup['database'];
    final rawFiles = backup['files'];
    if (database is! Map<String, dynamic> ||
        rawFiles is! Map<String, dynamic> ||
        rawFiles.length > 100000) {
      throw const FormatException('Backup data is incomplete.');
    }
    final files = <String, List<int>>{};
    var fileBytes = 0;
    for (final entry in rawFiles.entries) {
      _validateBackupAttachmentPath(entry.key);
      if (entry.value is! String) {
        throw const FormatException('Backup attachment data is invalid.');
      }
      final bytes = base64Decode(entry.value! as String);
      fileBytes += bytes.length;
      if (fileBytes > _backupDataLimitBytes) {
        throw const FormatException(
            'Backup attachments exceed the size limit.');
      }
      files[entry.key] = bytes;
    }

    final snapshot = Map<String, dynamic>.from(database);
    final tables = snapshot['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Backup database tables are invalid.');
    }
    final root = await _attachmentRoot();
    _rewriteDraftAttachmentPaths(tables, files.keys.toSet(), root.path);
    final movedFiles = <File>[];
    try {
      for (final entry in files.entries) {
        final target = File(
          '${root.path}/${entry.key.replaceAll('/', Platform.pathSeparator)}',
        );
        if (await target.exists()) {
          throw StateError(
            'A local attachment already exists. Restore into a clean install.',
          );
        }
        await target.parent.create(recursive: true);
        final temporary = File('${target.path}.restore-part');
        await temporary.writeAsBytes(entry.value, flush: true);
        await temporary.rename(target.path);
        movedFiles.add(target);
      }
      await _database.restorePortableBackupRows(snapshot);
    } on Object {
      for (final file in movedFiles) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  final MailboxSyncCoordinator _sync;

  @override
  Stream<List<MailAccount>> observeAccounts() => _database.watchAccounts().map(
        (accounts) => List.unmodifiable(accounts.map(_toMailAccount)),
      );

  @override
  Stream<AccountSyncSummary?> observeAccount(String accountId) =>
      _database.watchAccountSummary(accountId).map((summary) => summary == null
          ? null
          : AccountSyncSummary(
              accountId: summary.accountId,
              email: summary.email,
              syncState: summary.syncState,
              messageCount: summary.messageCount,
              gmailExtensionsEnabled: summary.gmailExtensionsEnabled,
              lastSyncedAtEpochMillis: summary.lastSyncedAtEpochMillis,
            ));

  @override
  Stream<List<MailListItem>> observeInbox(String accountId) =>
      _database.watchInbox(_inboxId(accountId)).map(_toMailListItems);

  @override
  Stream<List<MailListItem>> observeSent(String accountId) =>
      _database.watchInbox(_sentMailboxId(accountId)).map(_toMailListItems);

  @override
  Stream<List<MailListItem>> observeTrash(String accountId) =>
      _database.watchMailboxesForAccount(accountId).asyncExpand((mailboxes) {
        final mailbox = mailboxes
            .where((row) => _isTrashRemoteName(row.remoteName))
            .firstOrNull;
        return mailbox == null
            ? Stream.value(const <MailListItem>[])
            : _database.watchInbox(mailbox.mailboxId).map(_toMailListItems);
      });

  @override
  Future<String?> trashMailboxId(String accountId) async =>
      (await _database.watchMailboxesForAccount(accountId).first)
          .where((row) => _isTrashRemoteName(row.remoteName))
          .firstOrNull
          ?.mailboxId;

  @override
  Stream<List<MailListItem>> observeInboxCategory(
    String accountId,
    String category,
  ) =>
      _database
          .watchInbox(_inboxId(accountId), category: category)
          .map(_toMailListItems);

  @override
  Stream<List<MailListItem>> observeUnifiedInbox(
    List<String> accountIds,
    String category,
  ) =>
      _combineLatestLists(accountIds
              .map((id) => observeInboxCategory(id, category))
              .toList(growable: false))
          .map(_mergeMailLists);

  @override
  Stream<Map<String, int>> observeCategoryUnreadCounts(String accountId) =>
      _database.watchCategoryUnreadCounts(_inboxId(accountId)).map(
            (rows) => Map.unmodifiable({
              for (final row in rows) row.category: row.unreadCount,
            }),
          );

  @override
  Stream<Map<String, int>> observeUnifiedCategoryUnreadCounts(
    List<String> accountIds,
  ) =>
      _combineLatestLists(accountIds
              .map(observeCategoryUnreadCounts)
              .toList(growable: false))
          .map(_mergeUnreadCounts);

  @override
  Stream<List<MailListItem>> search(String accountId, String query) {
    final terms = _ftsTerms(query);
    if (terms.isEmpty) return Stream.value(const []);
    return _database
        .searchTerms(_inboxId(accountId), terms)
        .map(_toMailListItems);
  }

  @override
  Stream<List<MailListItem>> searchUnified(
    List<String> accountIds,
    String query,
  ) {
    final terms = _ftsTerms(query);
    if (terms.isEmpty) return Stream.value(const []);
    return _combineLatestLists(accountIds
            .map((id) => _database
                .searchTerms(_inboxId(id), terms)
                .map(_toMailListItems))
            .toList(growable: false))
        .map(_mergeMailLists);
  }

  @override
  Stream<MailCacheSettings> observeCacheSettings(String accountId) =>
      _database.watchCacheConfig(accountId).map((config) => config == null
          ? const MailCacheSettings()
          : MailCacheSettings(
              offlineMessageCount: config.offlineMessageCount,
              attachmentCacheLimitMb: config.attachmentCacheLimitMb,
              autoEvictReadOlderThanDays: config.autoEvictReadOlderThanDays,
              prefetchUnreadBodies: config.prefetchUnreadBodies != 0,
            ));

  @override
  Stream<StorageQuota?> observeStorageQuota(String accountId) =>
      _database.watchStorageQuota(accountId).map((quota) => quota == null
          ? null
          : StorageQuota(
              usedKb: quota.usedKb,
              limitKb: quota.limitKb,
              checkedAtEpochMillis: quota.checkedAtEpochMillis,
            ));

  @override
  Stream<MailMessage?> observeMessage(String messageId) => _combineLatest2(
        _database.watchMessage(messageId),
        _database.watchAttachments(messageId),
        (row, attachments) =>
            row == null ? null : _toMailMessage(row, attachments),
      );

  @override
  Stream<List<MailMessage>> observeThread(String messageId) =>
      _observeThread(messageId);

  @override
  Stream<List<MailMessage>> observeThreadInMailbox(
    String messageId,
    String mailboxId,
  ) =>
      _observeThread(messageId, mailboxId: mailboxId);

  Stream<List<MailMessage>> _observeThread(
    String messageId, {
    String? mailboxId,
  }) =>
      _switchMap(
        _database.watchThread(messageId, mailboxId: mailboxId),
        (rows) {
          if (rows.isEmpty) return Stream.value(const []);
          return _combineLatestLists(
            rows
                .map((row) => _database.watchAttachments(row.messageId))
                .toList(growable: false),
          ).map((attachments) => List.unmodifiable([
                for (var index = 0; index < rows.length; index++)
                  _toMailMessage(rows[index], attachments[index]),
              ]));
        },
      );

  @override
  Stream<List<MailDraft>> observeDrafts(String accountId) =>
      _database.watchDrafts(accountId).map((drafts) => List.unmodifiable(
            drafts.map(_toMailDraft),
          ));

  @override
  Stream<MailDraft?> observeDraft(String draftId) => _database
      .watchDraft(draftId)
      .map((draft) => draft == null ? null : _toMailDraft(draft));

  @override
  Future<void> createAccount(
    String accountId,
    String email, {
    required List<int> credentialUtf8,
    String syncState = 'READY',
  }) async {
    if (accountId.trim().isEmpty ||
        email.trim().isEmpty ||
        !email.contains('@')) {
      credentialUtf8.fillRange(0, credentialUtf8.length, 0);
      throw ArgumentError(
          'A non-empty account ID and valid email are required');
    }
    await _credentialStore.store(accountId, credentialUtf8);
    try {
      await _database.transaction(() async {
        await _database.saveAccount(AccountsCompanion.insert(
          accountId: accountId,
          email: email.trim(),
          createdAtEpochMillis: _clock(),
          syncState: syncState,
          gmailExtensionsEnabled: 0,
        ));
        await _database.saveCacheConfig(CacheConfigCompanion.insert(
          accountId: accountId,
        ));
      });
    } on Object {
      await _credentialStore.delete(accountId);
      rethrow;
    }
    await _onAccountAdded?.call(accountId);
  }

  @override
  Future<void> removeAccount(String accountId) async {
    await _credentialStore.delete(accountId);
    await _database.deleteAccount(accountId);
    await _onAccountRemoved?.call(accountId);
    final root = await _attachmentRoot();
    final directory = Directory(
      '${root.path}/attachments/${_fileKey(accountId)}',
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<void> updateCredential(
    String accountId,
    List<int> credentialUtf8,
  ) async {
    try {
      if (credentialUtf8.isEmpty ||
          await _database.accountById(accountId) == null) {
        throw ArgumentError('An existing account and password are required');
      }
      await _credentialStore.store(accountId, credentialUtf8);
      await _database.setAccountSyncState(accountId, 'READY');
      await _onAccountAdded?.call(accountId);
    } on Object {
      credentialUtf8.fillRange(0, credentialUtf8.length, 0);
      rethrow;
    }
  }

  @override
  Future<MailSyncResult> synchronize(String accountId) async {
    final result = await _sync.synchronize(accountId);
    if (result is MailSyncSuccess) {
      try {
        await _synchronizeSentMailbox(accountId);
      } on Object {
        // Sent sync is independent; retain the last usable local Sent snapshot.
      }
      try {
        await _synchronizeTrashMailbox(accountId);
      } on Object {
        // Trash refresh is independent; keep the last local Trash snapshot.
      }
      await _prefetchUnread(accountId);
      try {
        await refreshStorageQuota(accountId);
      } on Object {
        // Quota is provider-optional; failure does not invalidate a committed sync.
      }
      await enforceCacheLimits(accountId);
      if (!result.hasMore) {
        try {
          await _synchronizeRemoteDrafts(accountId);
        } on Object {
          // Remote draft sync is best effort; local drafts remain durable.
        }
      }
    }
    return result;
  }

  Future<void> _synchronizeSentMailbox(String accountId) async {
    final sentMailboxSource = _sentMailboxSource;
    if (sentMailboxSource == null) return;
    final account = await _database.accountById(accountId);
    if (account == null) return;
    final snapshot = await _credentialStore.withCredential(
      accountId,
      (credential) => sentMailboxSource.fetchLatest(
        email: account.email,
        credentialUtf8: credential,
      ),
    );
    if (snapshot == null) return;

    final mailboxId = _sentMailboxId(accountId);
    final checkpoint = await _database.checkpoint(mailboxId);
    final reset =
        checkpoint != null && checkpoint.uidValidity != snapshot.uidValidity;
    final highestKnownUid = snapshot.uidNext - 1;
    final seenUids = <int>{};
    final lowestReturnedUid = max(1, highestKnownUid - maxUidSlotsPerPage + 1);
    if (snapshot.messages.length > maxUidSlotsPerPage) {
      throw const ImapProtocolException('Sent mailbox returned too many UIDs');
    }
    for (final message in snapshot.messages) {
      if (message.uid <= 0 ||
          message.uid < lowestReturnedUid ||
          message.uid > highestKnownUid ||
          !seenUids.add(message.uid)) {
        throw const ImapProtocolException(
          'Sent mailbox returned an invalid UID page',
        );
      }
    }

    final messageRows = <MessagesCompanion>[];
    final memberships = <MailboxMessagesCompanion>[];
    for (final message in snapshot.messages) {
      final messageId = canonicalMessageId(
        accountId,
        snapshot.uidValidity,
        message,
      );
      messageRows.add(MessagesCompanion.insert(
        messageId: messageId,
        accountId: accountId,
        gmailMessageId: Value(message.gmailMessageId),
        gmailThreadId: Value(message.gmailThreadId),
        subject: Value(message.subject),
        sender: Value(message.sender),
        sentAtEpochMillis: Value(message.sentAtEpochMillis),
        sizeBytes: Value(message.sizeBytes),
        category: const Value('PRIMARY'),
        listUnsubscribe: Value(message.listUnsubscribe),
        listUnsubscribePost: Value(message.listUnsubscribePost),
        contentKind: 'PLAIN',
        bodyDownloadState: 'NOT_FETCHED',
      ));
      memberships.add(MailboxMessagesCompanion.insert(
        mailboxId: mailboxId,
        uid: message.uid,
        messageId: messageId,
        flags: (message.flags.toList()..sort()).join(' '),
        labels: (message.labels.toList()..sort()).join('\u001f'),
      ));
    }

    final now = _clock();
    await _database.commitMailboxSnapshot(
      mailbox: MailboxesCompanion.insert(
        mailboxId: mailboxId,
        accountId: accountId,
        remoteName: snapshot.remoteName,
        uidValidity: snapshot.uidValidity,
        uidNext: snapshot.uidNext,
        messageCount: snapshot.messageCount,
      ),
      messageRows: messageRows,
      memberships: memberships,
      checkpoint: SyncCheckpointsCompanion.insert(
        mailboxId: mailboxId,
        accountId: accountId,
        uidValidity: snapshot.uidValidity,
        highestKnownUid: highestKnownUid,
        syncGeneration: (checkpoint?.syncGeneration ?? 0) + (reset ? 1 : 0),
        lastSuccessfulSyncEpochMillis: Value(now),
      ),
      replaceMembership: reset,
    );
  }

  Future<void> _synchronizeTrashMailbox(String accountId) async {
    final trashMailboxSource = _trashMailboxSource;
    if (trashMailboxSource == null) return;
    final account = await _database.accountById(accountId);
    if (account == null) return;
    final snapshot = await _credentialStore.withCredential(
      accountId,
      (credential) => trashMailboxSource.fetchLatest(
        email: account.email,
        credentialUtf8: credential,
      ),
    );
    if (snapshot == null) return;
    if (snapshot.uidValidity <= 0 || snapshot.uidNext < 1) {
      throw const ImapProtocolException('Trash mailbox snapshot is invalid');
    }
    final mailboxId = '$accountId:${snapshot.remoteName}';
    final checkpoint = await _database.checkpoint(mailboxId);
    final reset =
        checkpoint != null && checkpoint.uidValidity != snapshot.uidValidity;
    final highestKnownUid = snapshot.uidNext - 1;
    final seenUids = <int>{};
    final lowestReturnedUid = max(1, highestKnownUid - maxUidSlotsPerPage + 1);
    if (snapshot.messages.length > maxUidSlotsPerPage) {
      throw const ImapProtocolException('Trash mailbox returned too many UIDs');
    }
    for (final message in snapshot.messages) {
      if (message.uid <= 0 ||
          message.uid < lowestReturnedUid ||
          message.uid > highestKnownUid ||
          !seenUids.add(message.uid)) {
        throw const ImapProtocolException(
            'Trash mailbox returned invalid UIDs');
      }
    }

    final messageRows = <MessagesCompanion>[];
    final memberships = <MailboxMessagesCompanion>[];
    for (final message in snapshot.messages) {
      final messageId = canonicalMessageId(
        accountId,
        snapshot.uidValidity,
        message,
      );
      messageRows.add(MessagesCompanion.insert(
        messageId: messageId,
        accountId: accountId,
        gmailMessageId: Value(message.gmailMessageId),
        gmailThreadId: Value(message.gmailThreadId),
        subject: Value(message.subject),
        sender: Value(message.sender),
        sentAtEpochMillis: Value(message.sentAtEpochMillis),
        sizeBytes: Value(message.sizeBytes),
        category: const Value('PRIMARY'),
        listUnsubscribe: Value(message.listUnsubscribe),
        listUnsubscribePost: Value(message.listUnsubscribePost),
        contentKind: 'PLAIN',
        bodyDownloadState: 'NOT_FETCHED',
      ));
      memberships.add(MailboxMessagesCompanion.insert(
        mailboxId: mailboxId,
        uid: message.uid,
        messageId: messageId,
        flags: (message.flags.toList()..sort()).join(' '),
        labels: (message.labels.toList()..sort()).join('\u001f'),
      ));
    }
    await _database.commitMailboxSnapshot(
      mailbox: MailboxesCompanion.insert(
        mailboxId: mailboxId,
        accountId: accountId,
        remoteName: snapshot.remoteName,
        uidValidity: snapshot.uidValidity,
        uidNext: snapshot.uidNext,
        messageCount: snapshot.messageCount,
      ),
      messageRows: messageRows,
      memberships: memberships,
      checkpoint: SyncCheckpointsCompanion.insert(
        mailboxId: mailboxId,
        accountId: accountId,
        uidValidity: snapshot.uidValidity,
        highestKnownUid: highestKnownUid,
        syncGeneration: (checkpoint?.syncGeneration ?? 0) + (reset ? 1 : 0),
        lastSuccessfulSyncEpochMillis: Value(_clock()),
      ),
      replaceMembership: true,
    );
  }

  @override
  Future<void> applyMutation(MailMutation mutation) =>
      _mutationQueue.applyLocal(mutation);

  @override
  Future<void> purgeFromTrash({
    required String accountId,
    required String messageId,
    required String mailboxId,
  }) async {
    final account = await _database.accountById(accountId);
    final message = await (_database.select(_database.messages)
          ..where((row) =>
              row.messageId.equals(messageId) &
              row.accountId.equals(accountId)))
        .getSingleOrNull();
    final mailbox = await (_database.select(_database.mailboxes)
          ..where((row) => row.mailboxId.equals(mailboxId)))
        .getSingleOrNull();
    if (account == null ||
        message == null ||
        mailbox == null ||
        mailbox.accountId != accountId) {
      throw StateError('Message is not in this account mailbox.');
    }
    if ((await _database.activeMutationsForMessage(messageId)).isNotEmpty) {
      throw StateError(
          'Sync pending message actions before permanent deletion.');
    }
    final membership = (await _database.membershipsForMessage(messageId))
        .where((row) => row.mailboxId == mailboxId)
        .firstOrNull;
    if (membership == null) {
      throw StateError('Message is not present in the selected Trash mailbox.');
    }
    final remoteMailbox = mailbox.remoteName;
    final authenticated = await _credentialStore.withCredential<bool>(
      accountId,
      (credential) async {
        final client = await _imapConnector();
        try {
          await client.login(account.email, credential);
          await client.selectMailbox(remoteMailbox);
          await client.permanentlyDeleteTrashUid(
            membership.uid,
            mailbox: remoteMailbox,
          );
          return true;
        } finally {
          await client.close();
        }
      },
    );
    if (authenticated != true) {
      throw StateError('Add this account password before permanent deletion.');
    }
    await _database.removeMailboxMembership(mailboxId, messageId);
  }

  @override
  Future<bool> undoPendingArchive(String messageId) =>
      _mutationQueue.undoPendingArchive(messageId);

  @override
  Future<void> saveCacheSettings(
    String accountId,
    MailCacheSettings settings,
  ) async {
    if (settings.offlineMessageCount < 0 ||
        settings.attachmentCacheLimitMb < 0 ||
        settings.autoEvictReadOlderThanDays < 0) {
      throw ArgumentError('Cache limits cannot be negative');
    }
    await _database.saveCacheConfig(CacheConfigCompanion.insert(
      accountId: accountId,
      offlineMessageCount: Value(settings.offlineMessageCount),
      attachmentCacheLimitMb: Value(settings.attachmentCacheLimitMb),
      autoEvictReadOlderThanDays: Value(settings.autoEvictReadOlderThanDays),
      prefetchUnreadBodies: Value(settings.prefetchUnreadBodies ? 1 : 0),
    ));
    await enforceCacheLimits(accountId);
  }

  @override
  Future<void> enforceCacheLimits(String accountId) async {
    final config = await _database.cacheConfigForAccount(accountId);
    final settings = config == null
        ? const MailCacheSettings()
        : MailCacheSettings(
            offlineMessageCount: config.offlineMessageCount,
            attachmentCacheLimitMb: config.attachmentCacheLimitMb,
            autoEvictReadOlderThanDays: config.autoEvictReadOlderThanDays,
            prefetchUnreadBodies: config.prefetchUnreadBodies != 0,
          );
    final before = _clock() -
        Duration(days: settings.autoEvictReadOlderThanDays).inMilliseconds;
    await _database.evictOldReadBodies(accountId, before);
    await _database.evictExcessBodies(
      accountId,
      settings.offlineMessageCount,
    );

    final root = await _attachmentRoot();
    final attachments = await _database.cachedAttachments(accountId);
    var cachedBytes = attachments.fold<int>(
      0,
      (total, attachment) => total + max(0, attachment.sizeBytes ?? 0),
    );
    final limitBytes = settings.attachmentCacheLimitMb * 1024 * 1024;
    for (final attachment in attachments) {
      if (cachedBytes <= limitBytes) break;
      final file = _attachmentFile(root, accountId, attachment.attachmentId);
      if (await file.exists()) await file.delete();
      await _database.setAttachmentDownloadState(
        attachment.attachmentId,
        'NOT_FETCHED',
      );
      cachedBytes -= max(0, attachment.sizeBytes ?? 0);
    }
  }

  @override
  Future<MailOperationResult<StorageQuota>> refreshStorageQuota(
    String accountId,
  ) async {
    final account = await _database.accountById(accountId);
    if (account == null) {
      return MailOperationFailure(StateError('Account is unavailable'));
    }
    try {
      final remote = await _credentialStore.withCredential(
        accountId,
        (credential) => _contentSource.fetchQuota(
          email: account.email,
          credentialUtf8: credential,
        ),
      );
      if (remote == null) {
        return MailOperationFailure(
          StateError('Credentials or IMAP storage quota are unavailable'),
        );
      }
      final quota = StorageQuota(
        usedKb: remote.usedKb,
        limitKb: remote.limitKb,
        checkedAtEpochMillis: _clock(),
      );
      await _database.saveStorageQuota(StorageQuotaCompanion.insert(
        accountId: accountId,
        usedKb: quota.usedKb,
        limitKb: quota.limitKb,
        checkedAtEpochMillis: quota.checkedAtEpochMillis,
      ));
      return MailOperationSuccess(quota);
    } on Object catch (error, stackTrace) {
      return MailOperationFailure(error, stackTrace: stackTrace);
    }
  }

  @override
  Future<MailOperationResult<MailMessage>> loadMessageBody(
    String messageId,
  ) async {
    try {
      final cachedState = await _database.bodyDownloadState(messageId);
      if (cachedState == 'AVAILABLE') {
        final cached = await observeMessage(messageId).first;
        if (cached?.body != null) return MailOperationSuccess(cached!);
      }
      final message = await (_database.select(_database.messages)
            ..where((row) => row.messageId.equals(messageId)))
          .getSingleOrNull();
      if (message == null) {
        return MailOperationFailure(StateError('Message is unavailable'));
      }
      final membership = await _membershipFor(messageId, message.accountId);
      if (membership == null) {
        return MailOperationFailure(
            StateError('Mailbox mapping is unavailable'));
      }
      final account = await _database.accountById(message.accountId);
      if (account == null) {
        return MailOperationFailure(StateError('Account is unavailable'));
      }
      await _database.updateMessageBody(
        messageId: messageId,
        body: message.body,
        preview: message.preview,
        contentKind: message.contentKind,
        downloadState: 'FETCHING',
      );
      final remoteMailbox =
          await _database.mailboxRemoteName(membership.mailboxId) ??
              membership.mailboxId.substringAfterColon;
      final parsed = await _credentialStore.withCredential(
        account.accountId,
        (credential) => _contentSource.fetchBody(
          email: account.email,
          credentialUtf8: credential,
          mailbox: remoteMailbox,
          uid: membership.uid,
        ),
      );
      if (parsed == null) {
        await _database.updateMessageBody(
          messageId: messageId,
          body: message.body,
          preview: message.preview,
          contentKind: message.contentKind,
          downloadState: 'FAILED',
        );
        return MailOperationFailure(StateError('Credentials are unavailable'));
      }
      final body = parsed.plainText ?? parsed.htmlText ?? '';
      await _database.transaction(() async {
        await _database.updateMessageBody(
          messageId: messageId,
          body: body,
          preview: parsed.previewSnippet,
          contentKind: parsed.htmlText == null ? 'PLAIN' : 'HTML',
          downloadState: 'AVAILABLE',
        );
        await _database.saveAttachments(parsed.attachments.map((attachment) {
          final id = _attachmentId(messageId, attachment.partId);
          return AttachmentsCompanion.insert(
            attachmentId: id,
            messageId: messageId,
            partId: attachment.partId,
            fileName: Value(attachment.fileName),
            mimeType: Value(attachment.mimeType),
            sizeBytes: Value(attachment.sizeBytes),
            downloadState: 'NOT_FETCHED',
          );
        }));
      });
      await enforceCacheLimits(message.accountId);
      final loaded = await observeMessage(messageId).first;
      if (loaded == null) {
        return MailOperationFailure<MailMessage>(
          StateError('Message disappeared after fetch'),
        );
      }
      return MailOperationSuccess<MailMessage>(loaded);
    } on Object catch (error, stackTrace) {
      final failed = await (_database.select(_database.messages)
            ..where((row) => row.messageId.equals(messageId)))
          .getSingleOrNull();
      if (failed != null) {
        await _database.updateMessageBody(
          messageId: messageId,
          body: failed.body,
          preview: failed.preview,
          contentKind: failed.contentKind,
          downloadState: 'FAILED',
        );
      }
      return MailOperationFailure(error, stackTrace: stackTrace);
    }
  }

  @override
  Future<MailOperationResult<DownloadedAttachment>> downloadAttachment(
    String accountId,
    String attachmentId,
  ) async {
    Attachment? attachment;
    try {
      final account = await _database.accountById(accountId);
      if (account == null) {
        return MailOperationFailure(StateError('Account is unavailable'));
      }
      attachment = await _database.attachmentById(attachmentId);
      if (attachment == null) {
        return MailOperationFailure(StateError('Attachment is unavailable'));
      }
      final currentAttachment = attachment;
      final message = await (_database.select(_database.messages)
            ..where((row) =>
                row.messageId.equals(currentAttachment.messageId) &
                row.accountId.equals(accountId)))
          .getSingleOrNull();
      if (message == null) {
        return MailOperationFailure(
          StateError('Attachment does not belong to this account'),
        );
      }
      final root = await _attachmentRoot();
      final target = _attachmentFile(root, accountId, attachmentId);
      final safeName =
          sanitizeAttachmentName(attachment.fileName ?? 'attachment');
      final mimeType = attachment.mimeType ?? 'application/octet-stream';
      if (attachment.downloadState == 'AVAILABLE' && await target.exists()) {
        await _database.markAttachmentAccessed(attachmentId, _clock());
        return MailOperationSuccess(DownloadedAttachment(
          filePath: target.path,
          fileName: safeName,
          mimeType: mimeType,
        ));
      }
      final membership = await _membershipFor(message.messageId, accountId);
      if (membership == null) {
        return MailOperationFailure(
            StateError('Mailbox mapping is unavailable'));
      }
      await _database.setAttachmentDownloadState(attachmentId, 'FETCHING');
      final remoteMailbox =
          await _database.mailboxRemoteName(membership.mailboxId) ??
              membership.mailboxId.substringAfterColon;
      final payload = await _credentialStore.withCredential(
        accountId,
        (credential) => _contentSource.fetchAttachment(
          email: account.email,
          credentialUtf8: credential,
          mailbox: remoteMailbox,
          uid: membership.uid,
          partId: attachment!.partId,
        ),
      );
      if (payload == null) {
        await _database.setAttachmentDownloadState(attachmentId, 'FAILED');
        return MailOperationFailure(StateError('Credentials are unavailable'));
      }
      if (payload.length > _attachmentLimitBytes) {
        await _database.setAttachmentDownloadState(attachmentId, 'FAILED');
        return MailOperationFailure(
          StateError('Attachment exceeds the 8 MiB IMAP literal limit'),
        );
      }
      await target.parent.create(recursive: true);
      final temporary = File('${target.path}.part');
      await temporary.writeAsBytes(payload, flush: true);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      await _database.setAttachmentDownloadState(attachmentId, 'AVAILABLE');
      await _database.markAttachmentAccessed(attachmentId, _clock());
      await enforceCacheLimits(accountId);
      if (!await target.exists()) {
        return MailOperationFailure(
          StateError('Attachment exceeds the configured cache limit'),
        );
      }
      return MailOperationSuccess(DownloadedAttachment(
        filePath: target.path,
        fileName: safeName,
        mimeType: mimeType,
      ));
    } on Object catch (error, stackTrace) {
      if (attachment != null) {
        await _database.setAttachmentDownloadState(attachmentId, 'FAILED');
      }
      return MailOperationFailure(error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> saveDraft(MailDraft draft) async {
    if (draft.draftId.isEmpty || draft.accountId.isEmpty) {
      throw ArgumentError('Draft and account IDs are required');
    }
    if (await _database.accountById(draft.accountId) == null) {
      throw StateError('Draft account is unavailable');
    }
    await _outgoingQueue.save(draft);
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    final draft = await _database.watchDraft(draftId).first;
    await _database.deleteDraft(draftId);
    if (draft == null || draft.status != DraftStatus.draft.storageValue) return;
    final account = await _database.accountById(draft.accountId);
    if (account == null) return;
    // Remote deletion is best effort; the local delete is already durable.
    try {
      await _credentialStore.withCredential(
        account.accountId,
        (credential) {
          final location = _remoteDraftLocation(draftId);
          return _remoteDraftSource.delete(
            email: account.email,
            credentialUtf8: credential,
            draftId: draftId,
            remoteUid: location?.$2,
            remoteUidValidity: location?.$1,
          );
        },
      );
    } on Object {
      // The local delete is durable; a later IMAP sync can remove a stale copy.
    }
  }

  @override
  Future<bool> cancelQueuedSend(String draftId) async =>
      _database.restoreQueuedDraft(
        draftId: draftId,
        updatedAtEpochMillis: _clock(),
      );

  @override
  Future<SendMailResult> send(MailAccount account, OutgoingMail mail) async {
    final draft = MailDraft(
      draftId: mail.operationId,
      accountId: mail.accountId,
      to: mail.to,
      cc: mail.cc,
      bcc: mail.bcc,
      subject: mail.subject,
      body: mail.body,
      inReplyTo: mail.inReplyTo,
      references: mail.references,
      attachments: mail.attachments
          .where((attachment) => attachment.uri != null)
          .map((attachment) => DraftAttachment(
                uri: attachment.uri!,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                sizeBytes: attachment.sizeBytes,
              ))
          .toList(growable: false),
    );
    await saveDraft(draft);
    return _outgoingQueue.send(account, draft, mail);
  }

  @override
  Future<void> seedDebugMailbox(int count) async {
    if (![10, 100, 1000, 10000].contains(count)) {
      throw ArgumentError.value(count, 'count');
    }
    await clearDebugMailbox();
    await _database.saveAccount(AccountsCompanion.insert(
      accountId: debugAccountId,
      email: 'debug@glassmail.local',
      createdAtEpochMillis: _clock(),
      syncState: 'READY',
      gmailExtensionsEnabled: 0,
    ));
    await _database.saveCacheConfig(CacheConfigCompanion.insert(
      accountId: debugAccountId,
    ));
    await _database.saveMailboxes([
      MailboxesCompanion.insert(
        mailboxId: _inboxId(debugAccountId),
        accountId: debugAccountId,
        remoteName: 'INBOX',
        uidValidity: 1,
        uidNext: count + 1,
        messageCount: count,
      ),
    ]);
    await _database.saveCheckpoint(SyncCheckpointsCompanion.insert(
      mailboxId: _inboxId(debugAccountId),
      accountId: debugAccountId,
      uidValidity: 1,
      highestKnownUid: count,
      syncGeneration: 1,
      lastSuccessfulSyncEpochMillis: Value(_clock()),
    ));
    for (var start = 1; start <= count; start += 200) {
      final end = min(count, start + 199);
      final messages = <MessagesCompanion>[];
      final memberships = <MailboxMessagesCompanion>[];
      final attachments = <AttachmentsCompanion>[];
      final labels = <MessageLabelsCompanion>[];
      for (var index = start; index <= end; index++) {
        final id = 'debug:$index';
        final sender = _debugSenders[(index - 1) % _debugSenders.length];
        final category = index % 17 == 0
            ? MailCategory.social
            : index % 13 == 0
                ? MailCategory.promotions
                : index % 11 == 0
                    ? MailCategory.updates
                    : index % 7 == 0
                        ? MailCategory.forums
                        : MailCategory.primary;
        final subject = _debugSubjects[(index - 1) % _debugSubjects.length];
        final preview =
            'Local deterministic fixture $index for inbox and search.';
        messages.add(MessagesCompanion.insert(
          messageId: id,
          accountId: debugAccountId,
          gmailMessageId: Value('debug-$index'),
          gmailThreadId: Value('thread-${(index - 1) ~/ 3}'),
          subject: Value(subject),
          sender: Value(sender),
          sentAtEpochMillis: Value(1735689600000 - index * 60000),
          sizeBytes: Value(1024 + index),
          category: Value(category),
          preview: Value(preview),
          body: Value(preview),
          contentKind: 'PLAIN',
          bodyDownloadState: 'AVAILABLE',
        ));
        final flags = <String>[];
        if (index % 3 != 0) flags.add(r'\Seen');
        if (index % 5 == 0) flags.add(r'\Flagged');
        memberships.add(MailboxMessagesCompanion.insert(
          mailboxId: _inboxId(debugAccountId),
          uid: index,
          messageId: id,
          flags: flags.join(' '),
          labels: index % 5 == 0 ? 'STARRED\u001fINBOX' : 'INBOX',
        ));
        if (index % 7 == 0) {
          labels.add(MessageLabelsCompanion.insert(
            messageId: id,
            label: 'Travel',
          ));
        }
        if (index % 9 == 0) {
          attachments.add(AttachmentsCompanion.insert(
            attachmentId: '$id:1',
            messageId: id,
            partId: '1',
            fileName: Value('fixture-$index.pdf'),
            mimeType: const Value('application/pdf'),
            sizeBytes: const Value(4096),
            downloadState: 'NOT_FETCHED',
          ));
        }
      }
      await _database.transaction(() async {
        await _database.saveMessages(messages);
        await _database.saveMailboxMessages(memberships);
        await _database.saveLabels(labels);
        await _database.saveAttachments(attachments);
      });
    }
  }

  @override
  Future<void> clearDebugMailbox() async {
    await _database.deleteAccount(debugAccountId);
  }

  Future<void> _prefetchUnread(String accountId) async {
    final config = await _database.cacheConfigForAccount(accountId);
    if (config?.prefetchUnreadBodies != 1) return;
    final rows = await _database.watchInbox(_inboxId(accountId)).first;
    final unread = rows
        .where((row) => !_decodeFlags(row.flags).contains(r'\Seen'))
        .take(12);
    for (final row in unread) {
      if (await _database.bodyDownloadState(row.messageId) == 'AVAILABLE') {
        continue;
      }
      await loadMessageBody(row.messageId);
    }
  }

  Future<void> _synchronizeRemoteDrafts(String accountId) async {
    final account = await _database.accountById(accountId);
    if (account == null) return;
    final remote = await _credentialStore.withCredential(
      accountId,
      (credential) => _remoteDraftSource.fetch(
        email: account.email,
        credentialUtf8: credential,
      ),
    );
    if (remote == null) return;

    final locals = await _database.watchDrafts(accountId).first;
    final localById = {for (final draft in locals) draft.draftId: draft};
    final remoteById = <String, ImapRemoteDraft>{};
    final encodedAccount = _fileKey(accountId);
    for (final remoteDraft in remote) {
      final remoteId = remoteDraft.draftId;
      final id = remoteId != null &&
              RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(remoteId)
          ? remoteId
          : 'remote-${encodedAccount.substring(0, min(32, encodedAccount.length))}-${remoteDraft.uidValidity ?? 0}-${remoteDraft.uid}';
      if (remoteId != null) remoteById[remoteId] = remoteDraft;

      final local = localById[id];
      final remoteTime = remoteDraft.updatedAtEpochMillis > 0
          ? remoteDraft.updatedAtEpochMillis
          : _clock();
      if (local == null ||
          (local.status == DraftStatus.draft.storageValue &&
              local.updatedAtEpochMillis < remoteTime)) {
        final replacement = MailDraft(
          draftId: id,
          accountId: accountId,
          to: remoteDraft.to,
          cc: remoteDraft.cc,
          bcc: remoteDraft.bcc,
          subject: remoteDraft.subject,
          body: remoteDraft.body,
          inReplyTo: remoteDraft.inReplyTo,
          references: remoteDraft.references,
          status: DraftStatus.draft,
          updatedAtEpochMillis: remoteTime,
          attachments:
              local == null ? const [] : _toMailDraft(local).attachments,
        );
        await saveDraft(replacement);
        final saved = await _database.watchDraft(id).first;
        if (saved != null) localById[id] = saved;
      }
    }

    for (final stored in localById.values) {
      final local = _toMailDraft(stored);
      if (local.status != DraftStatus.draft ||
          local.draftId.startsWith('remote-')) {
        continue;
      }
      final remoteDraft = remoteById[local.draftId];
      if (remoteDraft == null ||
          local.updatedAtEpochMillis > remoteDraft.updatedAtEpochMillis) {
        await _credentialStore.withCredential(
          accountId,
          (credential) => _remoteDraftSource.save(
            email: account.email,
            credentialUtf8: credential,
            draft: local,
          ),
        );
      }
    }
  }

  Future<MailboxMessage?> _membershipFor(
    String messageId,
    String accountId,
  ) async {
    final memberships = await _database.membershipsForMessage(messageId);
    return memberships
        .where((row) => row.mailboxId.startsWith('$accountId:'))
        .firstOrNull;
  }
}

String _inboxId(String accountId) => '$accountId:INBOX';
String _sentMailboxId(String accountId) => '$accountId:SENT';
bool _isTrashRemoteName(String name) => const {
      '[gmail]/trash',
      'trash',
      'bin',
    }.contains(name.toLowerCase());

MailAccount _toMailAccount(Account account) => MailAccount(
      accountId: account.accountId,
      email: account.email,
      syncState: account.syncState,
    );

List<MailListItem> _toMailListItems(List<MailboxMessageRow> rows) =>
    List.unmodifiable(rows.map((row) => MailListItem(
          messageId: row.messageId,
          threadId: row.gmailThreadId,
          sender: row.sender ?? '',
          subject: row.subject ?? '',
          preview: row.preview ?? '',
          sentAtEpochMillis: row.sentAtEpochMillis,
          unread: !_decodeFlags(row.flags).contains(r'\Seen'),
          starred: _decodeFlags(row.flags).contains(r'\Flagged'),
          labels: _decodeLabels(row.labels),
          hasAttachment: row.hasAttachment,
          category: row.category,
        )));

List<MailListItem> _mergeMailLists(List<List<MailListItem>> lists) {
  final merged = [for (final list in lists) ...list];
  merged.sort((a, b) {
    final aTime = a.sentAtEpochMillis;
    final bTime = b.sentAtEpochMillis;
    if (aTime == null) return bTime == null ? 0 : 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return List.unmodifiable(merged);
}

Map<String, int> _mergeUnreadCounts(List<Map<String, int>> values) {
  final merged = <String, int>{};
  for (final counts in values) {
    for (final entry in counts.entries) {
      merged.update(
        entry.key,
        (count) => count + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }
  return Map.unmodifiable(merged);
}

MailMessage _toMailMessage(
  MessageDetailRow row,
  List<Attachment> attachments,
) =>
    MailMessage(
      messageId: row.messageId,
      threadId: row.gmailThreadId,
      sender: row.sender ?? '',
      subject: row.subject ?? '',
      preview: row.preview ?? '',
      body: row.body,
      html: row.contentKind == 'HTML',
      sentAtEpochMillis: row.sentAtEpochMillis,
      unread: !_decodeFlags(row.flags).contains(r'\Seen'),
      starred: _decodeFlags(row.flags).contains(r'\Flagged'),
      labels: _decodeLabels(row.labels),
      attachments: attachments
          .map((attachment) => MailAttachment(
                attachmentId: attachment.attachmentId,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                sizeBytes: attachment.sizeBytes,
                downloadState: attachment.downloadState,
              ))
          .toList(growable: false),
      listUnsubscribe: row.listUnsubscribe,
      listUnsubscribePost: row.listUnsubscribePost,
    );

MailDraft _toMailDraft(Draft draft) => MailDraft(
      draftId: draft.draftId,
      accountId: draft.accountId,
      to: _decodeUnitList(draft.toAddresses),
      cc: _decodeUnitList(draft.ccAddresses),
      bcc: _decodeUnitList(draft.bccAddresses),
      subject: draft.subject,
      body: draft.body,
      inReplyTo: draft.inReplyTo,
      references: _decodeUnitList(draft.references),
      status: DraftStatus.fromStorageValue(draft.status),
      updatedAtEpochMillis: draft.updatedAtEpochMillis,
      attachments: _decodeStoredAttachments(draft.attachments),
    );

List<String> _ftsTerms(String input) {
  final tokens = RegExp(r'[\p{L}\p{N}_]+', unicode: true)
      .allMatches(input.toLowerCase())
      .map((match) => match[0]!)
      .toSet()
      .take(12)
      .toList(growable: false);
  return List.unmodifiable(tokens.map((token) => '"$token"*'));
}

Set<String> _decodeFlags(String encoded) =>
    encoded.split(' ').where((flag) => flag.isNotEmpty).toSet();

List<String> _decodeLabels(String encoded) => encoded
    .split('\u001f')
    .where((label) => label.isNotEmpty)
    .toList(growable: false);

String _attachmentId(String messageId, String partId) =>
    'attachment:${base64Url.encode(utf8.encode('$messageId\u0000$partId')).replaceAll('=', '')}';

String _fileKey(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

File _attachmentFile(Directory root, String accountId, String attachmentId) => File(
    '${root.path}/attachments/${_fileKey(accountId)}/${_fileKey(attachmentId)}');

const _debugSenders = [
  'Ada Lovelace <ada@example.test>',
  'Grace Hopper <grace@example.test>',
  'Linus Torvalds <linus@example.test>',
  'Margaret Hamilton <margaret@example.test>',
  'Katherine Johnson <katherine@example.test>',
];

const _debugSubjects = [
  'Quarterly update',
  'Design review',
  'Travel itinerary',
  'Build status',
  'Welcome to GlassMail',
];

List<String> _decodeUnitList(String values) =>
    values.split('\u001f').where((value) => value.isNotEmpty).toList();

(int, int)? _remoteDraftLocation(String draftId) {
  final match = RegExp(r'^remote-.+-(\d+)-(\d+)$').firstMatch(draftId);
  if (match == null) return null;
  final uidValidity = int.tryParse(match[1]!);
  final uid = int.tryParse(match[2]!);
  if (uidValidity == null || uid == null || uid <= 0) return null;
  return (uidValidity, uid);
}

List<DraftAttachment> _decodeStoredAttachments(String encoded) => encoded
    .split('\u001e')
    .map((row) => row.split('\u001f'))
    .where((parts) => parts.length == 4 && int.tryParse(parts[3]) != null)
    .map((parts) => DraftAttachment(
          uri: parts[0],
          fileName: parts[1],
          mimeType: parts[2],
          sizeBytes: int.parse(parts[3]),
        ))
    .toList();

int _estimateJsonStringBytes(Object? value) {
  if (value is String) return utf8.encode(value).length + 2;
  if (value is Map) {
    return value.entries.fold<int>(
        2,
        (total, entry) =>
            total +
            _estimateJsonStringBytes(entry.key.toString()) +
            _estimateJsonStringBytes(entry.value) +
            2);
  }
  if (value is Iterable) {
    return value.fold<int>(
        2, (total, item) => total + _estimateJsonStringBytes(item) + 1);
  }
  return 16;
}

void _validateBackupAttachmentPath(String relativePath) {
  final segments = relativePath.replaceAll('\\', '/').split('/');
  if (!relativePath.startsWith('attachments/') ||
      segments.length < 3 ||
      segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..') ||
      segments.any((segment) => segment.contains(':'))) {
    throw const FormatException('Backup contains an unsafe attachment path.');
  }
}

void _rewriteDraftAttachmentPaths(
  Map<String, dynamic> tables,
  Set<String> restoredFiles,
  String rootPath,
) {
  final drafts = tables['drafts'];
  if (drafts is! List) {
    throw const FormatException('Backup drafts are invalid.');
  }
  for (final rawDraft in drafts) {
    if (rawDraft is! Map<String, dynamic> ||
        rawDraft['attachments'] is! String) {
      throw const FormatException('Backup draft attachment data is invalid.');
    }
    final encoded = rawDraft['attachments']! as String;
    if (encoded.isEmpty) continue;
    rawDraft['attachments'] = encoded.split('\u001e').map((entry) {
      final parts = entry.split('\u001f');
      if (parts.length != 4) {
        throw const FormatException('Backup draft attachment is malformed.');
      }
      final uri = Uri.tryParse(parts[0]);
      final originalPath =
          uri != null && uri.scheme == 'file' ? uri.toFilePath() : parts[0];
      final slashPath = originalPath.replaceAll('\\', '/');
      const marker = '/attachments/';
      final markerIndex = slashPath.lastIndexOf(marker);
      if (markerIndex < 0) {
        throw const FormatException(
          'A draft attachment is outside GlassMail local storage.',
        );
      }
      final relativePath =
          'attachments/${slashPath.substring(markerIndex + marker.length)}';
      _validateBackupAttachmentPath(relativePath);
      if (!restoredFiles.contains(relativePath)) {
        throw const FormatException(
          'A draft attachment is missing from the backup.',
        );
      }
      parts[0] = Uri.file(
        '$rootPath${Platform.pathSeparator}'
        '${relativePath.replaceAll('/', Platform.pathSeparator)}',
      ).toString();
      return parts.join('\u001f');
    }).join('\u001e');
  }
}

extension _MailboxIdParsing on String {
  String get substringAfterColon => split(':').skip(1).join(':');
}

Stream<R> _combineLatest2<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? firstSub;
  StreamSubscription<B>? secondSub;
  A? firstValue;
  B? secondValue;
  var hasFirst = false;
  var hasSecond = false;
  var completed = 0;
  void emit() {
    if (hasFirst && hasSecond) {
      controller.add(combine(firstValue as A, secondValue as B));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      firstSub = first.listen(
          (value) {
            firstValue = value;
            hasFirst = true;
            emit();
          },
          onError: controller.addError,
          onDone: () {
            if (++completed == 2) controller.close();
          });
      secondSub = second.listen(
          (value) {
            secondValue = value;
            hasSecond = true;
            emit();
          },
          onError: controller.addError,
          onDone: () {
            if (++completed == 2) controller.close();
          });
    },
    onCancel: () async {
      await firstSub?.cancel();
      await secondSub?.cancel();
    },
  );
  return controller.stream;
}

Stream<List<T>> _combineLatestLists<T>(List<Stream<T>> sources) {
  if (sources.isEmpty) return Stream.value(const []);
  late StreamController<List<T>> controller;
  final subscriptions = <StreamSubscription<T>>[];
  final values = List<T?>.filled(sources.length, null);
  final ready = List<bool>.filled(sources.length, false);
  var completed = 0;
  controller = StreamController<List<T>>(
    onListen: () {
      for (var index = 0; index < sources.length; index++) {
        subscriptions.add(sources[index].listen(
            (value) {
              values[index] = value;
              ready[index] = true;
              if (ready.every((value) => value)) {
                controller.add(List.unmodifiable(values.cast<T>()));
              }
            },
            onError: controller.addError,
            onDone: () {
              if (++completed == sources.length) controller.close();
            }));
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

Stream<R> _switchMap<T, R>(
  Stream<T> source,
  Stream<R> Function(T) convert,
) {
  late StreamController<R> controller;
  StreamSubscription<T>? sourceSub;
  StreamSubscription<R>? innerSub;
  var sourceDone = false;
  controller = StreamController<R>(
    onListen: () {
      sourceSub = source.listen(
          (value) async {
            await innerSub?.cancel();
            innerSub = convert(value).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                if (sourceDone) controller.close();
              },
            );
          },
          onError: controller.addError,
          onDone: () {
            sourceDone = true;
            if (innerSub == null) controller.close();
          });
    },
    onCancel: () async {
      await sourceSub?.cancel();
      await innerSub?.cancel();
    },
  );
  return controller.stream;
}
