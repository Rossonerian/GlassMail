import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html;

typedef HostLookup = Future<List<InternetAddress>> Function(String host);
typedef LinkPreviewHtmlFetcher = Future<LinkPreviewHttpResponse> Function(
  Uri uri,
  InternetAddress pinnedAddress,
);

/// Bounded metadata from one user-requested HTTPS page.
final class MailLinkPreview {
  const MailLinkPreview({
    required this.uri,
    required this.title,
    required this.siteName,
    this.description,
  });

  final Uri uri;
  final String title;
  final String siteName;
  final String? description;
}

/// A small response boundary that keeps link-preview parsing easy to test.
final class LinkPreviewHttpResponse {
  const LinkPreviewHttpResponse({
    required this.statusCode,
    required this.contentType,
    required this.body,
  });

  final int statusCode;
  final String? contentType;
  final List<int> body;
}

final class LinkPreviewException implements Exception {
  const LinkPreviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fetches only a bounded HTML document from a public HTTPS endpoint.
///
/// Callers must obtain explicit consent before calling [fetch]. DNS results
/// are checked and pinned to the socket, redirects are disabled, and only page
/// metadata is parsed. The response's scripts, styles, images, and links are
/// never executed or fetched.
final class MailLinkPreviewService {
  MailLinkPreviewService({
    HostLookup? lookup,
    LinkPreviewHtmlFetcher? htmlFetcher,
  }) : _lookup = lookup ?? ((host) => InternetAddress.lookup(host)),
       _htmlFetcher = htmlFetcher ?? _fetchHtml;

  static const maxUrlLength = 2048;
  static const maxHtmlBytes = 128 * 1024;
  static const _maxDnsAnswers = 16;
  static const _operationTimeout = Duration(seconds: 8);

  final HostLookup _lookup;
  final LinkPreviewHtmlFetcher _htmlFetcher;

  /// Normalizes the one URL shape the preview transport accepts.
  static Uri normalizeUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!uri.isAbsolute ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        host.isEmpty ||
        uri.port != 443 ||
        uri.toString().length > maxUrlLength ||
        InternetAddress.tryParse(host) != null ||
        _isLocalHostName(host)) {
      throw const LinkPreviewException(
        'Only public HTTPS links on port 443 can be previewed.',
      );
    }
    return uri.replace(scheme: 'https', host: host, fragment: '');
  }

  Future<MailLinkPreview> fetch(Uri uri) async {
    final safeUri = normalizeUri(uri);
    late final List<InternetAddress> addresses;
    try {
      addresses = await _lookup(safeUri.host).timeout(_operationTimeout);
    } on Object {
      throw const LinkPreviewException(
        'The destination could not be resolved safely.',
      );
    }
    if (addresses.isEmpty ||
        addresses.length > _maxDnsAnswers ||
        addresses.any((address) => !_isPublicInternetAddress(address))) {
      throw const LinkPreviewException(
        'The destination is not a public Internet host.',
      );
    }

    final response = await _htmlFetcher(safeUri, addresses.first);
    if (response.statusCode != HttpStatus.ok) {
      throw const LinkPreviewException(
        'The destination did not return a previewable page.',
      );
    }
    final contentType = response.contentType
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (contentType != 'text/html' && contentType != 'application/xhtml+xml') {
      throw const LinkPreviewException(
        'The destination did not return an HTML page.',
      );
    }
    if (response.body.length > maxHtmlBytes) {
      throw const LinkPreviewException('The preview page is too large.');
    }

    final document = html.parse(
      utf8.decode(response.body, allowMalformed: true),
    );
    final title =
        _firstMetadataValue(document, const [
          'meta[property="og:title"]',
          'meta[name="twitter:title"]',
        ]) ??
        document.querySelector('title')?.text;
    final description = _firstMetadataValue(document, const [
      'meta[property="og:description"]',
      'meta[name="description"]',
      'meta[name="twitter:description"]',
    ]);
    final siteName = _firstMetadataValue(document, const [
      'meta[property="og:site_name"]',
      'meta[name="application-name"]',
    ]);

    return MailLinkPreview(
      uri: safeUri,
      title: _cleanText(title, limit: 180) ?? safeUri.host,
      siteName: _cleanText(siteName, limit: 80) ?? safeUri.host,
      description: _cleanText(description, limit: 360),
    );
  }

  static String? _firstMetadataValue(
    html_dom.Document document,
    List<String> selectors,
  ) {
    for (final selector in selectors) {
      final value = document.querySelector(selector)?.attributes['content'];
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static String? _cleanText(String? text, {required int limit}) {
    if (text == null) return null;
    final clean = text
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return null;
    return String.fromCharCodes(clean.runes.take(limit));
  }

  static bool _isLocalHostName(String host) {
    return host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.endsWith('.test') ||
        host.endsWith('.invalid') ||
        host.endsWith('.example');
  }

  static bool _isPublicInternetAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      final a = bytes[0];
      final b = bytes[1];
      final c = bytes[2];
      if (a == 0 ||
          a == 10 ||
          a == 127 ||
          a >= 224 ||
          (a == 100 && b >= 64 && b <= 127) ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 0 && c == 0) ||
          (a == 192 && b == 0 && c == 2) ||
          (a == 192 && b == 88 && c == 99) ||
          (a == 192 && b == 168) ||
          (a == 198 && (b == 18 || b == 19)) ||
          (a == 198 && b == 51 && c == 100) ||
          (a == 203 && b == 0 && c == 113)) {
        return false;
      }
      return true;
    }

    if (address.type != InternetAddressType.IPv6 || bytes.length != 16) {
      return false;
    }
    final isUnspecifiedOrMapped =
        bytes.take(10).every((byte) => byte == 0) &&
        (bytes[10] == 0 && bytes[11] == 0 ||
            bytes[10] == 0xff && bytes[11] == 0xff);
    final isGlobalUnicast = (bytes[0] & 0xe0) == 0x20;
    final isDocumentation =
        (bytes[0] == 0x20 &&
            bytes[1] == 0x01 &&
            bytes[2] == 0x0d &&
            bytes[3] == 0xb8) ||
        (bytes[0] == 0x3f && (bytes[1] & 0xf0) == 0xf0);
    final isTransitionOrTranslation =
        (bytes[0] == 0x20 && bytes[1] == 0x02) ||
        (bytes[0] == 0x00 &&
            bytes[1] == 0x64 &&
            bytes[2] == 0xff &&
            bytes[3] == 0x9b);
    final isIetfSpecialPurpose =
        bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] <= 0x01;
    return isGlobalUnicast &&
        !isUnspecifiedOrMapped &&
        !isDocumentation &&
        !isTransitionOrTranslation &&
        !isIetfSpecialPurpose;
  }

  static Future<LinkPreviewHttpResponse> _fetchHtml(
    Uri uri,
    InternetAddress pinnedAddress,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 2)
      ..maxConnectionsPerHost = 1
      ..autoUncompress = false;
    client.connectionFactory = (requestUri, proxyHost, proxyPort) {
      if (proxyHost != null ||
          proxyPort != null ||
          requestUri.scheme != 'https' ||
          requestUri.host != uri.host ||
          requestUri.port != 443) {
        throw const LinkPreviewException(
          'The preview connection could not be pinned safely.',
        );
      }
      return Socket.startConnect(pinnedAddress, 443);
    };

    try {
      final request = await client.getUrl(uri).timeout(_operationTimeout);
      request
        ..followRedirects = false
        ..maxRedirects = 0
        ..persistentConnection = false;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'text/html, application/xhtml+xml')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache, no-store')
        ..set(HttpHeaders.userAgentHeader, 'GlassMail Link Preview')
        ..removeAll(HttpHeaders.acceptEncodingHeader)
        ..removeAll(HttpHeaders.cookieHeader)
        ..removeAll(HttpHeaders.refererHeader);
      final response = await request.close().timeout(_operationTimeout);
      final contentType = response.headers.contentType?.mimeType;
      if (response.statusCode != HttpStatus.ok ||
          contentType == null ||
          (contentType != 'text/html' &&
              contentType != 'application/xhtml+xml') ||
          response.contentLength > maxHtmlBytes) {
        return LinkPreviewHttpResponse(
          statusCode: response.statusCode,
          contentType: contentType,
          body: const [],
        );
      }

      final body = await _readBoundedBody(response).timeout(_operationTimeout);
      return LinkPreviewHttpResponse(
        statusCode: response.statusCode,
        contentType: contentType,
        body: body,
      );
    } on TimeoutException {
      throw const LinkPreviewException('The preview request timed out.');
    } on LinkPreviewException {
      rethrow;
    } on Object {
      throw const LinkPreviewException('The preview could not be loaded.');
    } finally {
      client.close(force: true);
    }
  }

  static Future<Uint8List> _readBoundedBody(HttpClientResponse response) async {
    final bytes = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in response) {
      total += chunk.length;
      if (total > maxHtmlBytes) {
        throw const LinkPreviewException('The preview page is too large.');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }
}
