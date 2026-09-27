import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';

void main() {
  group('IMAP response parser', () {
    test('parses Gmail FETCH attributes and nested flags and labels', () {
      final response =
          ImapResponseParser.parse(
                r'* 42 FETCH (UID 900 FLAGS (\Seen \Flagged) X-GM-MSGID 123 X-GM-THRID 456 X-GM-LABELS (\Inbox "Projects"))',
                const [],
              )
              as ImapUntagged;
      final fetch = response.values[2].listValue;

      expect(response.values[0].atomValue, '42');
      expect(response.values[1].atomValue, 'FETCH');
      expect(fetch.attribute('UID')?.atomValue, '900');
      expect(fetch.attribute('X-GM-MSGID')?.atomValue, '123');
      expect(fetch.attribute('X-GM-THRID')?.atomValue, '456');
      expect(
        fetch
            .attribute('X-GM-LABELS')
            ?.listValue
            .map((value) => value.atomValue),
        [r'\Inbox', 'Projects'],
      );
      expect(fetch.attribute('FLAGS')?.listValue.first.atomValue, r'\Seen');
    });

    test('parses response codes and BODY.PEEK header sections', () {
      final response =
          ImapResponseParser.parse(
                '* OK [UIDVALIDITY 12345] UIDs valid',
                const [],
              )
              as ImapUntagged;
      final code = response.values[1].listValue;
      expect(code.attribute('UIDVALIDITY')?.atomValue, '12345');
      expect(response.values[2].atomValue, 'UIDs');

      final fetch =
          ImapResponseParser.parse(
                '* 1 FETCH (UID 7 BODY.PEEK[HEADER.FIELDS (DATE FROM)] \u0000L0\u0000)',
                [Uint8List.fromList(utf8.encode('Date: today\r\n'))],
              )
              as ImapUntagged;
      final fields = fetch.values[2].listValue;
      expect(
        fields.attribute('BODY.PEEK[HEADER.FIELDS (DATE FROM)]')?.literalValue,
        utf8.encode('Date: today\r\n'),
      );
      expect(fields.attribute('X-GM-UNKNOWN'), isNull);
    });

    test(
      'distinguishes tagged, untagged, continuation, quoted and NIL values',
      () {
        final tagged =
            ImapResponseParser.parse(
                  'G0001 OK [APPENDUID 4 900] done',
                  const [],
                )
                as ImapTagged;
        expect(tagged.tag, 'G0001');
        expect(tagged.status, 'OK');
        expect(
          tagged.values.first.listValue.attribute('APPENDUID')?.atomValue,
          '4',
        );

        expect(
          (ImapResponseParser.parse('+ continue', const []) as ImapContinuation)
              .text,
          'continue',
        );
        final values =
            ImapResponseParser.parse(
                  r'* LIST (\HasNoChildren) "/" "[Gmail]/Sent Mail"',
                  const [],
                )
                as ImapUntagged;
        expect(values.values[3].atomValue, '[Gmail]/Sent Mail');
        expect(values.values[2], isA<ImapQuoted>());
        expect(
          ImapResponseParser.parse('* 1 FETCH (BODY[] NIL)', const []),
          isA<ImapUntagged>(),
        );
      },
    );

    test('rejects malformed values and invalid literal references', () {
      for (final line in [
        '',
        'G0001',
        '* OK (unterminated',
        '* OK "unterminated',
        '* OK BODY[HEADER',
        '* OK ${'(' * (maxImapNestingDepth + 1)}x${')' * (maxImapNestingDepth + 1)}',
        '* OK \u0000not-a-literal\u0000',
        '* OK \u0000L2\u0000',
      ]) {
        expect(
          () => ImapResponseParser.parse(line, const []),
          throwsA(isA<ImapProtocolException>()),
          reason: 'input should be rejected: $line',
        );
      }
      final values =
          (ImapResponseParser.parse('* OK UIDVALIDITY', const [])
                  as ImapUntagged)
              .values;
      expect(values.attribute('UIDNEXT'), isNull);
      expect(const ImapNil().atomValue, isNull);
    });
  });

  group('IMAP response stream framing', () {
    test('reads responses across arbitrary packet boundaries', () async {
      final bytes = utf8.encode(
        '* 42 FETCH (UID 900 X-GM-LABELS (\\Inbox "Projects") BODY.PEEK[] {5}\r\n'
        'a\r\nbc)\r\n',
      );
      final reader = ImapResponseReader(_singleByteChunks(bytes));
      final response = await reader.readResponse() as ImapUntagged;
      final fields = response.values[2].listValue;

      expect(fields.attribute('UID')?.atomValue, '900');
      expect(fields.attribute('BODY.PEEK[]')?.literalValue, [
        97,
        13,
        10,
        98,
        99,
      ]);
      await reader.cancel();
    });

    test('preserves bytes and reads a maximum sized literal', () async {
      final prefix = utf8.encode(
        '* 1 FETCH (BODY[] {$maxImapLiteralBytes}\r\n',
      );
      final payload = Uint8List(maxImapLiteralBytes)
        ..fillRange(0, maxImapLiteralBytes, 0x78);
      final suffix = utf8.encode(')\r\n');
      final reader = ImapResponseReader(
        Stream<List<int>>.fromIterable([prefix, payload, suffix]),
      );

      final response = await reader.readResponse() as ImapUntagged;
      final literal = response.values[2].listValue
          .attribute('BODY[]')!
          .literalValue!;
      expect(literal.length, maxImapLiteralBytes);
      expect(literal.first, 0x78);
      expect(literal.last, 0x78);
      await reader.cancel();
    });

    test('bounds all literals in one response together', () async {
      final firstSize = maxImapLiteralBytes ~/ 2;
      final secondSize = firstSize + 1;
      final reader = ImapResponseReader(
        Stream<List<int>>.fromIterable([
          utf8.encode('* 1 FETCH (BODY[] {$firstSize}\r\n'),
          Uint8List(firstSize),
          utf8.encode(' BODY[1] {$secondSize}\r\n'),
        ]),
      );

      await expectLater(
        reader.readResponse(),
        throwsA(isA<ImapProtocolException>()),
      );
      await reader.cancel();
    });

    test(
      'enforces line and literal bounds and rejects truncated literals',
      () async {
        final maxLine = '* OK ${'x' * (maxImapLineBytes - 6)}\r\n';
        final lineReader = ImapResponseReader(
          Stream.value(utf8.encode(maxLine)),
        );
        expect(await lineReader.readResponse(), isA<ImapUntagged>());
        await lineReader.cancel();

        final tooLongLine = '* OK ${'x' * (maxImapLineBytes - 5)}\r\n';
        final longReader = ImapResponseReader(
          Stream.value(utf8.encode(tooLongLine)),
        );
        await expectLater(
          longReader.readResponse(),
          throwsA(isA<ImapProtocolException>()),
        );
        await longReader.cancel();

        final tooLarge = ImapResponseReader(
          Stream.value(
            utf8.encode('* 1 FETCH (BODY[] {${maxImapLiteralBytes + 1}}\r\n'),
          ),
        );
        await expectLater(
          tooLarge.readResponse(),
          throwsA(isA<ImapProtocolException>()),
        );
        await tooLarge.cancel();

        final malformedMarker = ImapResponseReader(
          Stream.value(utf8.encode('* 1 FETCH (BODY[] {x}\r\n')),
        );
        await expectLater(
          malformedMarker.readResponse(),
          throwsA(isA<ImapProtocolException>()),
        );
        await malformedMarker.cancel();

        final truncated = ImapResponseReader(
          Stream.value(utf8.encode('* 1 FETCH (BODY[] {4}\r\nab')),
        );
        await expectLater(
          truncated.readResponse(),
          throwsA(isA<ImapProtocolException>()),
        );
        await truncated.cancel();
      },
    );

    test('cancel interrupts a pending response read', () async {
      final stream = StreamController<List<int>>();
      final reader = ImapResponseReader(stream.stream);
      final pending = reader.readResponse();
      await Future<void>.delayed(Duration.zero);
      final interrupted = expectLater(
        pending,
        throwsA(isA<ImapProtocolException>()),
      );

      await reader.cancel();

      await interrupted;
      await stream.close();
    });
  });
}

Stream<List<int>> _singleByteChunks(List<int> bytes) =>
    Stream<List<int>>.fromIterable(bytes.map((byte) => [byte]));
