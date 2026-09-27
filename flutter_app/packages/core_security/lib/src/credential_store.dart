import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CredentialStore {
  /// Stores UTF-8 credential bytes and clears [credentialUtf8] before returning.
  Future<void> store(String accountId, List<int> credentialUtf8);

  /// Exposes mutable UTF-8 bytes for the duration of [useCredential], then
  /// clears the buffer. Callers should not copy or retain it.
  Future<T?> withCredential<T>(
    String accountId,
    FutureOr<T> Function(Uint8List credentialUtf8) useCredential,
  );

  Future<void> delete(String accountId);
}

abstract interface class CredentialStorageBackend {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// Platform-backed credential storage scoped by an opaque account key.
///
/// The Android implementation uses flutter_secure_storage's Android Keystore
/// key wrapping and AES-GCM storage cipher. iOS uses a device-only Keychain
/// item that requires the device to be unlocked. Platform plugins necessarily
/// expose a Dart String while crossing their method channel; Dart cannot
/// promise secure zeroization of those immutable String copies.
final class FlutterCredentialStore implements CredentialStore {
  FlutterCredentialStore({CredentialStorageBackend? backend})
    : _backend = backend ?? const _FlutterSecureStorageBackend();

  static const keyPrefix = 'credential.v1.';

  final CredentialStorageBackend _backend;

  @override
  Future<void> store(String accountId, List<int> credentialUtf8) async {
    try {
      _validateAccountId(accountId);
      final value = utf8.decode(credentialUtf8, allowMalformed: false);
      await _backend.write(_keyFor(accountId), value);
    } finally {
      credentialUtf8.fillRange(0, credentialUtf8.length, 0);
    }
  }

  @override
  Future<T?> withCredential<T>(
    String accountId,
    FutureOr<T> Function(Uint8List credentialUtf8) useCredential,
  ) async {
    _validateAccountId(accountId);
    final value = await _backend.read(_keyFor(accountId));
    if (value == null) return null;

    final credential = Uint8List.fromList(utf8.encode(value));
    try {
      return await useCredential(credential);
    } finally {
      credential.fillRange(0, credential.length, 0);
    }
  }

  @override
  Future<void> delete(String accountId) async {
    _validateAccountId(accountId);
    await _backend.delete(_keyFor(accountId));
  }

  static String _keyFor(String accountId) =>
      '$keyPrefix${base64Url.encode(utf8.encode(accountId)).replaceAll('=', '')}';

  static void _validateAccountId(String accountId) {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Must not be blank');
    }
  }
}

final class _FlutterSecureStorageBackend implements CredentialStorageBackend {
  const _FlutterSecureStorageBackend();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
      storageNamespace: 'com.glassmail.credentials.v1',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
