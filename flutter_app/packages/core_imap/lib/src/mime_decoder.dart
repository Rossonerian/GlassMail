import 'dart:convert';
import 'dart:typed_data';

import 'imap_protocol.dart';

final class ParsedAttachmentInfo {
  const ParsedAttachmentInfo({
    required this.partId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String partId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
}

final class ParsedMessageBody {
  ParsedMessageBody({
    required this.plainText,
    required this.htmlText,
    required this.previewSnippet,
    Map<String, String> headers = const {},
    List<ParsedAttachmentInfo> attachments = const [],
  })  : headers = Map.unmodifiable(headers),
        attachments = List.unmodifiable(attachments);

  final String? plainText;
  final String? htmlText;
  final String previewSnippet;
  final Map<String, String> headers;
  final List<ParsedAttachmentInfo> attachments;
}

/// Small RFC 822 body decoder ported from the current Kotlin implementation.
/// Input is bounded to the IMAP literal limit before it is copied or parsed.
abstract final class MimeDecoder {
  static const int maxMessageBytes = maxImapLiteralBytes;
  static const int maxMimeHeaderBytes = maxImapLineBytes;
  static const int maxMultipartParts = 500;
  static const int maxMultipartDepth = 16;

  static final _encodedWord = RegExp(
    r'=\?([A-Za-z0-9_-]+)\?([BbQq])\?([^?]+)\?=',
  );

  static String decodeMimeWords(String? input) {
    if (input == null || input.trim().isEmpty || !input.contains('=?')) {
      return input ?? '';
    }
    final normalized = input.replaceAll(RegExp(r'(\?=\s+=\?)'), '?==?');
    return normalized.replaceAllMapped(_encodedWord, (match) {
      final charset = match.group(1)!;
      final encoding = match.group(2)!.toUpperCase();
      final encoded = match.group(3)!;
      try {
        final bytes = switch (encoding) {
          'B' => Uint8List.fromList(
              base64.decode(encoded.replaceAll(RegExp(r'\s'), ''))),
          'Q' => _decodeQuotedPrintableBytes(encoded, header: true),
          _ => null,
        };
        return bytes == null ? match[0]! : _decodeCharset(bytes, charset);
      } on Object {
        return match[0]!;
      }
    });
  }

  static ParsedMessageBody parseRfc822(Uint8List rawBytes) {
    if (rawBytes.length > maxMessageBytes) {
      throw const ImapProtocolException('RFC 822 message exceeds 8 MiB limit');
    }
    final content = latin1.decode(rawBytes);
    final headerEnd = _findHeaderEnd(content);
    final headerSection = headerEnd > 0 ? content.substring(0, headerEnd) : '';
    _checkHeaderSize(headerSection);
    final bodySection = headerEnd > 0 ? content.substring(headerEnd) : content;
    final headers = _parseHeaders(headerSection);
    final contentType = headers['content-type'] ?? 'text/plain; charset=utf-8';
    final transferEncoding =
        headers['content-transfer-encoding']?.toLowerCase().trim() ?? '7bit';
    final parsed = _parseBodyParts(
      contentType,
      transferEncoding,
      bodySection,
      depth: 0,
      partId: '',
    );

    final cleanPlain = parsed.plainText == null
        ? null
        : _normalizeWhitespace(parsed.plainText!);
    final cleanHtmlText =
        parsed.htmlText == null ? null : htmlToPlainText(parsed.htmlText!);
    final bestText = cleanPlain?.trim().isNotEmpty == true
        ? cleanPlain!
        : cleanHtmlText?.trim().isNotEmpty == true
            ? cleanHtmlText!
            : '';

    return ParsedMessageBody(
      plainText: cleanPlain ?? cleanHtmlText,
      htmlText: parsed.htmlText,
      previewSnippet: generateSnippet(bestText),
      headers: headers,
      attachments: parsed.attachments,
    );
  }

  static String htmlToPlainText(String html) {
    var text = html
        .replaceAll(
          RegExp(r'<style.*?>.*?</style>', caseSensitive: false, dotAll: true),
          '',
        )
        .replaceAll(
          RegExp(r'<script.*?>.*?</script>',
              caseSensitive: false, dotAll: true),
          '',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</?(p|div|tr|h[1-6]|li)[^>]*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1)!);
      return code != null && _validCodePoint(code)
          ? String.fromCharCode(code)
          : match[0]!;
    });
    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1)!, radix: 16);
      return code != null && _validCodePoint(code)
          ? String.fromCharCode(code)
          : match[0]!;
    });
    return _normalizeWhitespace(text);
  }

  static String generateSnippet(String text, {int maxLength = 160}) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= maxLength) return singleLine;
    final truncated = singleLine.substring(0, maxLength);
    final lastSpace = truncated.lastIndexOf(' ');
    return lastSpace > maxLength ~/ 2
        ? '${truncated.substring(0, lastSpace)}…'
        : '$truncated…';
  }

  static _ParsedBodyParts _parseBodyParts(
    String contentType,
    String transferEncoding,
    String rawBody, {
    required int depth,
    required String partId,
    Map<String, String> headers = const {},
  }) {
    if (depth > maxMultipartDepth) {
      throw const ImapProtocolException('MIME nesting exceeds 16 levels');
    }
    final mimeType = contentType.split(';').first.trim().toLowerCase();
    if (mimeType.startsWith('multipart/')) {
      final boundary = _extractParameter(contentType, 'boundary');
      if (boundary != null && boundary.isNotEmpty) {
        return _parseMultipart(
          rawBody,
          boundary,
          depth: depth + 1,
          partId: partId,
        );
      }
    }
    final disposition = headers['content-disposition'] ?? '';
    final fileName = _extractParameter(disposition, 'filename') ??
        _extractParameter(contentType, 'name');
    final isAttachment = fileName != null ||
        disposition.toLowerCase().startsWith('attachment') ||
        (!mimeType.startsWith('text/') && !mimeType.startsWith('multipart/'));
    if (isAttachment && partId.isNotEmpty) {
      return _ParsedBodyParts(
        attachments: [
          ParsedAttachmentInfo(
            partId: partId,
            fileName: decodeMimeWords(fileName),
            mimeType: mimeType,
            sizeBytes: _decodedSize(rawBody, transferEncoding),
          ),
        ],
      );
    }
    final decoded = _decodeTransferEncoding(
      rawBody,
      transferEncoding,
      _extractCharset(contentType),
    );
    return mimeType == 'text/html'
        ? _ParsedBodyParts(htmlText: decoded)
        : _ParsedBodyParts(plainText: decoded);
  }

  static _ParsedBodyParts _parseMultipart(
    String body,
    String boundary, {
    required int depth,
    required String partId,
  }) {
    final marker = '--$boundary';
    final parts = _splitMultipartBounded(body, marker);
    String? bestPlain;
    String? bestHtml;
    final attachments = <ParsedAttachmentInfo>[];
    var childIndex = 0;
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty || trimmed == '--') continue;
      childIndex++;
      final headerEnd = _findHeaderEnd(trimmed);
      final headerSection =
          headerEnd > 0 ? trimmed.substring(0, headerEnd) : '';
      _checkHeaderSize(headerSection);
      final bodySection =
          headerEnd > 0 ? trimmed.substring(headerEnd) : trimmed;
      final headers = _parseHeaders(headerSection);
      final childPartId =
          partId.isEmpty ? '$childIndex' : '$partId.$childIndex';
      final parsed = _parseBodyParts(
        headers['content-type'] ?? 'text/plain',
        headers['content-transfer-encoding']?.toLowerCase().trim() ?? '7bit',
        bodySection,
        depth: depth,
        partId: childPartId,
        headers: headers,
      );
      bestPlain ??= parsed.plainText;
      bestHtml ??= parsed.htmlText;
      attachments.addAll(parsed.attachments);
    }
    return _ParsedBodyParts(
      plainText: bestPlain,
      htmlText: bestHtml,
      attachments: attachments,
    );
  }

  static int _decodedSize(String content, String encoding) {
    switch (encoding.toLowerCase().trim()) {
      case 'base64':
        try {
          return base64.decode(content.replaceAll(RegExp(r'\s'), '')).length;
        } on FormatException {
          return 0;
        }
      case 'quoted-printable':
        return _decodeQuotedPrintableBytes(content).length;
      default:
        return latin1.encode(content).length;
    }
  }

  static String _decodeTransferEncoding(
    String content,
    String encoding,
    String charset,
  ) {
    final bytes = latin1.encode(content);
    switch (encoding) {
      case 'quoted-printable':
        return _decodeCharset(_decodeQuotedPrintableBytes(content), charset);
      case 'base64':
        try {
          return _decodeCharset(
              base64.decode(content.replaceAll(RegExp(r'\s'), '')), charset);
        } on Object {
          return content;
        }
      default:
        return _decodeCharset(bytes, charset);
    }
  }

  static Uint8List _decodeQuotedPrintableBytes(
    String input, {
    bool header = false,
  }) {
    final output = BytesBuilder(copy: false);
    var index = 0;
    while (index < input.length) {
      final character = input.codeUnitAt(index);
      if (header && character == 0x5f) {
        output.addByte(0x20);
        index++;
      } else if (character == 0x3d) {
        if (index + 1 < input.length &&
            (input[index + 1] == '\r' || input[index + 1] == '\n')) {
          index++;
          if (index < input.length && input[index] == '\r') index++;
          if (index < input.length && input[index] == '\n') index++;
        } else if (index + 2 < input.length) {
          final byte =
              int.tryParse(input.substring(index + 1, index + 3), radix: 16);
          if (byte == null) {
            output.addByte(character);
            index++;
          } else {
            output.addByte(byte);
            index += 3;
          }
        } else {
          output.addByte(character);
          index++;
        }
      } else {
        output.addByte(character & 0xff);
        index++;
      }
    }
    return output.takeBytes();
  }

  static String _decodeCharset(List<int> bytes, String charset) {
    final normalized = charset.toLowerCase().replaceAll('_', '-');
    return switch (normalized) {
      'iso-8859-1' ||
      'latin1' ||
      'latin-1' ||
      'iso8859-1' =>
        latin1.decode(bytes),
      'windows-1252' || 'cp1252' => _decodeWindows1252(bytes),
      'us-ascii' || 'ascii' => ascii.decode(bytes, allowInvalid: true),
      'utf-16' => _decodeUtf16(bytes),
      'utf-16le' => _decodeUtf16(bytes, defaultLittleEndian: true),
      'utf-16be' => _decodeUtf16(bytes, defaultLittleEndian: false),
      _ => utf8.decode(bytes, allowMalformed: true),
    };
  }

  static String _decodeUtf16(
    List<int> bytes, {
    bool? defaultLittleEndian,
  }) {
    var offset = 0;
    var littleEndian = defaultLittleEndian ?? false;
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
      littleEndian = true;
      offset = 2;
    } else if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
      littleEndian = false;
      offset = 2;
    }
    final codeUnits = <int>[];
    for (var index = offset; index + 1 < bytes.length; index += 2) {
      final first = bytes[index];
      final second = bytes[index + 1];
      codeUnits
          .add(littleEndian ? first | (second << 8) : (first << 8) | second);
    }
    return String.fromCharCodes(codeUnits);
  }

  static String _decodeWindows1252(List<int> bytes) {
    const windows1252 = <int>[
      0x20ac,
      0x0081,
      0x201a,
      0x0192,
      0x201e,
      0x2026,
      0x2020,
      0x2021,
      0x02c6,
      0x2030,
      0x0160,
      0x2039,
      0x0152,
      0x008d,
      0x017d,
      0x008f,
      0x0090,
      0x2018,
      0x2019,
      0x201c,
      0x201d,
      0x2022,
      0x2013,
      0x2014,
      0x02dc,
      0x2122,
      0x0161,
      0x203a,
      0x0153,
      0x009d,
      0x017e,
      0x0178,
    ];
    return String.fromCharCodes(bytes.map((byte) =>
        byte >= 0x80 && byte <= 0x9f ? windows1252[byte - 0x80] : byte));
  }

  static String _extractCharset(String contentType) =>
      _extractParameter(contentType, 'charset') ?? 'utf-8';

  static String? _extractParameter(String header, String name) {
    final parameter = RegExp(
      '${RegExp.escape(name)}="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(header);
    return parameter?.group(1)?.trim();
  }

  static int _findHeaderEnd(String content) {
    final crlf = content.indexOf('\r\n\r\n');
    if (crlf >= 0) return crlf + 4;
    final lf = content.indexOf('\n\n');
    return lf >= 0 ? lf + 2 : -1;
  }

  static Map<String, String> _parseHeaders(String section) {
    final headers = <String, String>{};
    String? currentName;
    final currentValue = StringBuffer();
    void flush() {
      if (currentName != null) {
        headers[currentName!.toLowerCase()] = currentValue.toString();
      }
      currentName = null;
      currentValue.clear();
    }

    for (final line in const LineSplitter().convert(section)) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (currentName != null) currentValue.write(' ${line.trim()}');
        continue;
      }
      flush();
      final colon = line.indexOf(':');
      if (colon >= 0) {
        currentName = line.substring(0, colon).trim();
        currentValue.write(line.substring(colon + 1).trim());
      }
    }
    flush();
    return headers;
  }

  static List<String> _splitMultipartBounded(String body, String marker) {
    final parts = <String>[];
    var start = 0;
    var boundary = body.indexOf(marker);
    while (boundary >= 0) {
      parts.add(body.substring(start, boundary));
      if (parts.length > maxMultipartParts + 1) {
        throw const ImapProtocolException(
          'MIME message contains too many parts',
        );
      }
      start = boundary + marker.length;
      boundary = body.indexOf(marker, start);
    }
    parts.add(body.substring(start));
    if (parts.length > maxMultipartParts + 2) {
      throw const ImapProtocolException('MIME message contains too many parts');
    }
    return parts;
  }

  static void _checkHeaderSize(String header) {
    if (header.length > maxMimeHeaderBytes) {
      throw const ImapProtocolException('MIME headers exceed 64 KiB limit');
    }
  }

  static String _normalizeWhitespace(String text) {
    final output = <String>[];
    var previousEmpty = false;
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (!previousEmpty && output.isNotEmpty) {
          output.add('');
          previousEmpty = true;
        }
      } else {
        output.add(line);
        previousEmpty = false;
      }
    }
    return output.join('\n').trim();
  }

  static bool _validCodePoint(int code) =>
      code >= 0 && code <= 0x10ffff && (code < 0xd800 || code > 0xdfff);
}

final class _ParsedBodyParts {
  _ParsedBodyParts({
    this.plainText,
    this.htmlText,
    List<ParsedAttachmentInfo> attachments = const [],
  }) : attachments = List.unmodifiable(attachments);

  final String? plainText;
  final String? htmlText;
  final List<ParsedAttachmentInfo> attachments;
}
