import 'dart:math';
import 'package:drift/drift.dart';
import 'package:glassmail_core_database/glassmail_core_database.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

abstract interface class PendingMutationTransport {
  Future<void> apply({
    required String email,
    required Uint8List credentialUtf8,
    required PendingMutation mutation,
  });
}

typedef MutationImapConnector = Future<ImapClient> Function();

final class ImapPendingMutationTransport implements PendingMutationTransport {
  ImapPendingMutationTransport({MutationImapConnector? connect})
      : _connect = connect ?? ImapClient.connect;

  final MutationImapConnector _connect;

  @override
  Future<void> apply({
    required String email,
    required Uint8List credentialUtf8,
    required PendingMutation mutation,
  }) async {
    final uid = mutation.targetUid;
    if (uid == null || uid <= 0) {
      throw const ImapProtocolException('Pending mutation has no UID');
    }
    final client = await _connect();
    try {
      await client.login(email, credentialUtf8);
      final mailbox = mutation.mailboxId?.split(':').skip(1).join(':');
      await client.selectMailbox(
        mailbox == null || mailbox.isEmpty ? 'INBOX' : mailbox,
      );
      await client.applyMutation(
        uid: uid,
        type: mutation.type,
        label: mutation.payload,
      );
    } finally {
      await client.close();
    }
  }
}

/// Durable optimistic mutations and ordered, per-account server flushing.
final class PendingMutationQueue {
  PendingMutationQueue({
    required GlassMailDatabase database,
    required CredentialStore credentialStore,
    required PendingMutationTransport transport,
    int Function()? clock,
    String Function()? mutationIdFactory,
  })  : _database = database,
        _credentialStore = credentialStore,
        _transport = transport,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _mutationIdFactory = mutationIdFactory ?? _newMutationId;

  final GlassMailDatabase _database;
  final CredentialStore _credentialStore;
  final PendingMutationTransport _transport;
  final int Function() _clock;
  final String Function() _mutationIdFactory;

  Future<void> applyLocal(MailMutation mutation) async {
    await _database.transaction(() async {
      final message = await (_database.select(_database.messages)
            ..where((row) =>
                row.messageId.equals(mutation.messageId) &
                row.accountId.equals(mutation.accountId)))
          .getSingleOrNull();
      if (message == null) {
        throw StateError('Message does not belong to account');
      }

      final allMemberships =
          await _database.membershipsForMessage(mutation.messageId);
      final targeted = allMemberships
          .where((row) =>
              mutation.mailboxId == null || row.mailboxId == mutation.mailboxId)
          .toList(growable: false);
      final previous = targeted.firstOrNull;
      final type = _typeFor(mutation);
      if (mutation is ArchiveMutation && previous == null) {
        throw StateError('Cannot archive a message without a mailbox mapping');
      }

      switch (mutation) {
        case MarkReadMutation(:final read):
          await _writeMembershipFlags(
            targeted,
            r'\Seen',
            read,
          );
        case StarMutation(:final starred):
          await _writeMembershipFlags(
            targeted,
            r'\Flagged',
            starred,
          );
        case ArchiveMutation():
          await _removeMemberships(targeted);
        case DeleteMutation():
          await _removeMemberships(targeted);
        case LabelMutation(:final label, :final add):
          final rows = targeted.map((row) {
            final labels = _decodeLabels(row.labels);
            if (add) {
              labels.add(label);
            } else {
              labels.remove(label);
            }
            return MailboxMessagesCompanion.insert(
              mailboxId: row.mailboxId,
              uid: row.uid,
              messageId: row.messageId,
              flags: row.flags,
              labels: _encodeLabels(labels),
            );
          }).toList();
          if (rows.isNotEmpty) await _database.saveMailboxMessages(rows);
          if (add) {
            await _database.saveLabels([
              MessageLabelsCompanion.insert(
                messageId: mutation.messageId,
                label: label,
              ),
            ]);
          } else {
            await (_database.delete(_database.messageLabels)
                  ..where((row) =>
                      row.messageId.equals(mutation.messageId) &
                      row.label.equals(label)))
                .go();
          }
      }

      await _database.insertPendingMutation(PendingMutationsCompanion.insert(
        mutationId: _mutationIdFactory(),
        accountId: mutation.accountId,
        mailboxId: Value(mutation.mailboxId),
        messageId: mutation.messageId,
        targetUid: Value(previous?.uid),
        type: type,
        payload: Value(mutation is LabelMutation ? mutation.label : null),
        state: 'PENDING',
        retryCount: 0,
        createdAtEpochMillis: _clock(),
        previousFlags: Value(previous?.flags ?? ''),
        previousLabels: Value(previous?.labels ?? ''),
      ));
    });
  }

  Future<bool> undoPendingArchive(String messageId) =>
      _database.transaction(() async {
        final mutation = await _database.undoableArchiveForMessage(messageId);
        if (mutation == null ||
            mutation.mailboxId == null ||
            mutation.targetUid == null) {
          return false;
        }
        await _database.saveMailboxMessages([
          MailboxMessagesCompanion.insert(
            mailboxId: mutation.mailboxId!,
            uid: mutation.targetUid!,
            messageId: mutation.messageId,
            flags: mutation.previousFlags,
            labels: mutation.previousLabels,
          ),
        ]);
        await _database.deletePendingMutation(mutation.mutationId);
        return true;
      });

  Future<void> flush(String accountId) async {
    final account = await _database.accountById(accountId);
    if (account == null) return;
    final mutations = await _database.activeMutationsForAccount(accountId);
    if (mutations.isEmpty) return;

    final messageIdsMissingUid = mutations
        .where((mutation) => mutation.targetUid == null)
        .map((m) => m.messageId)
        .toSet();

    final membershipsByMessageId = <String, List<dynamic>>{};
    if (messageIdsMissingUid.isNotEmpty) {
      final allMemberships =
          await _database.membershipsForMessages(messageIdsMissingUid);
      for (final m in allMemberships) {
        membershipsByMessageId.putIfAbsent(m.messageId, () => []).add(m);
      }
    }

    await _credentialStore.withCredential(accountId, (credential) async {
      for (final mutation in mutations) {
        int? uid = mutation.targetUid;
        if (uid == null) {
          final memberships = membershipsByMessageId[mutation.messageId] ?? [];
          uid = memberships
              .where((row) =>
                  mutation.mailboxId == null ||
                  row.mailboxId == mutation.mailboxId)
              .firstOrNull
              ?.uid;
        }
        if (uid == null) {
          await _markPermanent(mutation, 'MISSING_UID');
          continue;
        }

        await _database.updatePendingMutationState(
          mutationId: mutation.mutationId,
          state: 'IN_FLIGHT',
          retryCount: mutation.retryCount,
          errorCode: null,
        );
        try {
          final remoteMailbox = mutation.mailboxId == null
              ? null
              : await _database.mailboxRemoteName(mutation.mailboxId!);
          await _transport.apply(
            email: account.email,
            credentialUtf8: credential,
            mutation: mutation.copyWith(
              mailboxId: Value(
                remoteMailbox == null
                    ? mutation.mailboxId
                    : 'remote:$remoteMailbox',
              ),
              targetUid: Value(uid),
            ),
          );
          await _database.deletePendingMutation(mutation.mutationId);
        } on ImapTransportException {
          await _database.updatePendingMutationState(
            mutationId: mutation.mutationId,
            state: 'PENDING',
            retryCount: mutation.retryCount + 1,
            errorCode: 'NETWORK',
          );
        } on ImapAuthenticationException {
          await _markPermanent(mutation, 'AUTHENTICATION');
        } on ImapProtocolException {
          await _markPermanent(mutation, 'SERVER_REJECTED');
        }
      }
    });
  }

  Future<void> _markPermanent(PendingMutation mutation, String errorCode) =>
      _database.updatePendingMutationState(
        mutationId: mutation.mutationId,
        state: 'FAILED_PERMANENT',
        retryCount: mutation.retryCount,
        errorCode: errorCode,
      );

  Future<void> _writeMembershipFlags(
    List<MailboxMessage> memberships,
    String flag,
    bool enabled,
  ) async {
    if (memberships.isEmpty) return;
    await _database.saveMailboxMessages(memberships.map((membership) {
      final flags = _decodeFlags(membership.flags);
      if (enabled) {
        flags.add(flag);
      } else {
        flags.remove(flag);
      }
      return MailboxMessagesCompanion.insert(
        mailboxId: membership.mailboxId,
        uid: membership.uid,
        messageId: membership.messageId,
        flags: (flags.toList()..sort()).join(' '),
        labels: membership.labels,
      );
    }));
  }

  Future<void> _removeMemberships(List<MailboxMessage> memberships) async {
    for (final membership in memberships) {
      await _database.removeMailboxMembership(
        membership.mailboxId,
        membership.messageId,
      );
    }
  }

  static String _typeFor(MailMutation mutation) => switch (mutation) {
        MarkReadMutation(read: true) => 'MARK_READ',
        MarkReadMutation(read: false) => 'MARK_UNREAD',
        StarMutation(starred: true) => 'STAR',
        StarMutation(starred: false) => 'UNSTAR',
        ArchiveMutation() => 'ARCHIVE',
        DeleteMutation() => 'DELETE',
        LabelMutation(add: true) => 'ADD_LABEL',
        LabelMutation(add: false) => 'REMOVE_LABEL',
      };

  static Set<String> _decodeFlags(String value) =>
      value.split(' ').where((item) => item.isNotEmpty).toSet();

  static Set<String> _decodeLabels(String value) =>
      value.split('\u001f').where((item) => item.isNotEmpty).toSet();

  static String _encodeLabels(Set<String> labels) =>
      (labels.toList()..sort()).join('\u001f');
}

String _newMutationId() {
  final random = Random.secure();
  return List<int>.generate(16, (_) => random.nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
