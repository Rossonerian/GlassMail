import 'package:flutter/foundation.dart';

const appShortcutCompose = 'compose';
const appShortcutInbox = 'inbox';
const appShortcutSearch = 'search';

/// Delivers launcher quick actions to the mounted mail workspace.
final appShortcutController = ValueNotifier<String?>(null);
