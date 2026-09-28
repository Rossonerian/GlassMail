import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';
import 'package:glassmail/main.dart';
import 'package:glassmail/features/inbox/inbox_screen.dart';
import 'package:glassmail/design/glass_mail_theme.dart';
import 'package:glassmail/app/user_preferences.dart';
import 'package:glassmail/app/workflow_store.dart';
import 'package:glassmail/app/app_shortcuts.dart';

void main() {
  testWidgets('renders the sample Inbox with accessible glass navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GlassMailFlutterApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('Maya Chen'), findsOneWidget);
    expect(find.text('A little weekend plan?'), findsOneWidget);
    expect(find.byTooltip('Search mail'), findsOneWidget);
    expect(find.byTooltip('Glass Lab'), findsOneWidget);
    expect(find.bySemanticsLabel('Inbox').last, findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.byKey(const ValueKey('mail-dock-expanded')), findsOneWidget);

    await tester.dragFrom(const Offset(200, 200), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-dock-compact')), findsOneWidget);

    await tester.dragFrom(const Offset(200, 200), const Offset(0, 90));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-dock-expanded')), findsOneWidget);

    await tester.tap(find.byTooltip('Glass Lab'));
    await tester.pumpAndSettle();
    expect(find.text('A small, bounded glass preview'), findsOneWidget);
    expect(find.text('Reduce transparency'), findsOneWidget);
    expect(find.textContaining('Raster ·'), findsOneWidget);
  });

  testWidgets('launcher Search shortcut opens the Search destination', (
    WidgetTester tester,
  ) async {
    final repository = _MemoryMailRepository();
    addTearDown(repository.dispose);
    addTearDown(() => appShortcutController.value = null);

    await tester.pumpWidget(GlassMailFlutterApp(repository: repository));
    await tester.pumpAndSettle();
    appShortcutController.value = appShortcutSearch;
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Inbox keeps primary navigation reachable at 200% text scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewData = MediaQueryData.fromView(
      tester.view,
    ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: glassMailTheme(Brightness.light),
        home: Scaffold(
          body: MediaQuery(data: viewData, child: const InboxScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Search mail'), findsOneWidget);
    expect(find.byTooltip('Glass Lab'), findsOneWidget);
    expect(find.bySemanticsLabel('Inbox'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved compose draft can be reopened with its content', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMailRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(GlassMailFlutterApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Compose message'));
    await tester.pumpAndSettle();
    await tester.enterText(_textField('To'), 'reader@example.test');
    await tester.enterText(_textField('Subject'), 'Saved from Flutter');
    await tester.enterText(_bodyField(), 'Draft body');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved drafts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved from Flutter'));
    await tester.pumpAndSettle();

    expect(
      (tester.widget(_textField('To')) as TextField).controller!.text,
      'reader@example.test',
    );
    expect(
      (tester.widget(_textField('Subject')) as TextField).controller!.text,
      'Saved from Flutter',
    );
    expect(
      (tester.widget(_bodyField()) as TextField).controller!.text,
      'Draft body',
    );
  });

  testWidgets('reader offers reply, reply all, forward and archive actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMailRepository()
      ..inboxes['account-a'] = [
        MailListItem(
          messageId: 'gmail:account-a:message-1',
          threadId: 'thread-1',
          sender: 'Ada <ada@example.test>',
          subject: 'Reading phase one',
          preview: 'A short message',
          sentAtEpochMillis: 1000,
          unread: false,
          starred: false,
          labels: const [],
          hasAttachment: false,
        ),
      ]
      ..thread = [
        MailMessage(
          messageId: 'gmail:account-a:message-1',
          threadId: 'thread-1',
          sender: 'Ada <ada@example.test>',
          subject: 'Reading phase one',
          preview: 'A short message',
          body: 'A short message',
          html: false,
          sentAtEpochMillis: 1000,
          unread: false,
          starred: false,
          labels: const [],
        ),
      ];
    addTearDown(repository.dispose);

    await tester.pumpWidget(GlassMailFlutterApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading phase one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Message actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();

    expect(
      (tester.widget(_textField('Subject')) as TextField).controller!.text,
      'Fwd: Reading phase one',
    );
    expect(
      (tester.widget(_bodyField()) as TextField).controller!.text,
      contains('— Forwarded message —'),
    );
  });

  testWidgets('account menu switches to a unified inbox', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMailRepository()
      ..accounts.add(
        const MailAccount(
          accountId: 'account-b',
          email: 'second@example.test',
          syncState: 'READY',
        ),
      )
      ..inboxes['account-a'] = [
        _listItem('gmail:account-a:one', 'First account mail'),
      ]
      ..inboxes['account-b'] = [
        _listItem('gmail:account-b:two', 'Second account mail'),
      ];
    addTearDown(repository.dispose);

    await tester.pumpWidget(GlassMailFlutterApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Accounts and more options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All accounts'));
    await tester.pumpAndSettle();

    expect(find.text('All accounts · Primary'), findsOneWidget);
    expect(find.text('First account mail'), findsOneWidget);
    expect(find.text('Second account mail'), findsOneWidget);
  });

  testWidgets('Trash keeps locally muted mail visible and stars its mailbox', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMailRepository()
      ..trashItems = [_listItem('gmail:account-a:trash-1', 'Trashed message')];
    final workflowStore = MailWorkflowStore.memory();
    await workflowStore.setSenderMuted(
      'Sender <Trashed message@example.test>',
      true,
    );
    addTearDown(repository.dispose);
    addTearDown(workflowStore.dispose);

    await tester.pumpWidget(
      GlassMailFlutterApp(repository: repository, workflowStore: workflowStore),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trash').last);
    await tester.pumpAndSettle();

    expect(find.text('Trashed message'), findsOneWidget);
    await tester.tap(find.byTooltip('Star message'));
    await tester.pumpAndSettle();

    final starMutation = repository.mutations.whereType<StarMutation>().single;
    expect(starMutation.mailboxId, 'account-a:[Gmail]/Trash');
    expect(starMutation.starred, isTrue);
  });

  testWidgets('appearance settings update the active app preferences', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMailRepository();
    final preferences = MailUserPreferences.memory();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      GlassMailFlutterApp(repository: repository, preferences: preferences),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    final reduceTransparency = find.ancestor(
      of: find.text('Reduce transparency'),
      matching: find.byType(SwitchListTile),
    );
    await tester.tap(reduceTransparency);
    await tester.pumpAndSettle();

    expect(preferences.themeMode, ThemeMode.dark);
    expect(preferences.reduceTransparency, isTrue);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Reduce transparency'), findsOneWidget);
  });

  testWidgets('account settings replace credentials and trigger a sync', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMailRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(GlassMailFlutterApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update app password'));
    await tester.pumpAndSettle();
    await tester.enterText(
      _textField('Google app password'),
      'replacement-test-secret',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.updatedCredentialAccountId, 'account-a');
    expect(repository.updatedCredential, 'replacement-test-secret');
    expect(repository.submittedCredential, everyElement(0));
    expect(repository.synchronizedAccounts, contains('account-a'));
    expect(find.text('Password updated. Syncing account…'), findsOneWidget);
  });

  testWidgets('snoozed messages leave the inbox and appear in Snoozed', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMailRepository()
      ..inboxes['account-a'] = [
        _listItem('gmail:account-a:snooze', 'Snooze me'),
      ]
      ..thread = [
        MailMessage(
          messageId: 'gmail:account-a:snooze',
          threadId: 'thread-snooze',
          sender: 'Ada <ada@example.test>',
          subject: 'Snooze me',
          preview: 'Reminder body',
          body: 'Reminder body',
          html: false,
          sentAtEpochMillis: 1000,
          unread: false,
          starred: false,
          labels: const [],
        ),
      ];
    final workflows = MailWorkflowStore.memory();
    addTearDown(repository.dispose);
    addTearDown(workflows.dispose);

    await tester.pumpWidget(
      GlassMailFlutterApp(repository: repository, workflowStore: workflows),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snooze me'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Message actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snooze 1 day'));
    await tester.pumpAndSettle();
    expect(workflows.isSnoozed('gmail:account-a:snooze'), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Snooze me'), findsNothing);
    await tester.tap(find.byTooltip('Filter categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snoozed'));
    await tester.pumpAndSettle();
    expect(find.text('Snooze me'), findsOneWidget);
  });

  testWidgets('mail links need confirmation before external launch', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMailRepository()
      ..inboxes['account-a'] = [
        _listItem('gmail:account-a:link', 'Check this link'),
      ]
      ..thread = [
        MailMessage(
          messageId: 'gmail:account-a:link',
          threadId: null,
          sender: 'Ada <ada@example.test>',
          subject: 'Check this link',
          preview: 'https://example.test/path',
          body: 'Visit https://example.test/path.',
          html: false,
          sentAtEpochMillis: 1000,
          unread: false,
          starred: false,
          labels: const [],
        ),
      ];
    addTearDown(repository.dispose);

    await tester.pumpWidget(GlassMailFlutterApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check this link'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('example.test').last);
    await tester.pumpAndSettle();
    expect(find.text('Open external link?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Open external link?'), findsNothing);

    await tester.tap(find.byTooltip('Preview link'));
    await tester.pumpAndSettle();
    expect(find.text('Fetch link preview?'), findsOneWidget);
    expect(find.textContaining('site can see your IP address'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Fetching limited page metadata…'), findsNothing);
  });
}

MailListItem _listItem(String id, String subject) => MailListItem(
  messageId: id,
  threadId: null,
  sender: 'Sender <$subject@example.test>',
  subject: subject,
  preview: 'Message preview',
  sentAtEpochMillis: 1000,
  unread: false,
  starred: false,
  labels: const [],
  hasAttachment: false,
);

Finder _textField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Finder _bodyField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.hintText == 'Write your message',
);

final class _MemoryMailRepository extends Fake
    implements
        MailRepository,
        DraftRepository,
        MailSender,
        TrashMailboxRepository {
  final accounts = <MailAccount>[
    const MailAccount(
      accountId: 'account-a',
      email: 'owner@example.test',
      syncState: 'READY',
    ),
  ];
  final inboxes = <String, List<MailListItem>>{};
  List<MailListItem> trashItems = const [];
  List<MailMessage> thread = const [];
  final mutations = <MailMutation>[];
  final _drafts = <MailDraft>[];
  final _draftEvents = StreamController<List<MailDraft>>.broadcast();
  final synchronizedAccounts = <String>[];
  String? updatedCredentialAccountId;
  String? updatedCredential;
  Uint8List submittedCredential = Uint8List(0);

  @override
  Stream<List<MailAccount>> observeAccounts() => Stream.value(accounts);

  @override
  Stream<List<MailListItem>> observeInbox(String accountId) =>
      Stream.value(inboxes[accountId] ?? const []);

  @override
  Stream<List<MailListItem>> observeInboxCategory(
    String accountId,
    String category,
  ) => observeInbox(accountId);

  @override
  Stream<List<MailListItem>> observeUnifiedInbox(
    List<String> accountIds,
    String category,
  ) => Stream.value([
    for (final id in accountIds) ...inboxes[id] ?? const <MailListItem>[],
  ]);

  @override
  Stream<List<MailListItem>> observeSent(String accountId) =>
      Stream.value(const []);

  @override
  Stream<List<MailListItem>> observeTrash(String accountId) =>
      Stream.value(trashItems);

  @override
  Future<String?> trashMailboxId(String accountId) async =>
      '$accountId:[Gmail]/Trash';

  @override
  Stream<List<MailMessage>> observeThread(String messageId) =>
      Stream.value(thread);

  @override
  Stream<List<MailMessage>> observeThreadInMailbox(
    String messageId,
    String mailboxId,
  ) => observeThread(messageId);

  @override
  Stream<List<MailListItem>> search(String accountId, String query) =>
      Stream.value(const []);

  @override
  Stream<List<MailListItem>> searchUnified(
    List<String> accountIds,
    String query,
  ) => Stream.value(const []);

  @override
  Future<void> applyMutation(MailMutation mutation) async {
    mutations.add(mutation);
  }

  @override
  Future<bool> undoPendingArchive(String messageId) async => true;

  @override
  Future<MailSyncResult> synchronize(String accountId) async {
    synchronizedAccounts.add(accountId);
    return const MailSyncSuccess(
      messageCount: 0,
      gmailExtensionsEnabled: false,
    );
  }

  @override
  Future<void> updateCredential(
    String accountId,
    List<int> credentialUtf8,
  ) async {
    updatedCredentialAccountId = accountId;
    updatedCredential = utf8.decode(credentialUtf8);
    submittedCredential = credentialUtf8 as Uint8List;
    credentialUtf8.fillRange(0, credentialUtf8.length, 0);
  }

  @override
  Stream<MailCacheSettings> observeCacheSettings(String accountId) =>
      Stream.value(const MailCacheSettings());

  @override
  Stream<StorageQuota?> observeStorageQuota(String accountId) =>
      Stream.value(null);

  @override
  Stream<List<MailDraft>> observeDrafts(String accountId) =>
      Stream.multi((sink) {
        sink.add(List.unmodifiable(_drafts));
        final subscription = _draftEvents.stream.listen(sink.add);
        sink.onCancel = subscription.cancel;
      });

  @override
  Future<void> saveDraft(MailDraft draft) async {
    _drafts.removeWhere((item) => item.draftId == draft.draftId);
    _drafts.add(draft);
    _draftEvents.add(List.unmodifiable(_drafts));
  }

  @override
  Future<SendMailResult> send(MailAccount account, OutgoingMail mail) async =>
      const MailSent();

  Future<void> dispose() => _draftEvents.close();
}
