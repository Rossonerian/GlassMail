import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';

void main() {
  test('IMAP TLS rejects an untrusted certificate without an override',
      () async {
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/untrusted-test-cert.pem')
      ..usePrivateKey('test/fixtures/untrusted-test-key.pem');
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    final subscription = server.listen((socket) {
      socket.listen((_) {});
    });

    try {
      await expectLater(
        ImapClient.connect(
          host: '127.0.0.1',
          port: server.port,
          connectTimeout: const Duration(seconds: 5),
        ),
        throwsA(isA<ImapTransportException>()),
      );
    } finally {
      await subscription.cancel();
      await server.close();
    }
  });
}
