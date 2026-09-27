import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';

void main() {
  group('IMAP command client', () {
    test('quotes credentials and classifies authentication rejection',
        () async {
      final wire = _FakeWire([
        ImapResponseParser.parse(
            'G0001 NO [AUTHENTICATIONFAILED] denied', const []),
      ]);
      final client = ImapClient(wire);

      await expectLater(
        client.login(
            'user@example.com', Uint8List.fromList('p"a\\ss'.codeUnits)),
        throwsA(isA<ImapAuthenticationException>()),
      );
      expect(
        wire.commands.single,
        r'G0001 LOGIN "user@example.com" "p\"a\\ss"',
      );
      expect(wire.commands.single, isNot(contains('AUTHENTICATIONFAILED')));
    });

    test('selects a mailbox and reads UIDVALIDITY, UIDNEXT and EXISTS',
        () async {
      final wire = _FakeWire([
        ImapResponseParser.parse('* 7 EXISTS', const []),
        ImapResponseParser.parse('* OK [UIDVALIDITY 91] valid', const []),
        ImapResponseParser.parse('* OK [UIDNEXT 108] next', const []),
        ImapResponseParser.parse('G0001 OK [READ-WRITE] selected', const []),
      ]);
      final client = ImapClient(wire);

      final selected = await client.selectMailbox('INBOX');

      expect(selected.uidValidity, 91);
      expect(selected.uidNext, 108);
      expect(selected.messageCount, 7);
      expect(wire.commands, ['G0001 SELECT "INBOX"']);
    });

    test('parses special-use LIST attributes and storage quota responses',
        () async {
      final wire = _FakeWire([
        ImapResponseParser.parse(
          r'* LIST (\HasNoChildren \Sent) "/" "[Gmail]/Sent Mail"',
          const [],
        ),
        ImapResponseParser.parse('G0001 OK list complete', const []),
        ImapResponseParser.parse('* QUOTA "" (STORAGE 3 9)', const []),
        ImapResponseParser.parse('G0002 OK quota complete', const []),
      ]);
      final client = ImapClient(wire);

      final mailboxes = await client.listMailboxes();
      final quota = await client.storageQuota('INBOX');

      expect(mailboxes.single.name, '[Gmail]/Sent Mail');
      expect(mailboxes.single.attributes, {r'\HasNoChildren', r'\Sent'});
      expect(quota?.usedKb, 3);
      expect(quota?.limitKb, 9);
      expect(
          wire.commands, ['G0001 LIST "" "*"', 'G0002 GETQUOTAROOT "INBOX"']);
    });

    test('permanently deletes only a UID from a UIDPLUS Trash mailbox',
        () async {
      final wire = _FakeWire([
        ImapResponseParser.parse('* 2 EXISTS', const []),
        ImapResponseParser.parse('* OK [UIDVALIDITY 91] valid', const []),
        ImapResponseParser.parse('* OK [UIDNEXT 4] next', const []),
        ImapResponseParser.parse('G0001 OK selected', const []),
        ImapResponseParser.parse(
          r'* LIST (\HasNoChildren \Trash) "/" "[Gmail]/Trash"',
          const [],
        ),
        ImapResponseParser.parse('G0002 OK listed', const []),
        ImapResponseParser.parse('* CAPABILITY IMAP4rev1 UIDPLUS', const []),
        ImapResponseParser.parse('G0003 OK capabilities', const []),
        ImapResponseParser.parse('G0004 OK marked', const []),
        ImapResponseParser.parse('G0005 OK expunged', const []),
      ]);
      final client = ImapClient(wire);

      await client.selectMailbox('[Gmail]/Trash');
      await client.permanentlyDeleteTrashUid(
        3,
        mailbox: '[Gmail]/Trash',
      );

      expect(wire.commands, [
        'G0001 SELECT "[Gmail]/Trash"',
        'G0002 LIST "" "*"',
        'G0003 CAPABILITY',
        r'G0004 UID STORE 3 +FLAGS.SILENT (\Deleted)',
        'G0005 UID EXPUNGE 3',
      ]);
      expect(wire.commands, isNot(contains('EXPUNGE')));
    });

    test('permanent delete rejects non-Trash mailboxes', () async {
      final wire = _FakeWire([
        ImapResponseParser.parse('* 2 EXISTS', const []),
        ImapResponseParser.parse('* OK [UIDVALIDITY 91] valid', const []),
        ImapResponseParser.parse('* OK [UIDNEXT 4] next', const []),
        ImapResponseParser.parse('G0001 OK selected', const []),
        ImapResponseParser.parse(
          r'* LIST (\HasNoChildren \Inbox) "/" "INBOX"',
          const [],
        ),
        ImapResponseParser.parse('G0002 OK listed', const []),
      ]);
      final client = ImapClient(wire);

      await client.selectMailbox('INBOX');
      await expectLater(
        client.permanentlyDeleteTrashUid(3, mailbox: 'INBOX'),
        throwsA(isA<ImapProtocolException>()),
      );
      expect(wire.commands, ['G0001 SELECT "INBOX"', 'G0002 LIST "" "*"']);
    });

    test('fetches Gmail metadata fields and preserves sparse UID ranges',
        () async {
      final fetch = ImapResponseParser.parse(
        r'* 4 FETCH (UID 18 FLAGS (\Seen) X-GM-MSGID 77 X-GM-THRID 88 X-GM-LABELS (\Inbox "Travel"))',
        const [],
      );
      final wire = _FakeWire([
        fetch,
        ImapResponseParser.parse('G0001 OK fetched', const []),
      ]);
      final client = ImapClient(wire);

      final results = await client.fetchMetadata(
        '4:12,14,18:25',
        gmailExtensions: true,
      );

      expect(results, [fetch]);
      expect(wire.commands.single, contains('UID FETCH 4:12,14,18:25'));
      expect(
          wire.commands.single, contains('X-GM-MSGID X-GM-THRID X-GM-LABELS'));
      expect(wire.commands.single, contains('BODY.PEEK[HEADER.FIELDS'));
    });

    test('rejects malformed UID ranges and command injection', () async {
      final client = ImapClient(_FakeWire(const []));

      await expectLater(
        client.fetchMetadata('1:; LOGOUT', gmailExtensions: true),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        client.selectMailbox('INBOX\r\nG0002 LOGOUT'),
        throwsA(isA<ImapProtocolException>()),
      );
    });

    test('uses Gmail silent label commands and escapes labels', () async {
      final wire = _FakeWire([
        ImapResponseParser.parse('G0001 OK stored', const []),
      ]);
      final client = ImapClient(wire);

      await client.storeGmailLabel(99, 'Work "Later"', add: true);

      expect(
        wire.commands.single,
        r'G0001 UID STORE 99 +X-GM-LABELS.SILENT ("Work \"Later\"")',
      );
    });

    test(
        'sends APPEND payload only after continuation and waits for completion',
        () async {
      final wire = _FakeWire([
        const ImapContinuation('send literal'),
        ImapResponseParser.parse('* 4 EXISTS', const []),
        ImapResponseParser.parse(
            'G0001 OK [APPENDUID 91 108] appended', const []),
      ]);
      final client = ImapClient(wire);
      final message = Uint8List.fromList([0x48, 0x69]);

      await client.append('[Gmail]/Sent Mail', message);

      expect(wire.commands, ['G0001 APPEND "[Gmail]/Sent Mail" (\\Seen) {2}']);
      expect(wire.literals, [message]);
    });

    test('DELIVERs mailbox changes during IDLE and surfaces BYE', () async {
      final wire = _FakeWire([
        const ImapContinuation('idling'),
        ImapResponseParser.parse('* 8 EXISTS', const []),
        ImapResponseParser.parse('G0001 OK idle complete', const []),
      ]);
      final client = ImapClient(wire);
      var notifications = 0;

      await client.idle(
        window: const Duration(minutes: 1),
        onMailboxChanged: () async => notifications++,
      );

      expect(notifications, 1);
      expect(wire.commands, ['G0001 IDLE']);

      final disconnected = ImapClient(
        _FakeWire([
          ImapResponseParser.parse('* BYE server closing', const []),
        ]),
      );
      await expectLater(
        disconnected.capability(),
        throwsA(isA<ImapProtocolException>()),
      );
      await disconnected.close();

      final reconnected = ImapClient(
        _FakeWire([
          ImapResponseParser.parse('* CAPABILITY IMAP4rev1', const []),
          ImapResponseParser.parse('G0001 OK capabilities', const []),
        ]),
      );
      expect(await reconnected.capability(), {'IMAP4REV1'});
    });
  });
}

final class _FakeWire implements ImapWireConnection {
  _FakeWire(Iterable<ImapResponse> responses) : _responses = List.of(responses);

  final List<ImapResponse> _responses;
  final List<String> commands = [];
  final List<Uint8List> literals = [];

  @override
  Future<void> close() async {}

  @override
  Future<ImapResponse> readResponse({Duration? timeout}) async {
    if (_responses.isEmpty) throw StateError('No fake IMAP response remains');
    return _responses.removeAt(0);
  }

  @override
  Future<void> writeCommand(String command) async => commands.add(command);

  @override
  Future<void> writeLiteral(Uint8List bytes) async => literals.add(bytes);
}
