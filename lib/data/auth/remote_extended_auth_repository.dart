import '../../domain/auth/extended_auth.dart';
import '../../domain/entities/account.dart';
import '../../domain/failures/xland_failure.dart';
import '../datasources/local/session_store.dart';
import '../mappers/domain_mappers.dart';
import '../repositories/remote_repositories.dart';
import 'auth_operation_coordinator.dart';
import 'google_identity_client.dart';

final class RemoteExtendedAuthRepository implements ExtendedAuthRepository {
  const RemoteExtendedAuthRepository({
    required this.gateway,
    required this.sessions,
    required this.coordinator,
    this.google,
  });
  final RemoteGateway gateway;
  final SessionStore sessions;
  final AuthOperationCoordinator coordinator;
  final GoogleIdentityClient? google;

  @override
  Future<AuthCapabilities> capabilities() =>
      gateway.request('EXT-L-CAP', 'GET', '/auth/capabilities', (value) {
        final data = wireObject(value);
        return AuthCapabilities(
          google:
              wireBool(
                wireField(wireObject(wireField(data, 'google')), 'enabled'),
              ) &&
              (google?.available ?? false),
          phoneOtp: wireBool(
            wireField(wireObject(wireField(data, 'phoneOtp')), 'enabled'),
          ),
        );
      });

  @override
  Future<Session?> signInWithGoogle() => coordinator.run((attempt) async {
    if (!(google?.available ?? false)) {
      throw const XlandFailure(
        code: FailureCode.featureNotEnabled,
        message: 'Đăng nhập Google chưa sẵn sàng.',
      );
    }
    final idToken = await google!.authenticate();
    attempt.check();
    if (idToken == null) return null;
    return _exchange(attempt, '/auth/google/sessions', {'idToken': idToken});
  });

  @override
  Future<PhoneOtpChallenge> requestPhoneOtp(String phone, String requestKey) =>
      gateway.request(
        'EXT-L-PHONE-REQUEST',
        'POST',
        '/auth/phone/challenges',
        (value) {
          final data = wireObject(value);
          final status = wireString(wireField(data, 'deliveryStatus'));
          return PhoneOtpChallenge(
            id: wireString(wireField(data, 'challengeId')),
            maskedPhone: wireString(wireField(data, 'maskedPhone')),
            expiresAt: DateTime.parse(wireString(wireField(data, 'expiresAt'))),
            resendAt: DateTime.parse(wireString(wireField(data, 'resendAt'))),
            deliveryStatus: switch (status) {
              'pending' => OtpDeliveryStatus.pending,
              'accepted' => OtpDeliveryStatus.accepted,
              'unknown' => OtpDeliveryStatus.unknown,
              _ => throw const FormatException('Invalid delivery status'),
            },
          );
        },
        body: {'phone': phone},
        idempotencyKey: requestKey,
      );

  @override
  Future<Session> signInWithPhoneOtp(String challengeId, String code) =>
      coordinator.run(
        (attempt) => _exchange(attempt, '/auth/phone/sessions', {
          'challengeId': challengeId,
          'code': code,
        }),
      );

  Future<Session> _exchange(
    AuthAttempt attempt,
    String path,
    Map<String, Object?> body,
  ) async {
    final result = await gateway.request('EXT-L-SESSION', 'POST', path, (
      value,
    ) {
      final data = wireObject(value);
      final token = wireString(wireField(data, 'accessToken'));
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        throw const FormatException('Invalid session');
      }
      return (token: token, session: mapSession(wireField(data, 'session')));
    }, body: body);
    attempt.check();
    await sessions.saveAccessToken(accessToken: result.token);
    try {
      attempt.check();
    } on XlandFailure {
      await sessions.clearIfMatches(accessToken: result.token);
      rethrow;
    }
    return result.session;
  }

  @override
  void cancelPendingSignIn() => coordinator.cancel();
}
