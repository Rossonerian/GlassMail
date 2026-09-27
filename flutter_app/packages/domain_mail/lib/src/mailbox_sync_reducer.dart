import 'mail_value.dart';

/// Pure values and reconciliation logic for one mailbox's UID namespace.
///
/// A UIDVALIDITY change discards stale UID mappings while preserving canonical
/// message flags for messages that can be matched again. Pending local read and
/// star intent wins over stale flags returned by the server.
final class ServerMessage with MailValueEquality {
  ServerMessage({
    required this.uid,
    required this.canonicalId,
    required Set<String> flags,
  }) : flags = Set.unmodifiable(flags);

  final int uid;
  final String canonicalId;
  final Set<String> flags;

  @override
  List<Object?> get equalityProps => [uid, canonicalId, flags];
}

final class ServerMailboxBatch with MailValueEquality {
  ServerMailboxBatch({
    required this.uidValidity,
    required List<ServerMessage> messages,
  }) : messages = List.unmodifiable(messages);

  final int uidValidity;
  final List<ServerMessage> messages;

  @override
  List<Object?> get equalityProps => [uidValidity, messages];
}

final class LocalMessage with MailValueEquality {
  LocalMessage({required this.canonicalId, required Set<String> flags})
      : flags = Set.unmodifiable(flags);

  final String canonicalId;
  final Set<String> flags;

  @override
  List<Object?> get equalityProps => [canonicalId, flags];
}

sealed class LocalMutation with MailValueEquality {
  const LocalMutation(this.messageUid);

  final int messageUid;

  @override
  List<Object?> get equalityProps => [messageUid];
}

final class LocalReadMutation extends LocalMutation {
  const LocalReadMutation(super.messageUid, {required this.read});

  final bool read;

  @override
  List<Object?> get equalityProps => [...super.equalityProps, read];
}

final class LocalStarMutation extends LocalMutation {
  const LocalStarMutation(super.messageUid, {required this.starred});

  final bool starred;

  @override
  List<Object?> get equalityProps => [...super.equalityProps, starred];
}

final class MailboxLocalState with MailValueEquality {
  MailboxLocalState({
    required this.uidValidity,
    required this.highestKnownUid,
    Map<int, LocalMessage> messages = const {},
    List<LocalMutation> pendingMutations = const [],
  })  : messages = Map.unmodifiable(messages),
        pendingMutations = List.unmodifiable(pendingMutations);

  final int uidValidity;
  final int highestKnownUid;
  final Map<int, LocalMessage> messages;
  final List<LocalMutation> pendingMutations;

  @override
  List<Object?> get equalityProps => [
        uidValidity,
        highestKnownUid,
        messages,
        pendingMutations,
      ];
}

abstract final class MailboxSyncReducer {
  static MailboxLocalState apply(
    MailboxLocalState current,
    ServerMailboxBatch server,
  ) {
    final previousByCanonicalId = {
      for (final message in current.messages.values)
        message.canonicalId: message,
    };
    final reset = current.uidValidity != server.uidValidity;
    final merged = <int, LocalMessage>{};

    for (final remote in server.messages) {
      final existing = reset
          ? previousByCanonicalId[remote.canonicalId]
          : current.messages[remote.uid];
      var flags = remote.flags;
      for (final mutation in current.pendingMutations.where(
        (mutation) => mutation.messageUid == remote.uid,
      )) {
        switch (mutation) {
          case LocalReadMutation(:final read):
            flags = _withFlag(flags, r'\Seen', read);
          case LocalStarMutation(:final starred):
            flags = _withFlag(flags, r'\Flagged', starred);
        }
      }
      merged[remote.uid] = LocalMessage(
        canonicalId: remote.canonicalId,
        flags: flags.isEmpty ? (existing?.flags ?? const {}) : flags,
      );
    }

    final highestServerUid = server.messages.fold<int>(
      0,
      (highest, message) => message.uid > highest ? message.uid : highest,
    );
    return MailboxLocalState(
      uidValidity: server.uidValidity,
      highestKnownUid: _max(
        reset ? 0 : current.highestKnownUid,
        highestServerUid,
      ),
      messages: reset ? merged : {...current.messages, ...merged},
      pendingMutations: current.pendingMutations,
    );
  }

  static Set<String> _withFlag(Set<String> flags, String flag, bool present) =>
      Set.unmodifiable(
        present ? {...flags, flag} : flags.where((item) => item != flag),
      );

  static int _max(int a, int b) => a > b ? a : b;
}
