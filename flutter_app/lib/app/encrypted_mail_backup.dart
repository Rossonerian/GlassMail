import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Password-protected, authenticated portable backup container.
///
/// The header is authenticated as AES-GCM associated data. Production files
/// use PBKDF2-HMAC-SHA256 with 600,000 iterations and AES-256-GCM.
final class EncryptedMailBackup {
  EncryptedMailBackup._({
    required this._iterations,
    required this._cryptography,
  });

  factory EncryptedMailBackup() => EncryptedMailBackup._(
    iterations: _productionIterations,
    cryptography: Cryptography.instance,
  );

  @visibleForTesting
  factory EncryptedMailBackup.forTesting({int iterations = 2}) =>
      EncryptedMailBackup._(
        iterations: iterations,
        cryptography: Cryptography.defaultInstance,
      );

  static const _productionIterations = 600000;
  static const _headerLength = 37;
  static const _macLength = 16;
  static const maxPlaintextBytes = 48 * 1024 * 1024;
  static const maxEncryptedBytes = 65 * 1024 * 1024;
  static const _magic = [0x47, 0x4d, 0x42, 0x4b]; // GMBK

  final int _iterations;
  final Cryptography _cryptography;

  Future<Uint8List> encrypt({
    required List<int> plaintext,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    if (plaintext.length > maxPlaintextBytes) {
      throw const FormatException('Backup exceeds the supported size limit.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final cipher = AesGcm.with256bits();
    final nonce = cipher.newNonce();
    final header = _makeHeader(salt, nonce);
    final key = await _deriveKey(passphrase, salt);
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
      aad: header,
    );
    final result = Uint8List.fromList([
      ...header,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    if (result.length > maxEncryptedBytes) {
      throw const FormatException('Backup exceeds the supported size limit.');
    }
    return result;
  }

  Future<Uint8List> decrypt({
    required List<int> ciphertext,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    if (ciphertext.length < _headerLength + _macLength ||
        ciphertext.length > maxEncryptedBytes) {
      throw const FormatException('Backup file size is invalid.');
    }
    final bytes = Uint8List.fromList(ciphertext);
    if (!_magic.asMap().entries.every(
          (entry) => bytes[entry.key] == entry.value,
        ) ||
        bytes[4] != 1) {
      throw const FormatException('File is not a supported GlassMail backup.');
    }
    final iterations = ByteData.sublistView(bytes).getUint32(5, Endian.big);
    if (iterations != _iterations) {
      throw const FormatException('Backup key settings are not supported.');
    }
    final salt = bytes.sublist(9, 25);
    final nonce = bytes.sublist(25, _headerLength);
    final macStart = bytes.length - _macLength;
    final secretBox = SecretBox(
      bytes.sublist(_headerLength, macStart),
      nonce: nonce,
      mac: Mac(bytes.sublist(macStart)),
    );
    final key = await _deriveKey(passphrase, salt);
    try {
      return Uint8List.fromList(
        await AesGcm.with256bits().decrypt(
          secretBox,
          secretKey: key,
          aad: bytes.sublist(0, _headerLength),
        ),
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Passphrase is incorrect or the backup file is damaged.',
      );
    }
  }

  Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
  ) => _cryptography
      .pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256)
      .deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);

  Uint8List _makeHeader(List<int> salt, List<int> nonce) {
    final header = Uint8List(_headerLength);
    header.setRange(0, _magic.length, _magic);
    header[4] = 1;
    ByteData.sublistView(header).setUint32(5, _iterations, Endian.big);
    header.setRange(9, 25, salt);
    header.setRange(25, _headerLength, nonce);
    return header;
  }

  static void _validatePassphrase(String passphrase) {
    if (passphrase.trim().length < 12 || passphrase.length > 1024) {
      throw const FormatException(
        'Use a passphrase between 12 and 1024 characters.',
      );
    }
  }
}
