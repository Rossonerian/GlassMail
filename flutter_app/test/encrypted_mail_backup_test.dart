import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail/app/encrypted_mail_backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encrypted backup round-trips authenticated JSON bytes', () async {
    final backup = EncryptedMailBackup.forTesting(iterations: 2);
    final clear = utf8.encode('{"format":"glassmail.backup.v1"}');
    final encrypted = await backup.encrypt(
      plaintext: clear,
      passphrase: 'correct horse battery',
    );

    expect(encrypted.length, greaterThan(clear.length));
    expect(
      await backup.decrypt(
        ciphertext: encrypted,
        passphrase: 'correct horse battery',
      ),
      clear,
    );
  });

  test(
    'encrypted backup rejects a wrong passphrase and a changed tag',
    () async {
      final backup = EncryptedMailBackup.forTesting(iterations: 2);
      final encrypted = await backup.encrypt(
        plaintext: utf8.encode('private message body'),
        passphrase: 'correct horse battery',
      );

      await expectLater(
        backup.decrypt(
          ciphertext: encrypted,
          passphrase: 'incorrect horse battery',
        ),
        throwsFormatException,
      );
      encrypted[encrypted.length - 1] ^= 1;
      await expectLater(
        backup.decrypt(
          ciphertext: encrypted,
          passphrase: 'correct horse battery',
        ),
        throwsFormatException,
      );
    },
  );

  test('backup passphrases require a minimum length', () async {
    final backup = EncryptedMailBackup.forTesting();
    await expectLater(
      backup.encrypt(plaintext: const [], passphrase: 'too short'),
      throwsFormatException,
    );
  });
}
