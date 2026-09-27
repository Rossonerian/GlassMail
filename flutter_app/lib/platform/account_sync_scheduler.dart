import 'dart:convert';
import 'dart:io';

import 'package:workmanager/workmanager.dart';

const accountSyncTaskName = 'glassmail.account.sync';
const accountPeriodicTaskName = 'glassmail.account.periodic';
const accountIdleTaskName = 'glassmail.account.idle';
const delayedSendTaskName = 'glassmail.delayed_send';
const iosPeriodicSyncTaskId = 'com.glassmail.dev.glassmail.periodic_sync';
const _idleWorkName = 'glassmail.mailbox.idle';

/// WorkManager owns durable Android retries; iOS refresh is app-wide and
/// opportunistic because BGTaskScheduler identifiers are registered per app.
final class AccountSyncScheduler {
  AccountSyncScheduler({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;

  Future<void> scheduleAccount(String accountId) async {
    if (accountId.isEmpty) throw ArgumentError.value(accountId, 'accountId');
    if (Platform.isIOS) {
      await _scheduleIosRefresh();
      return;
    }
    final encoded = _accountToken(accountId);
    await _workmanager.registerOneOffTask(
      _syncName(encoded),
      accountSyncTaskName,
      inputData: {'accountId': accountId},
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      tag: 'glassmail.account.sync',
    );
    await _workmanager.registerPeriodicTask(
      _periodicName(encoded),
      accountPeriodicTaskName,
      frequency: const Duration(minutes: 15),
      flexInterval: const Duration(minutes: 5),
      inputData: {'accountId': accountId},
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      tag: 'glassmail.account.periodic',
    );
    await startIdleService();
  }

  Future<void> scheduleManualRefresh(String accountId) async {
    if (Platform.isIOS) return; // Foreground/open sync is the iOS manual path.
    final encoded = _accountToken(accountId);
    await _workmanager.registerOneOffTask(
      _syncName(encoded),
      accountSyncTaskName,
      inputData: {'accountId': accountId},
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      tag: 'glassmail.account.sync',
    );
  }

  Future<void> scheduleContinuation(String accountId) async {
    if (Platform.isIOS) return;
    final encoded = _accountToken(accountId);
    await _workmanager.registerOneOffTask(
      'glassmail.account.$encoded.pages',
      accountSyncTaskName,
      inputData: {'accountId': accountId},
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
      existingWorkPolicy: ExistingWorkPolicy.update,
      tag: 'glassmail.account.sync',
    );
  }

  Future<void> scheduleDelayedSend(String draftId, Duration delay) async {
    if (Platform.isIOS) return; // iOS sends are dispatched from the foreground.
    if (draftId.isEmpty || delay.isNegative) {
      throw ArgumentError('A draft ID and non-negative delay are required');
    }
    final uniqueName = 'glassmail.outgoing.${_accountToken(draftId)}';
    await _workmanager.registerOneOffTask(
      uniqueName,
      delayedSendTaskName,
      inputData: {'draftId': draftId},
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      tag: 'glassmail.outgoing',
    );
  }

  Future<void> cancelDelayedSend(String draftId) async {
    if (Platform.isIOS) return;
    await _workmanager.cancelByUniqueName(
      'glassmail.outgoing.${_accountToken(draftId)}',
    );
  }

  Future<void> cancelAccount(String accountId) async {
    if (Platform.isIOS) return;
    final encoded = _accountToken(accountId);
    await _workmanager.cancelByUniqueName(_syncName(encoded));
    await _workmanager.cancelByUniqueName(_periodicName(encoded));
    await _workmanager.cancelByUniqueName('glassmail.account.$encoded.pages');
    if (Platform.isAndroid) {
      await _workmanager.cancelByUniqueName(_idleWorkName);
      await startIdleService(replace: true);
    }
  }

  Future<void> startIdleService({bool replace = false}) async {
    if (!Platform.isAndroid) return;
    await _workmanager.registerOneOffTask(
      _idleWorkName,
      accountIdleTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
      existingWorkPolicy: replace
          ? ExistingWorkPolicy.replace
          : ExistingWorkPolicy.keep,
      tag: 'glassmail.account.idle',
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'GlassMail is keeping mail up to date',
        notificationText: 'Secure mailbox connection is active',
        notificationChannelId: 'glassmail.background_sync',
        notificationChannelName: 'Mailbox connection',
        notificationId: 7301,
        foregroundServiceType: ForegroundServiceType.dataSync,
      ),
    );
  }

  Future<void> scheduleIosRefresh() => _scheduleIosRefresh();

  Future<void> _scheduleIosRefresh() => _workmanager.registerPeriodicTask(
    iosPeriodicSyncTaskId,
    iosPeriodicSyncTaskId,
    frequency: const Duration(hours: 24),
    initialDelay: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );

  static String _syncName(String accountToken) =>
      'glassmail.account.$accountToken.sync';

  static String _periodicName(String accountToken) =>
      'glassmail.account.$accountToken.periodic';

  static String _accountToken(String accountId) =>
      base64Url.encode(utf8.encode(accountId)).replaceAll('=', '');
}
