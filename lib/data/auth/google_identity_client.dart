import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/failures/xland_failure.dart';

abstract interface class GoogleIdentityClient {
  bool get available;
  Future<String?> authenticate();
}

/// Native Google identity only. Backend must verify this ID token before login.
final class NativeGoogleIdentityClient implements GoogleIdentityClient {
  NativeGoogleIdentityClient({required this.serverClientId, this.clientId});
  final String serverClientId;
  final String? clientId;
  Future<void>? _initialization;

  @override
  bool get available =>
      serverClientId.endsWith('.apps.googleusercontent.com') &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<String?> authenticate() async {
    if (!available) {
      throw const XlandFailure(
        code: FailureCode.featureNotEnabled,
        message: 'Đăng nhập Google chưa sẵn sàng trên thiết bị này.',
      );
    }
    try {
      await (_initialization ??= GoogleSignIn.instance.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
      ));
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const XlandFailure(
          code: FailureCode.unauthenticated,
          message: 'Google chưa cấp mã xác thực. Vui lòng thử lại.',
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      // SDK descriptions may include account details; do not surface or log them.
      throw const XlandFailure(
        code: FailureCode.upstreamUnavailable,
        message: 'Không thể mở đăng nhập Google. Vui lòng thử lại.',
      );
    } on XlandFailure {
      rethrow;
    } catch (_) {
      throw const XlandFailure(
        code: FailureCode.upstreamUnavailable,
        message: 'Không thể mở đăng nhập Google. Vui lòng thử lại.',
      );
    }
  }
}
