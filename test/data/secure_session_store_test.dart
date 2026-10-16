import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/datasources/local/secure_session_store.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  test(
    'session adapter uses secure-storage channel for token write/read/delete',
    () async {
      final values = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = Map<String, Object?>.from(call.arguments as Map);
            final key = args['key'] as String;
            switch (call.method) {
              case 'read':
                return values[key];
              case 'write':
                values[key] = args['value'] as String;
                return null;
              case 'delete':
                values.remove(key);
                return null;
              default:
                throw StateError('Unexpected storage method');
            }
          });
      const store = SecureSessionStore(FlutterSecureStorage());
      expect(await store.readAccessToken(), isNull);
      await store.saveAccessToken(accessToken: 'T' * 43);
      expect(await store.readAccessToken(), 'T' * 43);
      expect(values.keys, ['xland.access_token.v1']);
      await store.clear();
      expect(await store.readAccessToken(), isNull);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test('native channel failures remain typed failures without insecure memory fallback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async =>
              throw PlatformException(code: 'DEVICE_STORAGE_UNAVAILABLE'),
        );
    const store = SecureSessionStore(FlutterSecureStorage());
    final failure = isA<XlandFailure>().having(
      (e) => e.code,
      'code',
      FailureCode.internalError,
    );
    await expectLater(store.readAccessToken(), throwsA(failure));
    await expectLater(
      store.saveAccessToken(accessToken: 'T' * 43),
      throwsA(failure),
    );
    await expectLater(store.clear(), throwsA(failure));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
