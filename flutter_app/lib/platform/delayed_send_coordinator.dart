import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

import 'account_sync_scheduler.dart';

/// A durable Android undo window and a foreground-only iOS undo window.
/// Draft content stays in the local repository; WorkManager receives only ID.
final class DelayedSendCoordinator with WidgetsBindingObserver {
  DelayedSendCoordinator({
    required this.drafts,
    required this.sender,
    AccountSyncScheduler? scheduler,
  }) : _scheduler = scheduler ?? AccountSyncScheduler() {
    WidgetsBinding.instance.addObserver(this);
  }

  final DraftRepository drafts;
  final MailSender sender;
  final AccountSyncScheduler _scheduler;
  final Map<String, _PendingSend> _pending = {};

  Future<void> queue(
    MailAccount account,
    OutgoingMail message, {
    required Duration undoWindow,
  }) async {
    if (undoWindow.isNegative) {
      throw ArgumentError.value(undoWindow, 'undoWindow');
    }
    if (account.accountId != message.accountId ||
        account.email != message.from ||
        message.attachments.any((attachment) => attachment.uri == null)) {
      throw ArgumentError(
        'A matching account and locally retained files are required',
      );
    }
    final draft = MailDraft(
      draftId: message.operationId,
      accountId: message.accountId,
      to: message.to,
      cc: message.cc,
      bcc: message.bcc,
      subject: message.subject,
      body: message.body,
      inReplyTo: message.inReplyTo,
      references: message.references,
      status: DraftStatus.queued,
      updatedAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
      attachments: message.attachments
          .map(
            (attachment) => DraftAttachment(
              uri: attachment.uri!,
              fileName: attachment.fileName,
              mimeType: attachment.mimeType,
              sizeBytes: attachment.sizeBytes,
            ),
          )
          .toList(growable: false),
    );
    await drafts.saveDraft(draft);
    if (Platform.isAndroid) {
      try {
        await _scheduler.scheduleDelayedSend(draft.draftId, undoWindow);
      } on Object {
        await drafts.cancelQueuedSend(draft.draftId);
        rethrow;
      }
      return;
    }
    if (Platform.isIOS) {
      _pending[draft.draftId]?.timer?.cancel();
      _pending[draft.draftId] = _PendingSend(
        account: account,
        message: message,
        deadline: DateTime.now().add(undoWindow),
      );
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _arm(draft.draftId);
      }
      return;
    }
    await drafts.cancelQueuedSend(draft.draftId);
    throw UnsupportedError('Delayed send is supported on Android and iOS only');
  }

  Future<bool> undo(String draftId) async {
    await _scheduler.cancelDelayedSend(draftId);
    _pending.remove(draftId)?.timer?.cancel();
    return drafts.cancelQueuedSend(draftId);
  }

  /// After an iOS process restart, do not send a queued message from a
  /// background callback. Restore it as a normal draft for user review.
  Future<void> restoreInterruptedIosSends(
    List<MailAccount> accounts, {
    Future<void> Function(String draftId)? onInterrupted,
  }) async {
    if (!Platform.isIOS) return;
    for (final account in accounts) {
      final accountDrafts = await drafts.observeDrafts(account.accountId).first;
      for (final draft in accountDrafts.where(
        (draft) => draft.status == DraftStatus.queued,
      )) {
        await drafts.cancelQueuedSend(draft.draftId);
        await onInterrupted?.call(draft.draftId);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isIOS) return;
    if (state == AppLifecycleState.resumed) {
      for (final draftId in _pending.keys.toList()) {
        _arm(draftId);
      }
    } else {
      for (final pending in _pending.values) {
        pending.timer?.cancel();
        pending.timer = null;
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final pending in _pending.values) {
      pending.timer?.cancel();
    }
    _pending.clear();
  }

  void _arm(String draftId) {
    final pending = _pending[draftId];
    if (pending == null) return;
    pending.timer?.cancel();
    final remaining = pending.deadline.difference(DateTime.now());
    pending.timer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => unawaited(_send(draftId)),
    );
  }

  Future<void> _send(String draftId) async {
    final pending = _pending.remove(draftId);
    if (pending == null) return;
    try {
      await sender.send(pending.account, pending.message);
    } on Object {
      // Repository send state is durable; retain a recoverable draft on errors.
    }
  }
}

final class _PendingSend {
  _PendingSend({
    required this.account,
    required this.message,
    required this.deadline,
  });

  final MailAccount account;
  final OutgoingMail message;
  final DateTime deadline;
  Timer? timer;
}
