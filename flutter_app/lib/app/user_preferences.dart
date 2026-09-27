import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../design/glass_mail_glass.dart';

/// Small app-wide settings stay outside the mail database and never contain
/// account credentials or message content.
final class MailUserPreferences extends ChangeNotifier {
  MailUserPreferences._({
    required this._directory,
    this.themeMode = ThemeMode.system,
    this.glassTier = GlassMailTier.balanced,
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.showNotificationPreviews = false,
  });

  factory MailUserPreferences.memory() =>
      MailUserPreferences._(directory: null);

  final Directory? _directory;
  ThemeMode themeMode;
  GlassMailTier glassTier;
  bool reduceTransparency;
  bool reduceMotion;
  bool showNotificationPreviews;

  Map<String, Object?> exportBackupState() => {
    'themeMode': themeMode.name,
    'glassTier': glassTier.name,
    'reduceTransparency': reduceTransparency,
    'reduceMotion': reduceMotion,
    'showNotificationPreviews': showNotificationPreviews,
  };

  Future<void> restoreBackupState(Map<String, dynamic> values) async {
    final themeName = values['themeMode'];
    final glassTierName = values['glassTier'] ?? GlassMailTier.balanced.name;
    if (themeName is! String ||
        values['reduceTransparency'] is! bool ||
        values['reduceMotion'] is! bool ||
        values['showNotificationPreviews'] is! bool) {
      throw const FormatException('Appearance backup data is invalid.');
    }
    final restoredTheme = ThemeMode.values.firstWhere(
      (value) => value.name == themeName,
      orElse: () => throw const FormatException('Backup theme is invalid.'),
    );
    final restoredGlassTier = GlassMailTier.values.firstWhere(
      (value) => value.name == glassTierName,
      orElse: () => GlassMailTier.balanced,
    );
    await update(
      themeMode: restoredTheme,
      glassTier: restoredGlassTier,
      reduceTransparency: values['reduceTransparency']! as bool,
      reduceMotion: values['reduceMotion']! as bool,
      showNotificationPreviews: values['showNotificationPreviews']! as bool,
    );
  }

  static Future<MailUserPreferences> load() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/user-preferences.json');
    try {
      final values = jsonDecode(await file.readAsString());
      if (values is Map<String, dynamic>) {
        return MailUserPreferences._(
          directory: directory,
          themeMode: ThemeMode.values.firstWhere(
            (value) => value.name == values['themeMode'],
            orElse: () => ThemeMode.system,
          ),
          glassTier: GlassMailTier.values.firstWhere(
            (value) => value.name == values['glassTier'],
            orElse: () => GlassMailTier.balanced,
          ),
          reduceTransparency: values['reduceTransparency'] == true,
          reduceMotion: values['reduceMotion'] == true,
          showNotificationPreviews: values['showNotificationPreviews'] == true,
        );
      }
    } on Object {
      // Defaults replace malformed preferences; message and account data are separate.
    }
    return MailUserPreferences._(directory: directory);
  }

  static Future<bool> readShowNotificationPreviews() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/user-preferences.json');
      final values = jsonDecode(await file.readAsString());
      return values is Map<String, dynamic> &&
          values['showNotificationPreviews'] == true;
    } on Object {
      return false;
    }
  }

  Future<void> update({
    ThemeMode? themeMode,
    GlassMailTier? glassTier,
    bool? reduceTransparency,
    bool? reduceMotion,
    bool? showNotificationPreviews,
  }) async {
    if (themeMode != null) this.themeMode = themeMode;
    if (glassTier != null) this.glassTier = glassTier;
    if (reduceTransparency != null) {
      this.reduceTransparency = reduceTransparency;
    }
    if (reduceMotion != null) this.reduceMotion = reduceMotion;
    if (showNotificationPreviews != null) {
      this.showNotificationPreviews = showNotificationPreviews;
    }
    notifyListeners();
    final directory = _directory;
    if (directory == null) return;
    await directory.create(recursive: true);
    final target = File('${directory.path}/user-preferences.json');
    final temporary = File('${target.path}.part');
    await temporary.writeAsString(
      jsonEncode({
        'themeMode': this.themeMode.name,
        'glassTier': this.glassTier.name,
        'reduceTransparency': this.reduceTransparency,
        'reduceMotion': this.reduceMotion,
        'showNotificationPreviews': this.showNotificationPreviews,
      }),
      flush: true,
    );
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }
}
