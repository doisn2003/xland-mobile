import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

import '../../../domain/failures/xland_failure.dart';

import 'session_store.dart';

final class SecureSessionStore implements SessionStore,SessionInvalidationSource {
  SecureSessionStore(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'xland.access_token.v1';
  Future<void> _tail = Future<void>.value();
  final _invalidations=StreamController<void>.broadcast(sync:true);
  @override Stream<void> get sessionInvalidations=>_invalidations.stream;

  @override
  Future<String?> readAccessToken() => _serial(() => storage.read(key: _key));
  @override
  Future<void> saveAccessToken({required String accessToken}) =>
      _serial(() => storage.write(key: _key, value: accessToken));
  @override
  Future<void> clear() => _serial(() async {
    await storage.delete(key: _key);
    _invalidations.add(null);
  });
  @override
  Future<void> clearIfMatches({required String accessToken}) => _serial(() async {
    if (await storage.read(key: _key) == accessToken) {
      await storage.delete(key: _key);
      _invalidations.add(null);
    }
  });

  Future<T> _serial<T>(Future<T> Function() action) {
    final result=_tail.then((_)=>_guard(action));
    _tail=result.then<void>((_) {},onError:(Object _,StackTrace _) {});
    return result;
  }
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
