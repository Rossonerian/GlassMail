import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail/app/mail_link_preview.dart';

void main() {
  test('preview URLs are HTTPS on the default port without credentials', () {
    final normalized = MailLinkPreviewService.normalizeUri(
      Uri.parse('HTTPS://Example.com/a?token=abc#fragment'),
    );
    expect(normalized.toString(), 'https://example.com/a?token=abc');

    for (final value in [
      'http://example.com/',
      'https://example.com:8443/',
      'https://user:secret@example.com/',
      'https://localhost/',
      'https://sub.localhost/',
      'https://127.0.0.1/',
      'https://[::1]/',
    ]) {
      expect(
        () => MailLinkPreviewService.normalizeUri(Uri.parse(value)),
        throwsA(isA<LinkPreviewException>()),
        reason: value,
      );
    }
  });

  test('refuses a hostname if any DNS answer is non-public', () async {
    var fetched = false;
    final service = MailLinkPreviewService(
      lookup: (_) async => [_address('93.184.216.34'), _address('192.168.1.5')],
      htmlFetcher: (_, _) async {
        fetched = true;
        return _htmlResponse('<title>Not fetched</title>');
      },
    );

    await expectLater(
      service.fetch(Uri.parse('https://example.com/')),
      throwsA(isA<LinkPreviewException>()),
    );
    expect(fetched, isFalse);
  });

  test('parses only small page metadata from an HTML response', () async {
    Uri? requestedUri;
    InternetAddress? pinnedAddress;
    final service = MailLinkPreviewService(
      lookup: (_) async => [_address('93.184.216.34')],
      htmlFetcher: (uri, address) async {
        requestedUri = uri;
        pinnedAddress = address;
        return _htmlResponse('''
          <html><head>
            <title>Fallback title</title>
            <meta property="og:title" content="A &amp; B">
            <meta property="og:site_name" content="Example">
            <meta name="description" content="  A short\n description  ">
            <meta property="og:image" content="https://tracker.test/image.png">
          </head><body><script>must not run()</script></body></html>
        ''');
      },
    );

    final preview = await service.fetch(
      Uri.parse('https://Example.com/path#not-sent'),
    );

    expect(requestedUri.toString(), 'https://example.com/path');
    expect(pinnedAddress, _address('93.184.216.34'));
    expect(preview.title, 'A & B');
    expect(preview.siteName, 'Example');
    expect(preview.description, 'A short description');
    expect(preview.uri.toString(), 'https://example.com/path');
  });

  test('rejects redirects, non-HTML responses, and oversized documents', () {
    final cases = [
      LinkPreviewHttpResponse(
        statusCode: HttpStatus.found,
        contentType: 'text/html',
        body: utf8.encode('<title>Redirect</title>'),
      ),
      LinkPreviewHttpResponse(
        statusCode: HttpStatus.ok,
        contentType: 'image/png',
        body: const [],
      ),
      LinkPreviewHttpResponse(
        statusCode: HttpStatus.ok,
        contentType: 'text/html',
        body: List<int>.filled(MailLinkPreviewService.maxHtmlBytes + 1, 32),
      ),
    ];

    for (final response in cases) {
      final service = MailLinkPreviewService(
        lookup: (_) async => [_address('93.184.216.34')],
        htmlFetcher: (_, _) async => response,
      );
      expect(
        service.fetch(Uri.parse('https://example.com/')),
        throwsA(isA<LinkPreviewException>()),
      );
    }
  });
}

InternetAddress _address(String value) => InternetAddress.tryParse(value)!;

LinkPreviewHttpResponse _htmlResponse(String text) => LinkPreviewHttpResponse(
  statusCode: HttpStatus.ok,
  contentType: 'text/html; charset=utf-8',
  body: utf8.encode(text),
);
