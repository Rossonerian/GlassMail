import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../app/user_preferences.dart';
import '../app/workflow_store.dart';

final workflowReminderRouteController = ValueNotifier<String?>(null);

/// Local notifications emitted only for mail discovered after sync baseline.
/// Permission is deliberately requested by an explicit settings/onboarding UI.
final class MailNotifications {
  MailNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static Future<void>? _timezoneInitialization;

  Future<void> initialize({
    void Function(String messageId)? onMessageTap,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        _dispatchPayload(response.payload, onMessageTap);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _dispatchPayload(launchPayload, onMessageTap);
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'glassmail.new_mail',
            'New mail',
            description: 'Notifications for newly synchronized email',
            importance: Importance.high,
          ),
        );
    await _initializeTimezone();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'glassmail.reminders',
            'Mail reminders',
            description: 'Snooze and follow-up reminders',
            importance: Importance.defaultImportance,
          ),
        );
  }

  Future<bool?> requestPermission() async {
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return android ?? ios;
  }

  Future<void> showNewMessages(List<MailListItem> messages) async {
    final showPreviews =
        await MailUserPreferences.readShowNotificationPreviews();
    for (final message in messages) {
      final sender = message.sender.trim();
      final subject = message.subject.trim();
      await _plugin.show(
        id: _notificationId(message.messageId),
        title: showPreviews && sender.isNotEmpty ? sender : 'New mail',
        body: showPreviews && subject.isNotEmpty
            ? subject
            : 'You received a message',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'glassmail.new_mail',
            'New mail',
            channelDescription: 'Notifications for newly synchronized email',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
            category: AndroidNotificationCategory.email,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.messageId,
      );
    }
  }

  Future<void> showWorkflowReminder(WorkflowReminder reminder) async {
    await _plugin.show(
      id: _reminderNotificationId(reminder),
      title: _reminderTitle(reminder),
      body: _reminderBody,
      notificationDetails: _reminderDetails,
      payload: _reminderPayload(reminder),
    );
  }

  Future<void> scheduleWorkflowReminder(WorkflowReminder reminder) async {
    final dueAt = DateTime.fromMillisecondsSinceEpoch(reminder.atEpochMillis);
    if (!dueAt.isAfter(DateTime.now())) {
      await showWorkflowReminder(reminder);
      return;
    }
    await _initializeTimezone();
    await _plugin.zonedSchedule(
      id: _reminderNotificationId(reminder),
      title: _reminderTitle(reminder),
      body: _reminderBody,
      scheduledDate: tz.TZDateTime.from(dueAt, tz.local),
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _reminderPayload(reminder),
    );
  }

  Future<void> cancelWorkflowReminder(WorkflowReminder reminder) =>
      _plugin.cancel(id: _reminderNotificationId(reminder));

  Future<void> _initializeTimezone() => _timezoneInitialization ??= () async {
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } on Object {
      // UTC keeps epoch-based reminders valid if native timezone lookup fails.
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
  }();
}

const _reminderBody = 'Open GlassMail to review the message.';

const _reminderDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'glassmail.reminders',
    'Mail reminders',
    channelDescription: 'Snooze and follow-up reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    visibility: NotificationVisibility.private,
    category: AndroidNotificationCategory.email,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: false,
  ),
);

String _reminderTitle(WorkflowReminder reminder) =>
    reminder.kind == 'snooze' ? 'Snoozed mail is back' : 'Follow-up reminder';

int _reminderNotificationId(WorkflowReminder reminder) =>
    _notificationId('workflow:${reminder.kind}:${reminder.messageId}');

int _notificationId(String messageId) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(messageId)) {
    hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

void _dispatchPayload(
  String? payload,
  void Function(String messageId)? onMessageTap,
) {
  if (payload == null || payload.isEmpty) return;
  const prefix = 'workflow-reminder:';
  if (payload.startsWith(prefix)) {
    final reminderValue = payload.substring(prefix.length);
    final separator = reminderValue.indexOf(':');
    if (separator > 0 && separator < reminderValue.length - 1) {
      final kind = reminderValue.substring(0, separator);
      final messageId = reminderValue.substring(separator + 1);
      if (kind == 'snooze' || kind == 'followup') {
        workflowReminderRouteController.value = '$kind:$messageId';
        onMessageTap?.call(messageId);
        return;
      }
    }
  }
  onMessageTap?.call(payload);
}

String _reminderPayload(WorkflowReminder reminder) =>
    'workflow-reminder:${reminder.kind}:${reminder.messageId}';
