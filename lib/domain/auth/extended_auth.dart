import '../entities/account.dart';

final class AuthCapabilities {
  const AuthCapabilities({this.google = false, this.phoneOtp = false});
  final bool google;
  final bool phoneOtp;
}

enum OtpDeliveryStatus { pending, accepted, unknown }

final class PhoneOtpChallenge {
  const PhoneOtpChallenge({
    required this.id,
    required this.maskedPhone,
    required this.expiresAt,
    required this.resendAt,
    required this.deliveryStatus,
  });
  final String id;
  final String maskedPhone;
  final DateTime expiresAt;
  final DateTime resendAt;
  final OtpDeliveryStatus deliveryStatus;
}

/// Additive boundary; existing AccountRepository remains source compatible.
abstract interface class ExtendedAuthRepository {
  Future<AuthCapabilities> capabilities();

  /// Null means the user dismissed Google's account chooser.
  Future<Session?> signInWithGoogle();
  Future<PhoneOtpChallenge> requestPhoneOtp(String phone, String requestKey);
  Future<Session> signInWithPhoneOtp(String challengeId, String code);

  /// Invalidates pending sign-in results before they can persist a session.
  void cancelPendingSignIn();
}
