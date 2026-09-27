import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app_shortcuts.dart';
import 'app/mail_services.dart';
import 'app/user_preferences.dart';
import 'app/workflow_store.dart';
import 'design/glass_mail_glass.dart';
import 'design/glass_mail_theme.dart';
import 'features/routes/mail_workspace_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'platform/account_sync_scheduler.dart';
import 'platform/background_mail_sync.dart';
import 'platform/delayed_send_coordinator.dart';
import 'platform/mail_notifications.dart';
import 'platform/inbox_widget_bridge.dart';

final mailRepositoryProvider = Provider<MailRepository?>((ref) => null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeAppShortcuts();
  await Workmanager().initialize(glassMailBackgroundDispatcher);
  final notifications = MailNotifications();
  await notifications.initialize(
    onMessageTap: (messageId) => notificationRouteController.value = messageId,
  );
  await _scheduleExistingAccounts();
  final repository = await createMailRepository();
  unawaited(InboxWidgetBridge().start(repository));
  final preferences = await MailUserPreferences.load();
  final workflowStore = await MailWorkflowStore.load(
    onReminderDue: notifications.showWorkflowReminder,
    onReminderScheduled: notifications.scheduleWorkflowReminder,
    onReminderCanceled: notifications.cancelWorkflowReminder,
  );
  void acknowledgeTappedReminder() {
    final key = workflowReminderRouteController.value;
    if (key == null) return;
    workflowReminderRouteController.value = null;
    unawaited(workflowStore.acknowledgeReminder(key));
  }

  workflowReminderRouteController.addListener(acknowledgeTappedReminder);
  acknowledgeTappedReminder();
  final delayedSendCoordinator = DelayedSendCoordinator(
    drafts: repository,
    sender: repository,
  );
  await delayedSendCoordinator.restoreInterruptedIosSends(
    await repository.observeAccounts().first,
    onInterrupted: workflowStore.removeScheduledSend,
  );
  runApp(
    GlassMailFlutterApp(
      repository: repository,
      preferences: preferences,
      workflowStore: workflowStore,
      delayedSendCoordinator: delayedSendCoordinator,
    ),
  );
}

Future<void> _initializeAppShortcuts() async {
  const shortcuts = QuickActions();
  shortcuts.initialize((type) => appShortcutController.value = type);
  await shortcuts.setShortcutItems(const [
    ShortcutItem(type: appShortcutCompose, localizedTitle: 'Compose'),
    ShortcutItem(type: appShortcutInbox, localizedTitle: 'Inbox'),
    ShortcutItem(type: appShortcutSearch, localizedTitle: 'Search'),
  ]);
}

Future<void> _scheduleExistingAccounts() async {
  final database = GlassMailDatabase();
  try {
    final accountIds = (await database.watchAccounts().first).map(
      (account) => account.accountId,
    );
    final scheduler = AccountSyncScheduler();
    if (accountIds.isEmpty) return;
    for (final accountId in accountIds) {
      await scheduler.scheduleAccount(accountId);
    }
    await scheduler.startIdleService();
  } finally {
    await database.close();
  }
}

class GlassMailFlutterApp extends StatelessWidget {
  const GlassMailFlutterApp({
    super.key,
    this.repository,
    this.preferences,
    this.workflowStore,
    this.delayedSendCoordinator,
  });

  final MailRepository? repository;
  final MailUserPreferences? preferences;
  final MailWorkflowStore? workflowStore;
  final DelayedSendCoordinator? delayedSendCoordinator;

  static final _memoryPreferences = MailUserPreferences.memory();
  static final _memoryWorkflowStore = MailWorkflowStore.memory();

  @override
  Widget build(BuildContext context) {
    final appPreferences = preferences ?? _memoryPreferences;
    final workflows = workflowStore ?? _memoryWorkflowStore;
    return ProviderScope(
      overrides: repository == null
          ? const []
          : [mailRepositoryProvider.overrideWith((ref) => repository!)],
      child: AnimatedBuilder(
        animation: appPreferences,
        builder: (context, _) => MaterialApp(
          title: 'GlassMail',
          theme: glassMailTheme(Brightness.light),
          darkTheme: glassMailTheme(Brightness.dark),
          themeMode: appPreferences.themeMode,
          restorationScopeId: 'glassmail',
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MailGlassAccessibility(
              glassTier: appPreferences.glassTier,
              reduceTransparency: appPreferences.reduceTransparency,
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  disableAnimations:
                      mediaQuery.disableAnimations ||
                      appPreferences.reduceMotion,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: _AppEntry(
            preferences: appPreferences,
            workflowStore: workflows,
            delayedSendCoordinator: delayedSendCoordinator,
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class _AppEntry extends ConsumerWidget {
  const _AppEntry({
    required this.preferences,
    required this.workflowStore,
    required this.delayedSendCoordinator,
  });

  final MailUserPreferences preferences;
  final MailWorkflowStore workflowStore;
  final DelayedSendCoordinator? delayedSendCoordinator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(mailRepositoryProvider);
    if (repository == null) return const Material(child: InboxScreen());
    return MailWorkspaceScreen(
      repository: repository,
      preferences: preferences,
      workflowStore: workflowStore,
      delayedSendCoordinator: delayedSendCoordinator,
    );
  }
}
