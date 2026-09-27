import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail/app/workflow_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists private workflow choices and template content', () async {
    final directory = await Directory.systemTemp.createTemp(
      'glassmail-workflows-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/workflows.json');
    final store = await MailWorkflowStore.openFile(file);
    await store.saveTemplate(
      const MailTemplate(
        id: 'template-1',
        name: 'Status update',
        subject: 'Project status',
        body: 'Here is the update.',
      ),
    );
    await store.saveView(
      const MailSavedView(id: 'view-1', name: 'Receipts', query: 'receipt'),
    );
    await store.setReminder(
      WorkflowReminder(
        messageId: 'message-1',
        kind: 'snooze',
        atEpochMillis: DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
      ),
    );
    await store.saveScheduledSend(
      ScheduledMailSend(
        draftId: 'draft-1',
        accountId: 'account-1',
        atEpochMillis: DateTime.now()
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      ),
    );
    await store.setSenderMuted('Ada <ada@example.test>', true);
    await store.saveSenderProfile('Ada <ada@example.test>', 'Ada');
    store.dispose();

    WorkflowReminder? scheduledOnLoad;
    WorkflowReminder? canceled;
    final reopened = await MailWorkflowStore.openFile(
      file,
      onReminderScheduled: (reminder) async => scheduledOnLoad = reminder,
      onReminderCanceled: (reminder) async => canceled = reminder,
    );
    addTearDown(reopened.dispose);
    expect(reopened.templates.single.name, 'Status update');
    expect(reopened.savedViews.single.query, 'receipt');
    expect(reopened.isSnoozed('message-1'), isTrue);
    expect(reopened.scheduledSends.single.draftId, 'draft-1');
    expect(reopened.isSenderMuted('ada@example.test'), isTrue);
    expect(reopened.senderProfile('Ada <ada@example.test>'), 'Ada');
    expect(scheduledOnLoad?.messageId, 'message-1');
    await reopened.clearReminder('message-1', 'snooze');
    expect(canceled?.messageId, 'message-1');
    final persisted = await file.readAsString();
    expect(persisted, contains('Here is the update.'));
    expect(persisted, isNot(contains('throwaway-password')));
  });

  test(
    'due follow-up reminders notify once and retain in-app history',
    () async {
      final notified = Completer<WorkflowReminder>();
      final store = MailWorkflowStore.memory(
        enableReminderTimers: true,
        onReminderScheduled: (_) async {
          throw StateError('simulated platform scheduling failure');
        },
        onReminderDue: (reminder) async {
          if (!notified.isCompleted) notified.complete(reminder);
        },
      );
      addTearDown(store.dispose);
      final reminder = WorkflowReminder(
        messageId: 'message-2',
        kind: 'followup',
        atEpochMillis: DateTime.now()
            .add(const Duration(milliseconds: 30))
            .millisecondsSinceEpoch,
      );
      await store.setReminder(reminder);

      final delivered = await notified.future.timeout(
        const Duration(seconds: 1),
      );
      expect(delivered.messageId, 'message-2');
      expect(store.reminders.single.notified, isTrue);
    },
  );
}
