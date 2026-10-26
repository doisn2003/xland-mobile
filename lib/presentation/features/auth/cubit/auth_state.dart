import 'package:flutter/foundation.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

@immutable
sealed class AuthState {
  const AuthState();

  bool get isAuthenticated => this is AuthAuthenticated;
  bool get isGuest => this is AuthGuest;
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);
  final Session session;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthAuthenticated &&
          session.profile.id == other.session.profile.id &&
          session.profile.displayName == other.session.profile.displayName &&
          session.profile.avatarUrl == other.session.profile.avatarUrl &&
          session.profile.contactPhone == other.session.profile.contactPhone &&
          session.profile.address == other.session.profile.address &&
          session.profile.contactVerified ==
              other.session.profile.contactVerified &&
          session.profile.updatedAt == other.session.profile.updatedAt &&
          session.expiresAt == other.session.expiresAt;

  @override
  int get hashCode => Object.hash(
    session.profile.id,
    session.profile.displayName,
    session.profile.avatarUrl,
    session.profile.contactPhone,
    session.profile.address,
    session.profile.contactVerified,
    session.profile.updatedAt,
    session.expiresAt,
  );
}

final class AuthGuest extends AuthState {
  const AuthGuest({this.warningMessage});
  final String? warningMessage;

  bool get hasRevokeWarning => warningMessage != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthGuest &&
          runtimeType == other.runtimeType &&
          warningMessage == other.warningMessage;

  @override
  int get hashCode => warningMessage.hashCode;
}

final class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}
