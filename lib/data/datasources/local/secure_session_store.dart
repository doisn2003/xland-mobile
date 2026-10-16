import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../domain/failures/xland_failure.dart';

import 'session_store.dart';

final class SecureSessionStore implements SessionStore {
  const SecureSessionStore(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'xland.access_token.v1';

  @override
  Future<String?> readAccessToken() => _guard(() => storage.read(key: _key));
  @override
  Future<void> saveAccessToken({required String accessToken}) =>
      _guard(() => storage.write(key: _key, value: accessToken));
  @override
  Future<void> clear() => _guard(() => storage.delete(key: _key));
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      throw const XlandFailure(
        code: FailureCode.internalError,
        message: 'Không thể truy cập phiên đăng nhập an toàn trên thiết bị',
      );
    }
  }
}
