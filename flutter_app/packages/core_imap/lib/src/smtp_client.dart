import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const int maxSmtpMessageBytes = 24 * 1024 * 1024;
const int maxSmtpLineBytes = 64 * 1024;
const Duration defaultSmtpTimeout = Duration(seconds: 30);

final class SmtpProtocolException implements Exception {
  const SmtpProtocolException(this.message);

  final String message;

  @override
  String toString() => 'SmtpProtocolException: $message';
}

final class SmtpTransportException implements Exception {
  const SmtpTransportException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SmtpTransportException: $message';
}

final class SmtpAuthenticationException implements Exception {
  const SmtpAuthenticationException();

  @override
  String toString() => 'SMTP authentication failed';
}

final class SmtpRejectedException implements Exception {
  const SmtpRejectedException(this.code);

  final int code;

  @override
  String toString() => 'SMTP server rejected the message ($code)';
}

/// The server may have accepted DATA even though the final reply was lost.
final class SmtpUncertainDeliveryException implements Exception {
  const SmtpUncertainDeliveryException(this.cause);

  final Object cause;

  @override
  String toString() => 'SMTP delivery outcome is uncertain';
}

abstract interface class SmtpWireConnection {
  Future<SmtpReply> readReply({Duration? timeout});
  Future<void> writeLine(String line);
  Future<void> writeData(Uint8List bytes);
  Future<void> startTls(String host);
  Future<void> close();
}

final class SmtpReply {
  SmtpReply({required this.code, required Iterable<String> lines})
    : lines = List.unmodifiable(lines);

  final int code;
  final List<String> lines;
}

/// SMTP submission over mandatory STARTTLS. It never disables certificate or
/// hostname validation. A disconnect after DATA is reported as uncertain.
final class SmtpClient {
  SmtpClient(this._wire);

  final SmtpWireConnection _wire;

  static Future<SmtpClient> connect({
    String host = 'smtp.gmail.com',
    int port = 587,
    Duration timeout = defaultSmtpTimeout,
  }) async {
    final wire = await _SocketSmtpWire.connect(
      host: host,
      port: port,
      timeout: timeout,
    );
    try {
      return await SmtpClient.negotiateStartTls(
        wire,
        host: host,
        timeout: timeout,
      );
    } on Object {
      await wire.close();
      rethrow;
    }
  }

  /// Performs the mandatory STARTTLS exchange over an injectable wire. The
  /// default [connect] path supplies a socket that validates trust and host.
  static Future<SmtpClient> negotiateStartTls(
    SmtpWireConnection wire, {
    required String host,
    Duration timeout = defaultSmtpTimeout,
  }) async {
    final client = SmtpClient(wire);
    client._expect(await wire.readReply(timeout: timeout), [220]);
    await client._ehlo('glassmail.local');
    if (!client._features.any(
      (feature) => feature.toUpperCase() == 'STARTTLS',
    )) {
      throw const SmtpProtocolException('SMTP server does not offer STARTTLS');
    }
    await client._command('STARTTLS', [220]);
    await wire.startTls(host);
    client._features.clear();
    await client._ehlo('glassmail.local');
    client._ready = true;
    return client;
  }

  bool _ready = false;
  final List<String> _features = [];

  Future<void> sendRaw({
    required String email,
    required Uint8List credentialUtf8,
    required Iterable<String> recipients,
    required Uint8List rawMessage,
  }) async {
    if (!_ready) {
      throw const SmtpProtocolException('SMTP STARTTLS is not ready');
    }
    if (rawMessage.isEmpty || rawMessage.length > maxSmtpMessageBytes) {
      throw const SmtpProtocolException('SMTP message exceeds 24 MiB limit');
    }
    final allRecipients = recipients.toList(growable: false);
    if (!_validAddress.hasMatch(email) ||
        allRecipients.isEmpty ||
        allRecipients.any((address) => !_validAddress.hasMatch(address))) {
      throw const SmtpProtocolException('Invalid SMTP address');
    }

    await _authenticate(email, credentialUtf8);
    await _command('MAIL FROM:<$email>', [250]);
    for (final recipient in allRecipients) {
      await _command('RCPT TO:<$recipient>', [250, 251]);
    }
    await _command('DATA', [354]);
    try {
      await _wire.writeData(_dotStuffAndTerminate(rawMessage));
      final reply = await _wire.readReply();
      if (reply.code != 250) throw SmtpRejectedException(reply.code);
    } on SmtpRejectedException {
      rethrow;
    } on Object catch (error) {
      await _wire.close();
      throw SmtpUncertainDeliveryException(error);
    }
  }

  Future<void> close() => _wire.close();

  Future<void> _authenticate(String email, Uint8List credentialUtf8) async {
    final authLine = _features
        .where((feature) => feature.toUpperCase().startsWith('AUTH '))
        .join(' ')
        .toUpperCase();
    final emailBase64 = base64.encode(utf8.encode(email));
    final secretBase64 = base64.encode(credentialUtf8);

    if (authLine.contains('PLAIN')) {
      final payload = Uint8List(credentialUtf8.length + email.length + 2)
        ..[0] = 0;
      var offset = 1;
      final emailBytes = utf8.encode(email);
      payload.setRange(offset, offset + emailBytes.length, emailBytes);
      offset += emailBytes.length + 1;
      payload.setRange(offset, offset + credentialUtf8.length, credentialUtf8);
      final reply = await _command('AUTH PLAIN ${base64.encode(payload)}', [
        235,
        334,
      ], allowAuthenticationFailure: true);
      if (reply.code == 334) {
        await _command(base64.encode(payload), [
          235,
        ], allowAuthenticationFailure: true);
      }
      return;
    }

    if (authLine.contains('LOGIN')) {
      var reply = await _command('AUTH LOGIN', [
        334,
        235,
      ], allowAuthenticationFailure: true);
      if (reply.code == 235) return;
      reply = await _command(emailBase64, [
        334,
      ], allowAuthenticationFailure: true);
      reply = await _command(secretBase64, [
        235,
      ], allowAuthenticationFailure: true);
      if (reply.code != 235) throw const SmtpAuthenticationException();
      return;
    }
    throw const SmtpProtocolException(
      'SMTP server offers no supported password authentication method',
    );
  }

  Future<void> _ehlo(String name) async {
    final reply = await _command('EHLO $name', [250]);
    _features
      ..clear()
      ..addAll(reply.lines.map((line) => line.trim()));
  }

  Future<SmtpReply> _command(
    String line,
    List<int> expectedCodes, {
    bool allowAuthenticationFailure = false,
  }) async {
    if (line.contains('\r') || line.contains('\n')) {
      throw const SmtpProtocolException('SMTP command contains a line break');
    }
    await _wire.writeLine(line);
    final reply = await _wire.readReply();
    if (reply.code == 535 || reply.code == 534) {
      throw const SmtpAuthenticationException();
    }
    if (!expectedCodes.contains(reply.code)) {
      if (allowAuthenticationFailure && reply.code >= 400) {
        throw const SmtpAuthenticationException();
      }
      throw SmtpRejectedException(reply.code);
    }
    return reply;
  }

  void _expect(SmtpReply reply, List<int> codes) {
    if (!codes.contains(reply.code)) throw SmtpRejectedException(reply.code);
  }

  static Uint8List _dotStuffAndTerminate(Uint8List message) {
    final output = BytesBuilder(copy: false);
    var atLineStart = true;
    for (var index = 0; index < message.length; index++) {
      final byte = message[index];
      if (byte == 0x0d || byte == 0x0a) {
        if (byte == 0x0d &&
            index + 1 < message.length &&
            message[index + 1] == 0x0a) {
          index++;
        }
        if (output.length + 2 > maxSmtpMessageBytes) {
          throw const SmtpProtocolException(
            'Normalized SMTP message exceeds limit',
          );
        }
        output.add(const [0x0d, 0x0a]);
        atLineStart = true;
        continue;
      }
      if (output.length + (atLineStart && byte == 0x2e ? 2 : 1) >
          maxSmtpMessageBytes) {
        throw const SmtpProtocolException(
          'Normalized SMTP message exceeds limit',
        );
      }
      if (atLineStart && byte == 0x2e) output.addByte(0x2e);
      output.addByte(byte);
      atLineStart = false;
    }
    final hasTrailingNewline =
        message.isNotEmpty && (message.last == 0x0d || message.last == 0x0a);
    final terminatorLength = hasTrailingNewline ? 3 : 5;
    if (output.length + terminatorLength > maxSmtpMessageBytes) {
      throw const SmtpProtocolException(
        'Normalized SMTP message exceeds limit',
      );
    }
    if (!hasTrailingNewline) output.add(const [0x0d, 0x0a]);
    output.add(const [0x2e, 0x0d, 0x0a]);
    return output.takeBytes();
  }

  static final _validAddress = RegExp(
    r'^[A-Za-z0-9.!#$%&\x27*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+$',
  );
}

final class _SocketSmtpWire implements SmtpWireConnection {
  _SocketSmtpWire(this._socket, this._timeout)
    : _lines = _SmtpLineReader(_socket);

  Socket _socket;
  _SmtpLineReader _lines;
  final Duration _timeout;
  bool _closed = false;

  static Future<_SocketSmtpWire> connect({
    required String host,
    required int port,
    required Duration timeout,
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      return _SocketSmtpWire(socket, timeout);
    } on SocketException catch (error) {
      throw SmtpTransportException('SMTP connection failed', error);
    } on TimeoutException catch (error) {
      throw SmtpTransportException('SMTP connection timed out', error);
    }
  }

  @override
  Future<SmtpReply> readReply({Duration? timeout}) async {
    final lines = <String>[];
    int? code;
    while (true) {
      final line = await _lines.readLine(timeout ?? _timeout);
      if (line.length < 4 ||
          int.tryParse(line.substring(0, 3)) == null ||
          (line[3] != ' ' && line[3] != '-')) {
        throw const SmtpProtocolException('Malformed SMTP reply');
      }
      final thisCode = int.parse(line.substring(0, 3));
      code ??= thisCode;
      if (thisCode != code) {
        throw const SmtpProtocolException('Inconsistent multiline SMTP reply');
      }
      lines.add(line.substring(4));
      if (line[3] == ' ') return SmtpReply(code: code, lines: lines);
      if (lines.length > 256) {
        throw const SmtpProtocolException('SMTP reply contains too many lines');
      }
    }
  }

  @override
  Future<void> writeLine(String line) async {
    _ensureOpen();
    _socket.add(utf8.encode('$line\r\n'));
    await _socket.flush();
  }

  @override
  Future<void> writeData(Uint8List bytes) async {
    _ensureOpen();
    _socket.add(bytes);
    await _socket.flush();
  }

  @override
  Future<void> startTls(String host) async {
    _ensureOpen();
    await _lines.cancel();
    try {
      _socket = await SecureSocket.secure(_socket, host: host);
      _lines = _SmtpLineReader(_socket);
    } on HandshakeException catch (error) {
      await close();
      throw SmtpTransportException('SMTP TLS handshake failed', error);
    } on SocketException catch (error) {
      await close();
      throw SmtpTransportException('SMTP TLS upgrade failed', error);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _lines.cancel();
    await _socket.close();
  }

  void _ensureOpen() {
    if (_closed) throw const SmtpTransportException('SMTP socket is closed');
  }
}

final class _SmtpLineReader {
  _SmtpLineReader(Stream<List<int>> stream)
    : _iterator = StreamIterator<List<int>>(stream);

  final StreamIterator<List<int>> _iterator;
  List<int> _chunk = const [];
  int _position = 0;

  Future<String> readLine(Duration timeout) async {
    final line = BytesBuilder(copy: false);
    while (true) {
      final byte = await _readByte().timeout(timeout);
      if (byte == 0x0a) {
        final bytes = line.takeBytes().toList();
        if (bytes.isNotEmpty && bytes.last == 0x0d) bytes.removeLast();
        return ascii.decode(bytes, allowInvalid: true);
      }
      if (line.length >= maxSmtpLineBytes) {
        throw const SmtpProtocolException('SMTP response line exceeds 64 KiB');
      }
      line.addByte(byte);
    }
  }

  Future<int> _readByte() async {
    while (_position >= _chunk.length) {
      if (!await _iterator.moveNext()) {
        throw const SmtpTransportException('SMTP server disconnected');
      }
      _chunk = _iterator.current;
      _position = 0;
      if (_chunk.isEmpty) continue;
    }
    return _chunk[_position++];
  }

  Future<void> cancel() => _iterator.cancel();
}
