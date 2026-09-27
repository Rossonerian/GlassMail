import 'dart:async';
import 'dart:io';

import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';
import 'package:home_widget/home_widget.dart';

/// Sends only aggregate unread counts to native home-screen widgets.
final class InboxWidgetBridge {
  static const appGroupId = 'group.com.glassmail.dev.glassmail.shared';
  static const androidProvider = 'GlassMailInboxWidgetProvider';
  static const qualifiedAndroidProvider =
      'com.glassmail.dev.glassmail.GlassMailInboxWidgetProvider';
  static const iOSWidgetKind = 'GlassMailInboxWidget';

  StreamSubscription<List<MailAccount>>? _accountsSubscription;
  StreamSubscription<Map<String, int>>? _countsSubscription;
  Future<void> _accountUpdateTail = Future<void>.value();

  Future<void> start(MailRepository repository) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (Platform.isIOS) await HomeWidget.setAppGroupId(appGroupId);
    await _publishCount(0);
    _accountsSubscription = repository.observeAccounts().listen((accounts) {
      _accountUpdateTail = _accountUpdateTail
          .then((_) => _replaceAccounts(repository, accounts))
          .catchError((Object _) {});
    });
  }

  Future<void> dispose() async {
    await _accountsSubscription?.cancel();
    await _countsSubscription?.cancel();
  }

  Future<void> _replaceAccounts(
    MailRepository repository,
    List<MailAccount> accounts,
  ) async {
    await _countsSubscription?.cancel();
    _countsSubscription = null;
    if (accounts.isEmpty) {
      await _publishCount(0);
      return;
    }
    _countsSubscription = repository
        .observeUnifiedCategoryUnreadCounts(
          accounts.map((account) => account.accountId).toList(growable: false),
        )
        .listen((counts) {
          final unread = counts.values.fold<int>(
            0,
            (sum, count) => sum + count,
          );
          unawaited(_publishCount(unread));
        });
  }

  Future<void> _publishCount(int unreadCount) async {
    final count = unreadCount.clamp(0, 99999).toInt();
    if (Platform.isIOS) {
      await HomeWidget.saveWidgetData<int>(
        'unreadCount',
        count,
        appGroupId: appGroupId,
      );
      await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
    } else if (Platform.isAndroid) {
      await HomeWidget.saveWidgetData<int>('unreadCount', count);
      await HomeWidget.updateWidget(
        androidName: androidProvider,
        qualifiedAndroidName: qualifiedAndroidProvider,
      );
    }
  }
}
