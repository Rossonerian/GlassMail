import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// App-private workflow choices used by Phase 2 UI.
/// Templates contain user-authored text; credentials are never stored here.
final class MailWorkflowStore extends ChangeNotifier
    with WidgetsBindingObserver {
  MailWorkflowStore._({
    File? persistenceFile,
    Future<void> Function(WorkflowReminder reminder)? reminderCallback,
    Future<void> Function(WorkflowReminder reminder)? scheduleReminder,
    Future<void> Function(WorkflowReminder reminder)? cancelReminder,
    bool timerEnabled = true,
  }) : _file = persistenceFile,
       onReminderDue = reminderCallback,
       onReminderScheduled = scheduleReminder,
       onReminderCanceled = cancelReminder,
       _enableReminderTimers = timerEnabled {
    WidgetsBinding.instance.addObserver(this);
  }

  factory MailWorkflowStore.memory({
    Future<void> Function(WorkflowReminder reminder)? onReminderDue,
    Future<void> Function(WorkflowReminder reminder)? onReminderScheduled,
    Future<void> Function(WorkflowReminder reminder)? onReminderCanceled,
    bool enableReminderTimers = false,
  }) => MailWorkflowStore._(
    reminderCallback: onReminderDue,
    scheduleReminder: onReminderScheduled,
    cancelReminder: onReminderCanceled,
    timerEnabled: enableReminderTimers,
  );

  final File? _file;
  final Future<void> Function(WorkflowReminder reminder)? onReminderDue;
  final Future<void> Function(WorkflowReminder reminder)? onReminderScheduled;
  final Future<void> Function(WorkflowReminder reminder)? onReminderCanceled;
  final bool _enableReminderTimers;
  final Map<String, MailTemplate> _templates = {};
  final Map<String, MailSavedView> _views = {};
  final Map<String, WorkflowReminder> _reminders = {};
  final Map<String, ScheduledMailSend> _scheduledSends = {};
  final Set<String> _mutedSenders = {};
  final Set<String> _platformScheduledReminders = {};
  final Map<String, String> _senderProfiles = {};
  Future<void> _writeTail = Future<void>.value();
  Timer? _reminderTimer;

  List<MailTemplate> get templates =>
      List.unmodifiable(_templates.values.toList()..sort(_byName));
  List<MailSavedView> get savedViews =>
      List.unmodifiable(_views.values.toList()..sort(_byName));
  List<WorkflowReminder> get reminders => List.unmodifiable(
    _reminders.values.toList()
      ..sort((a, b) => a.atEpochMillis.compareTo(b.atEpochMillis)),
  );
  List<ScheduledMailSend> get scheduledSends => List.unmodifiable(
    _scheduledSends.values.toList()
      ..sort((a, b) => a.atEpochMillis.compareTo(b.atEpochMillis)),
  );
  Set<String> get mutedSenders => Set.unmodifiable(_mutedSenders);
  Map<String, String> get senderProfiles => Map.unmodifiable(_senderProfiles);

  static Future<MailWorkflowStore> load({
    Future<void> Function(WorkflowReminder reminder)? onReminderDue,
    Future<void> Function(WorkflowReminder reminder)? onReminderScheduled,
    Future<void> Function(WorkflowReminder reminder)? onReminderCanceled,
  }) async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/mail-workflows.json');
    return openFile(
      file,
      onReminderDue: onReminderDue,
      onReminderScheduled: onReminderScheduled,
      onReminderCanceled: onReminderCanceled,
    );
  }

  static Future<MailWorkflowStore> openFile(
    File file, {
    Future<void> Function(WorkflowReminder reminder)? onReminderDue,
    Future<void> Function(WorkflowReminder reminder)? onReminderScheduled,
    Future<void> Function(WorkflowReminder reminder)? onReminderCanceled,
  }) async {
    final store = MailWorkflowStore._(
      persistenceFile: file,
      reminderCallback: onReminderDue,
      scheduleReminder: onReminderScheduled,
      cancelReminder: onReminderCanceled,
    );
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) store._read(decoded);
    } on Object {
      // A malformed preference file falls back to empty local workflows.
    }
    store._armReminderTimer();
    for (final reminder in store.activeReminders()) {
      await store._scheduleReminder(reminder);
    }
    return store;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifyDueReminders();
      _armReminderTimer();
    }
  }

  Future<void> saveTemplate(MailTemplate template) async {
    if (template.name.trim().isEmpty) {
      throw ArgumentError.value(template.name, 'name', 'Must not be blank');
    }
    _templates[template.id] = template;
    await _changed();
  }

  Future<void> removeTemplate(String id) async {
    if (_templates.remove(id) != null) await _changed();
  }

  Future<void> saveView(MailSavedView view) async {
    if (view.name.trim().isEmpty || view.query.trim().isEmpty) {
      throw ArgumentError('A saved view needs a name and search query');
    }
    _views[view.id] = view;
    await _changed();
  }

  Future<void> removeView(String id) async {
    if (_views.remove(id) != null) await _changed();
  }

  Future<void> setReminder(WorkflowReminder reminder) async {
    _reminders[reminder.key] = reminder;
    await _changed();
    if (reminder.atEpochMillis > DateTime.now().millisecondsSinceEpoch) {
      await _scheduleReminder(reminder);
    }
    _armReminderTimer();
  }

  Future<void> clearReminder(String messageId, String kind) async {
    if (_reminders.remove('$kind:$messageId') != null) {
      await _changed();
      final reminder = WorkflowReminder(
        messageId: messageId,
        kind: kind,
        atEpochMillis: 0,
      );
      _platformScheduledReminders.remove(reminder.key);
      await _cancelReminder(reminder);
      _armReminderTimer();
    }
  }

  Future<void> acknowledgeReminder(String reminderKey) async {
    final reminder = _reminders[reminderKey];
    if (reminder == null || reminder.notified) return;
    _reminders[reminderKey] = reminder.copyWith(notified: true);
    _platformScheduledReminders.remove(reminderKey);
    await _changed();
  }

  Future<void> _scheduleReminder(WorkflowReminder reminder) async {
    final callback = onReminderScheduled;
    if (callback == null) return;
    try {
      await callback(reminder);
      _platformScheduledReminders.add(reminder.key);
    } on Object {
      // Keep the local timer as a foreground fallback if OS scheduling fails.
    }
  }

  Future<void> _cancelReminder(WorkflowReminder reminder) async {
    final callback = onReminderCanceled;
    if (callback == null) return;
    try {
      await callback(reminder);
    } on Object {
      // A stale generic notification is less harmful than changing mail state.
    }
  }

  Future<void> saveScheduledSend(ScheduledMailSend send) async {
    _scheduledSends[send.draftId] = send;
    await _changed();
  }

  Future<void> removeScheduledSend(String draftId) async {
    if (_scheduledSends.remove(draftId) != null) await _changed();
  }

  bool isSnoozed(String messageId, {DateTime? now}) {
    final reminder = _reminders['snooze:$messageId'];
    return reminder != null &&
        reminder.atEpochMillis > (now ?? DateTime.now()).millisecondsSinceEpoch;
  }

  void _armReminderTimer() {
    _reminderTimer?.cancel();
    if (!_enableReminderTimers) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final futureReminders = _reminders.values
        .where((item) => item.atEpochMillis > now)
        .toList(growable: false);
    if (futureReminders.isEmpty) {
      _notifyDueReminders();
      return;
    }
    final earliest = futureReminders
        .map((item) => item.atEpochMillis)
        .reduce((a, b) => a < b ? a : b);
    _reminderTimer = Timer(Duration(milliseconds: earliest - now), () {
      _notifyDueReminders();
      _armReminderTimer();
    });
  }

  void _notifyDueReminders() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = _reminders.values
        .where((item) => item.atEpochMillis <= now && !item.notified)
        .toList(growable: false);
    if (due.isEmpty) return;
    for (final item in due) {
      _reminders[item.key] = item.copyWith(notified: true);
    }
    unawaited(_changed());
    for (final item in due) {
      if (_platformScheduledReminders.remove(item.key)) continue;
      final callback = onReminderDue;
      if (callback != null) unawaited(_sendReminder(callback, item));
    }
  }

  Future<void> _sendReminder(
    Future<void> Function(WorkflowReminder) callback,
    WorkflowReminder reminder,
  ) async {
    try {
      await callback(reminder);
    } on Object {
      // Keep in-app reminder state even if the OS notification is unavailable.
    }
  }

  List<WorkflowReminder> activeReminders({DateTime? now}) {
    final epoch = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return reminders
        .where((item) => !item.notified && item.atEpochMillis > epoch)
        .toList();
  }

  bool isSenderMuted(String sender) =>
      _mutedSenders.contains(_senderKey(sender));

  Future<void> setSenderMuted(String sender, bool muted) async {
    final key = _senderKey(sender);
    if (key.isEmpty) return;
    final changed = muted ? _mutedSenders.add(key) : _mutedSenders.remove(key);
    if (changed) await _changed();
  }

  String? senderProfile(String sender) => _senderProfiles[_senderKey(sender)];

  Future<void> saveSenderProfile(String sender, String displayName) async {
    final key = _senderKey(sender);
    final value = displayName.trim();
    if (key.isEmpty || value.isEmpty) {
      throw ArgumentError('A sender address and display name are required');
    }
    _senderProfiles[key] = value;
    await _changed();
  }

  Future<void> removeSenderProfile(String sender) async {
    if (_senderProfiles.remove(_senderKey(sender)) != null) await _changed();
  }

  Map<String, Object?> exportBackupState() => {
    'version': 1,
    'templates': _templates.values.map((item) => item.toJson()).toList(),
    'views': _views.values.map((item) => item.toJson()).toList(),
    'reminders': _reminders.values.map((item) => item.toJson()).toList(),
    'mutedSenders': _mutedSenders.toList(),
    'senderProfiles': Map<String, String>.from(_senderProfiles),
  };

  Future<void> restoreBackupState(Map<String, dynamic> values) async {
    if (values['version'] != 1 ||
        values['templates'] is! List ||
        values['views'] is! List ||
        values['reminders'] is! List ||
        values['mutedSenders'] is! List ||
        values['senderProfiles'] is! Map<String, dynamic>) {
      throw const FormatException('Workflow backup data is invalid.');
    }
    _templates.clear();
    _views.clear();
    _reminders.clear();
    _scheduledSends.clear();
    _mutedSenders.clear();
    _senderProfiles.clear();
    _read(values);
    await _changed();
    for (final reminder in activeReminders()) {
      await _scheduleReminder(reminder);
    }
  }

  void _read(Map<String, dynamic> values) {
    for (final value in values['templates'] as List? ?? const []) {
      if (value is Map<String, dynamic>) {
        try {
          final item = MailTemplate.fromJson(value);
          _templates[item.id] = item;
        } on Object {
          continue;
        }
      }
    }
    for (final value in values['views'] as List? ?? const []) {
      if (value is Map<String, dynamic>) {
        try {
          final item = MailSavedView.fromJson(value);
          _views[item.id] = item;
        } on Object {
          continue;
        }
      }
    }
    for (final value in values['reminders'] as List? ?? const []) {
      if (value is Map<String, dynamic>) {
        try {
          final item = WorkflowReminder.fromJson(value);
          _reminders[item.key] = item;
        } on Object {
          continue;
        }
      }
    }
    for (final value in values['scheduledSends'] as List? ?? const []) {
      if (value is Map<String, dynamic>) {
        try {
          final item = ScheduledMailSend.fromJson(value);
          _scheduledSends[item.draftId] = item;
        } on Object {
          continue;
        }
      }
    }
    _mutedSenders.addAll(
      (values['mutedSenders'] as List? ?? const []).whereType<String>(),
    );
    final profiles = values['senderProfiles'];
    if (profiles is Map<String, dynamic>) {
      for (final entry in profiles.entries) {
        if (entry.value is String) {
          _senderProfiles[entry.key] = entry.value! as String;
        }
      }
    }
  }

  Future<void> _changed() async {
    notifyListeners();
    final file = _file;
    if (file == null) return;
    final state = jsonEncode({
      'version': 1,
      'templates': _templates.values.map((item) => item.toJson()).toList(),
      'views': _views.values.map((item) => item.toJson()).toList(),
      'reminders': _reminders.values.map((item) => item.toJson()).toList(),
      'scheduledSends': _scheduledSends.values
          .map((item) => item.toJson())
          .toList(),
      'mutedSenders': _mutedSenders.toList(),
      'senderProfiles': _senderProfiles,
    });
    final pending = _writeTail.then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.part');
      await temporary.writeAsString(state, flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    });
    _writeTail = pending.catchError((Object _) {});
    await pending;
  }
}

final class MailTemplate {
  const MailTemplate({
    required this.id,
    required this.name,
    this.subject = '',
    this.body = '',
  });

  final String id;
  final String name;
  final String subject;
  final String body;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'subject': subject,
    'body': body,
  };

  factory MailTemplate.fromJson(Map<String, dynamic> json) => MailTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    subject: json['subject'] as String? ?? '',
    body: json['body'] as String? ?? '',
  );
}

final class MailSavedView {
  const MailSavedView({
    required this.id,
    required this.name,
    required this.query,
  });

  final String id;
  final String name;
  final String query;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'query': query};

  factory MailSavedView.fromJson(Map<String, dynamic> json) => MailSavedView(
    id: json['id'] as String,
    name: json['name'] as String,
    query: json['query'] as String,
  );
}

final class WorkflowReminder {
  const WorkflowReminder({
    required this.messageId,
    required this.kind,
    required this.atEpochMillis,
    this.notified = false,
  });

  final String messageId;
  final String kind;
  final int atEpochMillis;
  final bool notified;
  String get key => '$kind:$messageId';

  WorkflowReminder copyWith({bool? notified}) => WorkflowReminder(
    messageId: messageId,
    kind: kind,
    atEpochMillis: atEpochMillis,
    notified: notified ?? this.notified,
  );

  Map<String, Object?> toJson() => {
    'messageId': messageId,
    'kind': kind,
    'atEpochMillis': atEpochMillis,
    'notified': notified,
  };

  factory WorkflowReminder.fromJson(Map<String, dynamic> json) =>
      WorkflowReminder(
        messageId: json['messageId'] as String,
        kind: json['kind'] as String,
        atEpochMillis: json['atEpochMillis'] as int,
        notified: json['notified'] as bool? ?? false,
      );
}

final class ScheduledMailSend {
  const ScheduledMailSend({
    required this.draftId,
    required this.accountId,
    required this.atEpochMillis,
  });

  final String draftId;
  final String accountId;
  final int atEpochMillis;

  Map<String, Object?> toJson() => {
    'draftId': draftId,
    'accountId': accountId,
    'atEpochMillis': atEpochMillis,
  };

  factory ScheduledMailSend.fromJson(Map<String, dynamic> json) =>
      ScheduledMailSend(
        draftId: json['draftId'] as String,
        accountId: json['accountId'] as String,
        atEpochMillis: json['atEpochMillis'] as int,
      );
}

int _byName(dynamic left, dynamic right) => (left.name as String)
    .toLowerCase()
    .compareTo((right.name as String).toLowerCase());

String _senderKey(String raw) {
  final match = RegExp(r'<([^>]+)>').firstMatch(raw);
  final candidate = (match?.group(1) ?? raw).trim().toLowerCase();
  return candidate.contains('@') ? candidate : '';
}
