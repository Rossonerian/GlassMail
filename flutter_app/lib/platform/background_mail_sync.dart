import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:glassmail_data_mail/glassmail_data_mail.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';
import 'package:workmanager/workmanager.dart';

import 'account_sync_scheduler.dart';
import 'mail_notifications.dart';

@pragma('vm:entry-point')
void glassMailBackgroundDispatcher() {
  final idleSessions = _BackgroundIdleSessions();
  Workmanager().executeTask(
    (taskName, inputData) async {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      try {
        if (taskName == accountIdleTaskName) {
          return await idleSessions.run();
        }
        if (taskName == delayedSendTaskName) {
          final draftId = inputData?['draftId'] as String?;
          if (draftId == null || draftId.isEmpty) return true;
          return await _sendQueuedDraft(draftId);
        }
        final accountId = inputData?['accountId'] as String?;
        final database = GlassMailDatabase();
        try {
          final accounts = await database.watchAccounts().first;
          final targets = accountId == null
              ? accounts.map((account) => account.accountId).toList()
              : [accountId];
          final notifications = MailNotifications();
          await notifications.initialize();
          final credentials = FlutterCredentialStore();
          final mutationQueue = PendingMutationQueue(
            database: database,
            credentialStore: credentials,
            transport: ImapPendingMutationTransport(),
          );
          final outgoingQueue = OutgoingMailQueue(
            database: database,
            credentialStore: credentials,
            transport: SecureSmtpMailTransport(),
            sentCopyAppender: ImapSentCopyAppender(),
          );
          final repository = LocalFirstMailRepository(
            database: database,
            credentialStore: credentials,
            mutationQueue: mutationQueue,
            outgoingQueue: outgoingQueue,
            sentMailboxSource: ImapSentMailboxPageSource(),
            trashMailboxSource: ImapTrashMailboxPageSource(),
            onAccountAdded: AccountSyncScheduler().scheduleAccount,
            onAccountRemoved: AccountSyncScheduler().cancelAccount,
            onNewMessages: notifications.showNewMessages,
          );

          var retry = false;
          for (final id in targets) {
            final result = await repository.synchronize(id);
            if (result case MailSyncFailure(error: MailSyncError.network)) {
              retry = true;
            } else if (result case MailSyncSuccess(hasMore: true)) {
              await AccountSyncScheduler().scheduleContinuation(id);
            }
          }
          return !retry;
        } finally {
          await database.close();
        }
      } on Object {
        // WorkManager retries without placing server errors or credentials in logs.
        return false;
      }
    },
    onTaskStopped: (taskName, stopReason) async {
      if (taskName == accountIdleTaskName) await idleSessions.stop();
    },
  );
}

Future<bool> _sendQueuedDraft(String draftId) async {
  final database = GlassMailDatabase();
  try {
    final credentials = FlutterCredentialStore();
    final mutationQueue = PendingMutationQueue(
      database: database,
      credentialStore: credentials,
      transport: ImapPendingMutationTransport(),
    );
    final outgoingQueue = OutgoingMailQueue(
      database: database,
      credentialStore: credentials,
      transport: SecureSmtpMailTransport(),
      sentCopyAppender: ImapSentCopyAppender(),
    );
    final repository = LocalFirstMailRepository(
      database: database,
      credentialStore: credentials,
      mutationQueue: mutationQueue,
      outgoingQueue: outgoingQueue,
      onAccountRemoved: AccountSyncScheduler().cancelAccount,
    );
    final draft = await repository.observeDraft(draftId).first;
    if (draft == null || draft.status != DraftStatus.queued) return true;
    final account = (await repository.observeAccounts().first)
        .where((candidate) => candidate.accountId == draft.accountId)
        .firstOrNull;
    if (account == null) return true;

    final attachments = <OutgoingAttachment>[];
    for (final attachment in draft.attachments) {
      final file = _localAttachmentFile(attachment.uri);
      if (file == null || !await file.exists()) {
        await repository.saveDraft(_draftWithStatus(draft, DraftStatus.failed));
        return true;
      }
      attachments.add(
        OutgoingAttachment(
          uri: attachment.uri,
          fileName: attachment.fileName,
          mimeType: attachment.mimeType,
          sizeBytes: attachment.sizeBytes,
          openStream: file.openRead,
        ),
      );
    }
    final message = OutgoingMail(
      operationId: draft.draftId,
      accountId: account.accountId,
      from: account.email,
      to: draft.to,
      cc: draft.cc,
      bcc: draft.bcc,
      subject: draft.subject,
      body: draft.body,
      inReplyTo: draft.inReplyTo,
      references: draft.references,
      attachments: attachments,
    );
    final result = await outgoingQueue.send(
      account,
      draft,
      message,
      requireQueued: true,
    );
    return result is! MailSendFailed || result.error != SendMailError.network;
  } finally {
    await database.close();
  }
}

File? _localAttachmentFile(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.hasScheme && uri.scheme != 'file')) return null;
  return File(uri.scheme == 'file' ? uri.toFilePath() : value);
}

MailDraft _draftWithStatus(MailDraft draft, DraftStatus status) => MailDraft(
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
  updatedAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
  attachments: draft.attachments,
);

final class _BackgroundIdleSessions {
  bool _stopped = false;
  final Map<String, _IdleAccountLoop> _loops = {};

  Future<bool> run() async {
    final database = GlassMailDatabase();
    try {
      while (!_stopped) {
        final accounts = await database.watchAccounts().first;
        final accountIds = accounts.map((account) => account.accountId).toSet();
        for (final stale in _loops.keys.toSet().difference(accountIds)) {
          await _loops.remove(stale)?.stop();
        }
        for (final accountId in accountIds) {
          _loops.putIfAbsent(
            accountId,
            () => _IdleAccountLoop(
              accountId: accountId,
              database: database,
              credentials: FlutterCredentialStore(),
            )..start(),
          );
        }
        if (_loops.isEmpty) return true;
        await Future<void>.delayed(const Duration(seconds: 30));
      }
      return true;
    } finally {
      for (final loop in _loops.values) {
        await loop.stop();
      }
      _loops.clear();
      await database.close();
    }
  }

  Future<void> stop() async {
    _stopped = true;
    for (final loop in _loops.values) {
      await loop.stop();
    }
  }
}

final class _IdleAccountLoop {
  _IdleAccountLoop({
    required this.accountId,
    required this.database,
    required this.credentials,
  });

  final String accountId;
  final GlassMailDatabase database;
  final FlutterCredentialStore credentials;
  ImapClient? _client;
  bool _stopped = false;

  void start() {
    _maintain();
  }

  Future<void> _maintain() async {
    var retryDelay = const Duration(seconds: 2);
    while (!_stopped) {
      try {
        final account = await database.accountById(accountId);
        if (account == null) return;
        final connected = await credentials.withCredential<bool>(accountId, (
          credential,
        ) async {
          final client = await ImapClient.connect();
          _client = client;
          try {
            await client.login(account.email, credential);
            await client.selectMailbox('INBOX');
            await client.idle(
              window: const Duration(minutes: 24),
              onMailboxChanged: () =>
                  AccountSyncScheduler().scheduleManualRefresh(accountId),
            );
            return true;
          } finally {
            if (identical(_client, client)) _client = null;
            await client.close();
          }
        });
        if (_stopped) return;
        if (connected == null) {
          await Future<void>.delayed(const Duration(minutes: 5));
          continue;
        }
        retryDelay = const Duration(seconds: 2);
      } on Object {
        if (_stopped) return;
        await Future<void>.delayed(retryDelay);
        retryDelay = Duration(
          seconds: (retryDelay.inSeconds * 2).clamp(2, 300).toInt(),
        );
      }
    }
  }

  Future<void> stop() async {
    _stopped = true;
    final client = _client;
    _client = null;
    await client?.close();
  }
}
