import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_security/glassmail_core_security.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native secure storage stores, reads and deletes a throwaway value',
    (tester) async {
      final store = FlutterCredentialStore();
      final accountId =
          'codex-p0.2-smoke-${DateTime.now().microsecondsSinceEpoch}';
      final secret =
          'temporary-device-check-${DateTime.now().millisecondsSinceEpoch}';
      final input = Uint8List.fromList(utf8.encode(secret));

      try {
        await store.store(accountId, input);
        expect(input, everyElement(0));
        final stored = await store.withCredential(accountId, (bytes) {
          final decoded = utf8.decode(bytes);
          expect(decoded, secret);
          return decoded;
        });
        expect(stored, secret);
      } finally {
        await store.delete(accountId);
      }

      expect(
        await store.withCredential(accountId, (bytes) => bytes.length),
        isNull,
      );
    },
  );
}
