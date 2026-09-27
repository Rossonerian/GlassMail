import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_imap/glassmail_core_imap.dart';

void main() {
  group('SMTP STARTTLS submission', () {
    test('requires STARTTLS before auth and rebuilds EHLO capabilities',
        () async {
      final wire = _FakeSmtpWire([
        SmtpReply(code: 220, lines: ['ready']),
        SmtpReply(code: 250, lines: ['host', 'STARTTLS', 'AUTH LOGIN']),
        SmtpReply(code: 220, lines: ['begin TLS']),
        SmtpReply(code: 250, lines: ['host', 'AUTH PLAIN LOGIN']),
      ]);

      final client = await SmtpClient.negotiateStartTls(
        wire,
        host: 'smtp.example.test',
      );

      expect(wire.tlsHosts, ['smtp.example.test']);
      expect(wire.commands, [
        'EHLO glassmail.local',
        'STARTTLS',
        'EHLO glassmail.local',
      ]);
      await client.close();
    });

    test('authenticates after TLS, dot-stuffs DATA and accepts recipients',
        () async {
      final wire = _FakeSmtpWire([
        SmtpReply(code: 220, lines: ['ready']),
        SmtpReply(code: 250, lines: ['host', 'STARTTLS', 'AUTH PLAIN LOGIN']),
        SmtpReply(code: 220, lines: ['begin TLS']),
        SmtpReply(code: 250, lines: ['host', 'AUTH PLAIN LOGIN']),
        SmtpReply(code: 235, lines: ['authenticated']),
        SmtpReply(code: 250, lines: ['sender accepted']),
        SmtpReply(code: 251, lines: ['forwarding recipient accepted']),
        SmtpReply(code: 354, lines: ['send message']),
        SmtpReply(code: 250, lines: ['queued']),
      ]);
      final client =
          await SmtpClient.negotiateStartTls(wire, host: 'smtp.test');
      final secret = Uint8List.fromList(utf8.encode('test-app-password'));

      await client.sendRaw(
        email: 'sender@example.com',
        credentialUtf8: secret,
        recipients: ['to@example.com'],
        rawMessage: Uint8List.fromList(
          utf8.encode('Subject: test\n\n.first\n..second'),
        ),
      );

      expect(wire.commands, contains('MAIL FROM:<sender@example.com>'));
      expect(wire.commands, contains('RCPT TO:<to@example.com>'));
      expect(wire.commands, contains('DATA'));
      expect(wire.commands.join('\n'), isNot(contains('test-app-password')));
      final auth = wire.commands
          .singleWhere((command) => command.startsWith('AUTH PLAIN '));
      expect(base64.decode(auth.substring('AUTH PLAIN '.length)), [
        0,
        ...utf8.encode('sender@example.com'),
        0,
        ...utf8.encode('test-app-password'),
      ]);
      expect(
        utf8.decode(wire.data.single),
        'Subject: test\r\n\r\n..first\r\n...second\r\n.\r\n',
      );
      await client.close();
    });

    test('distinguishes rejected DATA from uncertain delivery', () async {
      final rejectedWire = _FakeSmtpWire([
        ..._startTlsReplies(),
        SmtpReply(code: 235, lines: ['authenticated']),
        SmtpReply(code: 250, lines: ['sender accepted']),
        SmtpReply(code: 250, lines: ['recipient accepted']),
        SmtpReply(code: 354, lines: ['send message']),
        SmtpReply(code: 554, lines: ['rejected']),
      ]);
      final rejected = await SmtpClient.negotiateStartTls(
        rejectedWire,
        host: 'smtp.test',
      );
      await expectLater(
        rejected.sendRaw(
          email: 'sender@example.com',
          credentialUtf8: Uint8List.fromList(utf8.encode('secret')),
          recipients: ['to@example.com'],
          rawMessage:
              Uint8List.fromList(utf8.encode('Subject: test\r\n\r\nbody')),
        ),
        throwsA(isA<SmtpRejectedException>()),
      );

      final uncertainWire = _FakeSmtpWire(
        [
          ..._startTlsReplies(),
          SmtpReply(code: 235, lines: ['authenticated']),
          SmtpReply(code: 250, lines: ['sender accepted']),
          SmtpReply(code: 250, lines: ['recipient accepted']),
          SmtpReply(code: 354, lines: ['send message']),
        ],
      );
      final uncertain = await SmtpClient.negotiateStartTls(
        uncertainWire,
        host: 'smtp.test',
      );
      await expectLater(
        uncertain.sendRaw(
          email: 'sender@example.com',
          credentialUtf8: Uint8List.fromList(utf8.encode('secret')),
          recipients: ['to@example.com'],
          rawMessage:
              Uint8List.fromList(utf8.encode('Subject: test\r\n\r\nbody')),
        ),
        throwsA(isA<SmtpUncertainDeliveryException>()),
      );
      expect(uncertainWire.closed, isTrue);
    });

    test('classifies authentication failure and rejects absent STARTTLS',
        () async {
      final rejectedTls = _FakeSmtpWire([
        SmtpReply(code: 220, lines: ['ready']),
        SmtpReply(code: 250, lines: ['host', 'AUTH PLAIN']),
      ]);
      await expectLater(
        SmtpClient.negotiateStartTls(rejectedTls, host: 'smtp.test'),
        throwsA(isA<SmtpProtocolException>()),
      );

      final authWire = _FakeSmtpWire([
        ..._startTlsReplies(),
        SmtpReply(code: 535, lines: ['authentication failed']),
      ]);
      final client = await SmtpClient.negotiateStartTls(
        authWire,
        host: 'smtp.test',
      );
      await expectLater(
        client.sendRaw(
          email: 'sender@example.com',
          credentialUtf8: Uint8List.fromList(utf8.encode('secret')),
          recipients: ['to@example.com'],
          rawMessage:
              Uint8List.fromList(utf8.encode('Subject: test\r\n\r\nbody')),
        ),
        throwsA(isA<SmtpAuthenticationException>()),
      );
    });
  });
}

List<SmtpReply> _startTlsReplies() => [
      SmtpReply(code: 220, lines: ['ready']),
      SmtpReply(code: 250, lines: ['host', 'STARTTLS', 'AUTH PLAIN LOGIN']),
      SmtpReply(code: 220, lines: ['begin TLS']),
      SmtpReply(code: 250, lines: ['host', 'AUTH PLAIN LOGIN']),
    ];

final class _FakeSmtpWire implements SmtpWireConnection {
  _FakeSmtpWire(Iterable<SmtpReply> replies) : _replies = List.of(replies);

  final List<SmtpReply> _replies;
  final List<String> commands = [];
  final List<Uint8List> data = [];
  final List<String> tlsHosts = [];
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<SmtpReply> readReply({Duration? timeout}) async {
    if (_replies.isEmpty) {
      throw const SocketException('simulated disconnect');
    }
    return _replies.removeAt(0);
  }

  @override
  Future<void> startTls(String host) async => tlsHosts.add(host);

  @override
  Future<void> writeData(Uint8List bytes) async => data.add(bytes);

  @override
  Future<void> writeLine(String line) async => commands.add(line);
}
