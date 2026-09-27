import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

const int maxImapLineBytes = 64 * 1024;
const int maxImapLiteralBytes = 8 * 1024 * 1024;
const int maxImapNestingDepth = 64;

sealed class ImapValue {
  const ImapValue();
}

final class ImapAtom extends ImapValue {
  const ImapAtom(this.value);

  final String value;
}

final class ImapQuoted extends ImapValue {
  const ImapQuoted(this.value);

  final String value;
}

final class ImapLiteral extends ImapValue {
  ImapLiteral(List<int> bytes) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
}

final class ImapValueList extends ImapValue {
  ImapValueList(Iterable<ImapValue> values)
      : values = List<ImapValue>.unmodifiable(values);

  final List<ImapValue> values;
}

final class ImapNil extends ImapValue {
  const ImapNil();
}

sealed class ImapResponse {
  const ImapResponse();
}

final class ImapUntagged extends ImapResponse {
  ImapUntagged(Iterable<ImapValue> values)
      : values = List<ImapValue>.unmodifiable(values);

  final List<ImapValue> values;
}

final class ImapTagged extends ImapResponse {
  ImapTagged({
    required this.tag,
    required this.status,
    required Iterable<ImapValue> values,
  }) : values = List<ImapValue>.unmodifiable(values);

  final String tag;
  final String status;
  final List<ImapValue> values;
}

final class ImapContinuation extends ImapResponse {
  const ImapContinuation(this.text);

  final String text;
}

final class ImapProtocolException implements Exception {
  const ImapProtocolException(this.message);

  final String message;

  @override
  String toString() => 'ImapProtocolException: $message';
}

extension ImapValueAccess on ImapValue {
  String? get atomValue => switch (this) {
        ImapAtom(:final value) => value,
        ImapQuoted(:final value) => value,
        _ => null,
      };

  Uint8List? get literalValue =>
      this is ImapLiteral ? (this as ImapLiteral).bytes : null;

  List<ImapValue> get listValue =>
      this is ImapValueList ? (this as ImapValueList).values : const [];
}

extension ImapValueAttributes on List<ImapValue> {
  ImapValue? attribute(String name) {
    final index = indexWhere(
      (value) => value.atomValue?.toLowerCase() == name.toLowerCase(),
    );
    return index < 0 || index + 1 >= length ? null : this[index + 1];
  }
}

abstract final class ImapResponseParser {
  static final _literalReference = RegExp(r'\{(\d+)\+?\}$');
  static final _malformedLiteralSuffix = RegExp(r'\{[^{}\r\n]*\}$');

  static ImapResponse parse(String line, List<Uint8List> literals) {
    if (line.trim().isEmpty) {
      throw const ImapProtocolException('Empty IMAP response');
    }
    if (line.startsWith('+')) {
      return ImapContinuation(line.substring(1).trimLeft());
    }
    if (line.startsWith('* ')) {
      return ImapUntagged(_ValueParser(line.substring(2), literals).parseAll());
    }

    final values = _ValueParser(line, literals).parseAll();
    if (values.length < 2) {
      throw const ImapProtocolException('Malformed tagged IMAP response');
    }
    final tag = values[0].atomValue;
    final status = values[1].atomValue;
    if (tag == null || status == null) {
      throw const ImapProtocolException('Invalid IMAP tag or status');
    }
    return ImapTagged(tag: tag, status: status, values: values.skip(2));
  }
}

/// Reads complete logical responses from the byte stream, including literals
/// split across arbitrary socket packets. One reader must own a socket stream.
final class ImapResponseReader {
  ImapResponseReader(Stream<List<int>> chunks)
      : _iterator = StreamIterator<List<int>>(chunks);

  final StreamIterator<List<int>> _iterator;
  List<int> _chunk = const [];
  int _position = 0;

  Future<ImapResponse> readResponse() async {
    final literals = <Uint8List>[];
    final response = StringBuffer();
    var totalLiteralBytes = 0;
    var line = await _readLine();

    while (true) {
      final marker = ImapResponseParser._literalReference.firstMatch(line);
      if (marker == null) {
        if (ImapResponseParser._malformedLiteralSuffix.hasMatch(line)) {
          throw const ImapProtocolException('Invalid IMAP literal marker');
        }
        response.write(line);
        break;
      }
      final length = int.tryParse(marker.group(1)!);
      if (length == null || length < 0 || length > maxImapLiteralBytes) {
        throw const ImapProtocolException('IMAP literal exceeds 8 MiB limit');
      }
      if (totalLiteralBytes + length > maxImapLiteralBytes) {
        throw const ImapProtocolException(
          'IMAP response literals exceed 8 MiB limit',
        );
      }
      totalLiteralBytes += length;
      response.write(line.substring(0, marker.start));
      literals.add(await _readExactly(length));
      response
        ..write(' ')
        ..write('\u0000L${literals.length - 1}\u0000');
      line = await _readLine();
    }

    return ImapResponseParser.parse(response.toString(), literals);
  }

  Future<void> cancel() => _iterator.cancel();

  Future<String> _readLine() async {
    final bytes = BytesBuilder(copy: false);
    while (true) {
      final next = await _readByte();
      if (next == 0x0a) {
        final line = bytes.takeBytes().toList();
        if (line.isNotEmpty && line.last == 0x0d) {
          line.removeLast();
        }
        return utf8.decode(line, allowMalformed: true);
      }
      if (bytes.length >= maxImapLineBytes) {
        throw const ImapProtocolException('IMAP response line exceeds 64 KiB');
      }
      bytes.addByte(next);
    }
  }

  Future<Uint8List> _readExactly(int length) async {
    final bytes = Uint8List(length);
    var offset = 0;
    while (offset < length) {
      final available = await _readAvailableChunk();
      if (available == null) {
        throw const ImapProtocolException(
          'IMAP server disconnected in literal',
        );
      }
      final count = (length - offset).clamp(0, _chunk.length - _position);
      bytes.setRange(offset, offset + count, _chunk, _position);
      offset += count;
      _position += count;
    }
    return bytes;
  }

  Future<int> _readByte() async {
    final available = await _readAvailableChunk();
    if (available == null) {
      throw const ImapProtocolException('IMAP server disconnected');
    }
    return _chunk[_position++];
  }

  Future<bool?> _readAvailableChunk() async {
    while (_position >= _chunk.length) {
      if (!await _iterator.moveNext()) return null;
      _chunk = _iterator.current;
      _position = 0;
      if (_chunk.isEmpty) continue;
    }
    return true;
  }
}

final class _ValueParser {
  _ValueParser(this._input, this._literals);

  final String _input;
  final List<Uint8List> _literals;
  int _position = 0;
  int _responseCodeDepth = 0;
  int _valueDepth = 0;

  List<ImapValue> parseAll() {
    final values = <ImapValue>[];
    _skipWhitespace();
    while (_position < _input.length) {
      values.add(_parseValue());
      _skipWhitespace();
    }
    return values;
  }

  ImapValue _parseValue() {
    if (_position >= _input.length) {
      throw const ImapProtocolException('Unexpected end of IMAP response');
    }
    return switch (_input[_position]) {
      '(' => _parseList('(', ')'),
      '[' => _parseResponseCode(),
      '"' => ImapQuoted(_parseQuoted()),
      '\u0000' => _parseLiteralReference(),
      _ => _parseAtom(),
    };
  }

  ImapValue _parseResponseCode() {
    _responseCodeDepth++;
    final value = _parseList('[', ']');
    _responseCodeDepth--;
    return value;
  }

  ImapValueList _parseList(String opening, String closing) {
    _valueDepth++;
    if (_valueDepth > maxImapNestingDepth) {
      throw const ImapProtocolException('IMAP response nesting exceeds 64');
    }
    _position++;
    final values = <ImapValue>[];
    try {
      _skipWhitespace();
      while (_position < _input.length && _input[_position] != closing) {
        values.add(_parseValue());
        _skipWhitespace();
      }
      if (_position >= _input.length || _input[_position] != closing) {
        throw ImapProtocolException('Unterminated IMAP $opening list');
      }
      _position++;
      return ImapValueList(values);
    } finally {
      _valueDepth--;
    }
  }

  String _parseQuoted() {
    _position++;
    final value = StringBuffer();
    while (_position < _input.length) {
      final character = _input[_position++];
      if (character == '"') return value.toString();
      if (character == '\\') {
        if (_position >= _input.length) {
          throw const ImapProtocolException('Invalid quoted IMAP string');
        }
        value.write(_input[_position++]);
      } else {
        value.write(character);
      }
    }
    throw const ImapProtocolException('Unterminated IMAP quoted string');
  }

  ImapLiteral _parseLiteralReference() {
    final start = _position;
    final end = _input.indexOf('\u0000', start + 1);
    if (end <= start) {
      throw const ImapProtocolException('Invalid IMAP literal marker');
    }
    final marker = _input.substring(start + 1, end);
    if (!marker.startsWith('L')) {
      throw const ImapProtocolException('Invalid IMAP literal marker');
    }
    final index = int.tryParse(marker.substring(1));
    if (index == null || index < 0 || index >= _literals.length) {
      throw const ImapProtocolException('Invalid IMAP literal reference');
    }
    _position = end + 1;
    return ImapLiteral(_literals[index]);
  }

  ImapValue _parseAtom() {
    final start = _position;
    var sectionDepth = 0;
    while (_position < _input.length) {
      final character = _input[_position];
      if (sectionDepth > 0) {
        if (character == '[') sectionDepth++;
        if (character == ']') sectionDepth--;
        _position++;
        continue;
      }
      if (_responseCodeDepth == 0 && character == '[') {
        sectionDepth = 1;
        _position++;
        continue;
      }
      if (character.trim().isEmpty ||
          character == '(' ||
          character == ')' ||
          (_responseCodeDepth > 0 && character == ']')) {
        break;
      }
      _position++;
    }
    if (start == _position) {
      throw const ImapProtocolException('Invalid IMAP atom');
    }
    if (sectionDepth != 0) {
      throw const ImapProtocolException('Unterminated IMAP body section');
    }
    final value = _input.substring(start, _position);
    return value.toUpperCase() == 'NIL' ? const ImapNil() : ImapAtom(value);
  }

  void _skipWhitespace() {
    while (_position < _input.length && _input[_position].trim().isEmpty) {
      _position++;
    }
  }
}
