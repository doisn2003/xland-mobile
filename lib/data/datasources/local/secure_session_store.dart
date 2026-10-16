import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

final class SecureSessionStore implements SessionStore {
  const SecureSessionStore(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'xland.access_token.v1';

  @override
  Future<String?> readAccessToken() => storage.read(key: _key);
  @override
  Future<void> saveAccessToken({required String accessToken}) =>
      storage.write(key: _key, value: accessToken);
  @override
  Future<void> clear() => storage.delete(key: _key);
}
