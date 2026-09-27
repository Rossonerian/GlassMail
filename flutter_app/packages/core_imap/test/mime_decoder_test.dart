import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';

void main() {
  group('MIME decoder', () {
    test('decodes Q and Base64 RFC 2047 words and adjacent encoded words', () {
      expect(
        MimeDecoder.decodeMimeWords(
          '=?UTF-8?Q?=E2=8F=B0_Important_Update!?=',
        ),
        '⏰ Important Update!',
      );
      expect(
        MimeDecoder.decodeMimeWords('=?UTF-8?B?SGVsbG8gV29ybGQ=?='),
        'Hello World',
      );
      expect(
        MimeDecoder.decodeMimeWords(
          '=?UTF-8?Q?Hello_?=  =?UTF-8?Q?World!?=',
        ),
        'Hello World!',
      );
      expect(
        MimeDecoder.decodeMimeWords('A plain subject'),
        'A plain subject',
      );
    });

    test('parses plain UTF-8 and multipart alternative content', () {
      final plain = MimeDecoder.parseRfc822(
        Uint8List.fromList(
          utf8.encode(
            'Content-Type: text/plain; charset=utf-8\r\n'
            'Content-Transfer-Encoding: 7bit\r\n\r\n'
            'Hello, this is a plain text email body.',
          ),
        ),
      );
      expect(plain.plainText, 'Hello, this is a plain text email body.');
      expect(plain.previewSnippet, plain.plainText);

      const multipart = '''
Content-Type: multipart/alternative; boundary="boundary42"

--boundary42
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: quoted-printable

Hello=20World!=20Welcome to GlassMail.
--boundary42
Content-Type: text/html; charset=utf-8

<p>Hello <b>World</b>! Welcome to GlassMail.</p>
--boundary42--
''';
      final parsed = MimeDecoder.parseRfc822(
        Uint8List.fromList(utf8.encode(multipart)),
      );
      expect(parsed.plainText, contains('Hello World! Welcome to GlassMail.'));
      expect(parsed.htmlText, contains('<p>Hello'));
      expect(parsed.previewSnippet, 'Hello World! Welcome to GlassMail.');
      expect(parsed.attachments, isEmpty);
    });

    test('finds stable nested IMAP part IDs and bounded attachment metadata',
        () {
      const mixed = '''
Content-Type: multipart/mixed; boundary="outer"

--outer
Content-Type: multipart/alternative; boundary="inner"

--inner
Content-Type: text/plain; charset=utf-8

Hello from the body.
--inner
Content-Type: text/html; charset=utf-8

<p>Hello from the body.</p>
--inner--
--outer
Content-Type: application/pdf; name="=?UTF-8?B?cmVwb3J0LnBkZg==?="
Content-Disposition: attachment; filename="=?UTF-8?B?cmVwb3J0LnBkZg==?="
Content-Transfer-Encoding: base64

JVBERi0xLjQ=
--outer--
''';
      final parsed = MimeDecoder.parseRfc822(
        Uint8List.fromList(utf8.encode(mixed)),
      );

      expect(parsed.plainText, contains('Hello from the body.'));
      expect(parsed.attachments, hasLength(1));
      expect(parsed.attachments.single.partId, '2');
      expect(parsed.attachments.single.fileName, 'report.pdf');
      expect(parsed.attachments.single.mimeType, 'application/pdf');
      expect(parsed.attachments.single.sizeBytes, 8);
    });

    test('decodes transfer encoding, folded headers and safe preview text', () {
      final message = MimeDecoder.parseRfc822(
        Uint8List.fromList(
          utf8.encode(
            'Subject: first\r\n\tcontinued\r\n'
            'Content-Type: text/plain; charset=utf-8\r\n'
            'Content-Transfer-Encoding: base64\r\n\r\n'
            '${base64.encode(utf8.encode('A base64 body'))}\r\n',
          ),
        ),
      );
      expect(message.plainText, 'A base64 body');
      expect(
        MimeDecoder.decodeMimeWords('=?UTF-8?Q?caf=C3=A9?='),
        'café',
      );
    });

    test('strips script/style markup and decodes HTML entities', () {
      expect(
        MimeDecoder.htmlToPlainText(
          '<style>.hide {display:none}</style><script>bad()</script>'
          '<div><h1>Title</h1><p>Paragraph &amp; &lt;tag&gt; '
          '&quot;quote&quot; &#128512; and&nbsp;spaces.</p></div>',
        ),
        'Title\n\nParagraph & <tag> "quote" 😀 and spaces.',
      );
    });

    test('bounds input size and multipart recursion and part count', () {
      expect(
        () => MimeDecoder.parseRfc822(
          Uint8List(MimeDecoder.maxMessageBytes + 1),
        ),
        throwsA(isA<ImapProtocolException>()),
      );

      final tooManyParts = StringBuffer(
        'Content-Type: multipart/mixed; boundary="b"\r\n\r\n',
      );
      for (var index = 0; index < MimeDecoder.maxMultipartParts + 3; index++) {
        tooManyParts.write('--b\r\nContent-Type: text/plain\r\n\r\nx\r\n');
      }
      tooManyParts.write('--b--\r\n');
      expect(
        () => MimeDecoder.parseRfc822(
          Uint8List.fromList(utf8.encode(tooManyParts.toString())),
        ),
        throwsA(isA<ImapProtocolException>()),
      );

      var nested = 'Content-Type: text/plain\r\n\r\nhello';
      for (var index = 0; index <= MimeDecoder.maxMultipartDepth; index++) {
        nested = 'Content-Type: multipart/mixed; boundary="b$index"\r\n\r\n'
            '--b$index\r\n$nested\r\n--b$index--\r\n';
      }
      expect(
        () => MimeDecoder.parseRfc822(Uint8List.fromList(utf8.encode(nested))),
        throwsA(isA<ImapProtocolException>()),
      );
    });
  });
}
