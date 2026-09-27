import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

void main() {
  test('same batch is idempotent and advances the UID checkpoint', () {
    final initial = MailboxLocalState(uidValidity: 11, highestKnownUid: 5);
    final batch = ServerMailboxBatch(
      uidValidity: 11,
      messages: [
        ServerMessage(uid: 6, canonicalId: 'gmail:1', flags: {r'\Seen'}),
      ],
    );

    final twice = MailboxSyncReducer.apply(
      MailboxSyncReducer.apply(initial, batch),
      batch,
    );

    expect(twice.highestKnownUid, 6);
    expect(twice.messages, hasLength(1));
    expect(twice.messages[6]!.flags, {r'\Seen'});
  });

  test('pending local read intent wins over stale server flags', () {
    final initial = MailboxLocalState(
      uidValidity: 11,
      highestKnownUid: 4,
      messages: {4: LocalMessage(canonicalId: 'gmail:4', flags: const {})},
      pendingMutations: [const LocalReadMutation(4, read: true)],
    );

    final result = MailboxSyncReducer.apply(
      initial,
      ServerMailboxBatch(
        uidValidity: 11,
        messages: [
          ServerMessage(uid: 4, canonicalId: 'gmail:4', flags: const {})
        ],
      ),
    );

    expect(result.messages[4]!.flags, contains(r'\Seen'));
  });

  test('UIDVALIDITY reset drops stale UID mappings and retains canonical flags',
      () {
    final initial = MailboxLocalState(
      uidValidity: 11,
      highestKnownUid: 80,
      messages: {
        80: LocalMessage(canonicalId: 'gmail:preserve', flags: {r'\Seen'}),
      },
    );

    final result = MailboxSyncReducer.apply(
      initial,
      ServerMailboxBatch(
        uidValidity: 22,
        messages: [
          ServerMessage(uid: 1, canonicalId: 'gmail:preserve', flags: const {}),
        ],
      ),
    );

    expect(result.uidValidity, 22);
    expect(result.messages, isNot(contains(80)));
    expect(result.messages[1]!.flags, contains(r'\Seen'));
    expect(result.highestKnownUid, 1);
  });

  test('large mailbox batch keeps each server UID mapping', () {
    final result = MailboxSyncReducer.apply(
      MailboxLocalState(uidValidity: 11, highestKnownUid: 0),
      ServerMailboxBatch(
        uidValidity: 11,
        messages: [
          for (var uid = 1; uid <= 10000; uid++)
            ServerMessage(uid: uid, canonicalId: 'gmail:$uid', flags: const {}),
        ],
      ),
    );

    expect(result.messages, hasLength(10000));
    expect(result.highestKnownUid, 10000);
    expect(result.messages.values.map((item) => item.canonicalId).toSet(),
        hasLength(10000));
  });

  test('reducer input and output values compare structurally', () {
    final state = MailboxLocalState(
      uidValidity: 7,
      highestKnownUid: 10,
      messages: {
        10: LocalMessage(canonicalId: 'message', flags: {r'\Seen'}),
      },
      pendingMutations: const [LocalReadMutation(10, read: true)],
    );
    final clone = MailboxLocalState(
      uidValidity: 7,
      highestKnownUid: 10,
      messages: {
        10: LocalMessage(canonicalId: 'message', flags: {r'\Seen'}),
      },
      pendingMutations: const [LocalReadMutation(10, read: true)],
    );

    expect(state, clone);
    expect(state.hashCode, clone.hashCode);
  });
}
