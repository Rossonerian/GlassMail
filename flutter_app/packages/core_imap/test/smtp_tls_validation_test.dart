import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';

void main() {
  test('SMTP STARTTLS rejects an untrusted certificate', () async {
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/untrusted-test-cert.pem')
      ..usePrivateKey('test/fixtures/untrusted-test-key.pem');
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final acceptedSocket = server.first;
    final client = SmtpClient.connect(
      host: '127.0.0.1',
      port: server.port,
      timeout: const Duration(seconds: 5),
    );
    final socket = await acceptedSocket;
    final lines = _SocketLineReader(socket);
    socket.add(utf8.encode('220 test SMTP ready\r\n'));
    await socket.flush();
    expect(await lines.readLine(), 'EHLO glassmail.local');
    socket.add(
      utf8.encode('250-test\r\n250-STARTTLS\r\n250 AUTH PLAIN LOGIN\r\n'),
    );
    await socket.flush();
    expect(await lines.readLine(), 'STARTTLS');
    socket.add(utf8.encode('220 begin TLS\r\n'));
    await socket.flush();
    await lines.cancel();

    final serverHandshake = SecureSocket.secure(socket, context: context)
        .then<void>((secure) async {
          await secure.drain<void>();
        }, onError: (Object _) {});
    await expectLater(client, throwsA(isA<SmtpTransportException>()));
    await serverHandshake.timeout(const Duration(seconds: 5));
    await socket.close();
    await server.close();
  });
}

final class _SocketLineReader {
  _SocketLineReader(Stream<List<int>> stream)
    : _iterator = StreamIterator<List<int>>(stream);

  final StreamIterator<List<int>> _iterator;
  List<int> _chunk = const [];
  int _offset = 0;

  Future<String> readLine() async {
    final bytes = <int>[];
    while (true) {
      if (_offset >= _chunk.length) {
        if (!await _iterator.moveNext()) throw StateError('Socket ended');
        _chunk = _iterator.current;
        _offset = 0;
        continue;
      }
      final byte = _chunk[_offset++];
      if (byte == 0x0a) {
        if (bytes.isNotEmpty && bytes.last == 0x0d) bytes.removeLast();
        return ascii.decode(bytes);
      }
      bytes.add(byte);
    }
  }

  Future<void> cancel() => _iterator.cancel();
}
