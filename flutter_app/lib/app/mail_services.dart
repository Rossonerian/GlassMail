import 'package:flutter/foundation.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:glassmail_data_mail/glassmail_data_mail.dart';

import '../platform/account_sync_scheduler.dart';
import '../platform/mail_notifications.dart';

final notificationRouteController = ValueNotifier<String?>(null);

/// App-lifetime composition root. Mail data stays in Drift and credentials are
/// only passed to the transport through the secure-store boundary.
Future<LocalFirstMailRepository> createMailRepository() async {
  final database = GlassMailDatabase();
  final credentials = FlutterCredentialStore();
  final scheduler = AccountSyncScheduler();
  final notifications = MailNotifications();
  final mutations = PendingMutationQueue(
    database: database,
    credentialStore: credentials,
    transport: ImapPendingMutationTransport(),
  );
  final outgoing = OutgoingMailQueue(
    database: database,
    credentialStore: credentials,
    transport: SecureSmtpMailTransport(),
    sentCopyAppender: ImapSentCopyAppender(),
  );

  return LocalFirstMailRepository(
    database: database,
    credentialStore: credentials,
    mutationQueue: mutations,
    outgoingQueue: outgoing,
    sentMailboxSource: ImapSentMailboxPageSource(),
    trashMailboxSource: ImapTrashMailboxPageSource(),
    onAccountAdded: scheduler.scheduleAccount,
    onAccountRemoved: scheduler.cancelAccount,
    onNewMessages: notifications.showNewMessages,
  );
}
