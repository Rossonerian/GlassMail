import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';

void main() {
  test(
    'imports remote drafts with stable IDs and UIDVALIDITY namespace',
    () async {
      final raw = utf8.encode(
        'Message-ID: <draft-4@glassmail.local>\r\n'
        'To: Ada <ada@example.test>\r\n'
        'Bcc: hidden@example.test\r\n'
        'Subject: =?UTF-8?Q?Caf=C3=A9_notes?=\r\n'
        'In-Reply-To: <root@example.test>\r\n'
        'References: <root@example.test> <thread@example.test>\r\n'
        'Content-Type: text/plain; charset=utf-8\r\n\r\n'
        'Saved remotely',
      );
      final wire = _FakeWire([
        ImapResponseParser.parse(
          r'* LIST (\HasNoChildren \Drafts) "/" "Drafts"',
          const [],
        ),
        ImapResponseParser.parse('G0001 OK listed', const []),
        ImapResponseParser.parse('* 1 EXISTS', const []),
        ImapResponseParser.parse('* OK [UIDVALIDITY 91] valid', const []),
        ImapResponseParser.parse('* OK [UIDNEXT 5] next', const []),
        ImapResponseParser.parse('G0002 OK selected', const []),
        ImapResponseParser.parse('* SEARCH 4', const []),
        ImapResponseParser.parse('G0003 OK searched', const []),
        ImapResponseParser.parse(
          '* 1 FETCH (UID 4 INTERNALDATE "26-Sep-2026 12:00:00 +0000" '
          'BODY[] \u0000L0\u0000)',
          [Uint8List.fromList(raw)],
        ),
        ImapResponseParser.parse('G0004 OK fetched', const []),
      ]);
      final client = ImapClient(wire);

      final drafts = await client.fetchRemoteDrafts();

      expect(drafts, hasLength(1));
      expect(drafts.single.uid, 4);
      expect(drafts.single.uidValidity, 91);
      expect(drafts.single.draftId, 'draft-4');
      expect(drafts.single.to, ['ada@example.test']);
      expect(drafts.single.bcc, ['hidden@example.test']);
      expect(drafts.single.subject, 'Café notes');
      expect(drafts.single.body, 'Saved remotely');
      expect(drafts.single.inReplyTo, '<root@example.test>');
      expect(drafts.single.references, [
        '<root@example.test>',
        '<thread@example.test>',
      ]);
      expect(
        drafts.single.updatedAtEpochMillis,
        DateTime.utc(2026, 9, 26, 12).millisecondsSinceEpoch,
      );
    },
  );

  test('replaces only older copies after a successful draft APPEND', () async {
    final wire = _FakeWire([
      ImapResponseParser.parse('* CAPABILITY IMAP4rev1 UIDPLUS', const []),
      ImapResponseParser.parse('G0001 OK capabilities', const []),
      ImapResponseParser.parse('* SEARCH 4', const []),
      ImapResponseParser.parse('G0002 OK searched', const []),
      const ImapContinuation('send literal'),
      ImapResponseParser.parse('G0003 OK [APPENDUID 91 5] appended', const []),
      ImapResponseParser.parse('* SEARCH 4 5', const []),
      ImapResponseParser.parse('G0004 OK searched', const []),
      ImapResponseParser.parse('G0005 OK deleted', const []),
      ImapResponseParser.parse('G0006 OK expunged', const []),
    ]);
    final client = ImapClient(wire);
    final bytes = Uint8List.fromList(utf8.encode('draft bytes'));

    await client.replaceRemoteDraft('draft-4', bytes, draftsMailbox: 'Drafts');

    expect(wire.literals.single, bytes);
    expect(wire.commands.last, 'G0006 UID EXPUNGE 4');
    expect(
      wire.commands.any(
        (command) => command == 'G0005 UID STORE 4 +FLAGS.SILENT (\\Deleted)',
      ),
      isTrue,
    );
  });

  test('refuses draft deletion if UIDPLUS is unavailable', () async {
    final wire = _FakeWire([
      ImapResponseParser.parse('* CAPABILITY IMAP4rev1', const []),
      ImapResponseParser.parse('G0001 OK capabilities', const []),
    ]);
    final client = ImapClient(wire);

    await expectLater(
      client.deleteDraftUid(7),
      throwsA(isA<ImapProtocolException>()),
    );
    expect(wire.commands, ['G0001 CAPABILITY']);
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
