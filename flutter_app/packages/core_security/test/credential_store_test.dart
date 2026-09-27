import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';

void main() {
  late _MemoryCredentialBackend backend;
  late FlutterCredentialStore store;

  setUp(() {
    backend = _MemoryCredentialBackend();
    store = FlutterCredentialStore(backend: backend);
  });

  test(
    'stores namespaced opaque account keys and clears input bytes',
    () async {
      final password = Uint8List.fromList(utf8.encode('temporary-secret'));

      await store.store('account/one@example.test', password);

      expect(password, everyElement(0));
      expect(
        backend.values.keys.single,
        startsWith(FlutterCredentialStore.keyPrefix),
      );
      expect(backend.values.values.single, 'temporary-secret');
      expect(backend.values.keys.single, isNot(contains('example.test')));
    },
  );

  test(
    'credential callback is awaited and its mutable bytes are cleared',
    () async {
      await store.store('account-one', Uint8List.fromList([0xc3, 0xa9]));
      Uint8List? received;

      final result = await store.withCredential<String>('account-one', (
        bytes,
      ) async {
        received = bytes;
        await Future<void>.delayed(Duration.zero);
        return utf8.decode(bytes);
      });

      expect(result, 'é');
      expect(received, everyElement(0));
      expect(await store.withCredential('missing', (_) => 'unused'), isNull);
    },
  );

  test(
    'removal deletes only that account and invalid account ids are rejected',
    () async {
      await store.store('one', Uint8List.fromList([49]));
      await store.store('two', Uint8List.fromList([50]));

      await store.delete('one');

      expect(await store.withCredential('one', (_) => 'found'), isNull);
      expect(
        await store.withCredential('two', (bytes) => utf8.decode(bytes)),
        '2',
      );
      expect(
        () => store.store('  ', Uint8List.fromList([49])),
        throwsArgumentError,
      );
    },
  );
}

final class _MemoryCredentialBackend implements CredentialStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
