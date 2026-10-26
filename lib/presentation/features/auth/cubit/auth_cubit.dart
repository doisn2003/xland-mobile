import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';

import 'package:xland_mobile/domain/xland_domain.dart';

import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._accountRepository, {this.extendedAuth})
    : super(const AuthInitial()) {
    final repository = _accountRepository;
    if (repository case AccountSessionEvents events) {
      _invalidations = events.sessionInvalidations.listen((_) {
        // A previous logout can finish while a new login is still pending.
        // The pending login owns the next state; an actual active session
        // invalidation immediately clears private UI through AuthGuest.
        if (!isClosed && state is! AuthLoading && state is! AuthGuest) {
          if (_logoutEpoch != _sessionEpoch) _sessionEpoch++;
          emit(const AuthGuest());
        }
      });
    }
  }

  final AccountRepository _accountRepository;
  final ExtendedAuthRepository? extendedAuth;
  int _sessionEpoch = 0;
  int? _logoutEpoch;
  StreamSubscription<void>? _invalidations;
  bool _current(int epoch) => !isClosed && epoch == _sessionEpoch;

  @override
  Future<void> close() async {
    _sessionEpoch++;
    extendedAuth?.cancelPendingSignIn();
    await _invalidations?.cancel();
    return super.close();
  }

  Future<void> checkSession() async {
    final epoch = ++_sessionEpoch;
    try {
      final session = await _accountRepository.getSession();
      if (!_current(epoch)) return;
      if (session != null && session.expiresAt.isAfter(DateTime.now())) {
        emit(AuthAuthenticated(session));
      } else {
        emit(const AuthGuest());
      }
    } catch (_) {
      if (_current(epoch)) emit(const AuthGuest());
    }
  }

  void profileUpdated(UserProfile profile) {
    final current = state;
    if (!isClosed &&
        current is AuthAuthenticated &&
        current.session.profile.id == profile.id) {
      emit(AuthAuthenticated(Session(
        profile: profile,
        expiresAt: current.session.expiresAt,
      )));
    }
  }

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    extendedAuth?.cancelPendingSignIn();
    final epoch = ++_sessionEpoch;
    if (isClosed) return false;
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.length < 3 || cleanUsername.length > 64) {
      emit(const AuthError('Tên đăng nhập phải có từ 3 đến 64 ký tự.'));
      return false;
    }

    if (password.length < 8 || password.length > 128) {
      emit(const AuthError('Mật khẩu phải có từ 8 đến 128 ký tự.'));
      return false;
    }

    emit(const AuthLoading());
    try {
      final session = await _accountRepository.signIn(
        SignInInput(username: cleanUsername, password: password),
      );
      if (!_current(epoch)) return false;
      emit(AuthAuthenticated(session));
      return true;
    } on XlandFailure catch (failure) {
      if (_current(epoch)) emit(AuthError(failure.message));
      return false;
    } catch (e) {
      if (_current(epoch)) {
        emit(const AuthError('Không thể đăng nhập. Vui lòng thử lại.'));
      }
      return false;
    }
  }

  Future<bool> signUp({
    required String username,
    required String password,
  }) async {
    extendedAuth?.cancelPendingSignIn();
    final epoch = ++_sessionEpoch;
    if (isClosed) return false;
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.length < 3 || cleanUsername.length > 64) {
      emit(const AuthError('Tên đăng nhập phải có từ 3 đến 64 ký tự.'));
      return false;
    }

    if (password.length < 8 || password.length > 128) {
      emit(const AuthError('Mật khẩu phải có từ 8 đến 128 ký tự.'));
      return false;
    }

    emit(const AuthLoading());
    try {
      final session = await _accountRepository.signUp(
        SignUpInput(username: cleanUsername, password: password),
      );
      if (!_current(epoch)) return false;
      emit(AuthAuthenticated(session));
      return true;
    } on XlandFailure catch (failure) {
      if (_current(epoch)) emit(AuthError(failure.message));
      return false;
    } catch (e) {
      if (_current(epoch)) {
        emit(const AuthError('Không thể đăng ký. Vui lòng thử lại.'));
      }
      return false;
    }
  }

  Future<void> signOut() async {
    extendedAuth?.cancelPendingSignIn();
    final epoch = ++_sessionEpoch;
    _logoutEpoch = epoch;
    try {
      await _accountRepository.signOut();
      if (!_current(epoch)) return;
      emit(const AuthGuest());
    } on XlandFailure catch (failure) {
      if (!_current(epoch)) return;
      emit(
        AuthGuest(
          warningMessage:
              'Đã xóa phiên thiết bị, chưa xác nhận thu hồi server: ${failure.message}',
        ),
      );
    } catch (_) {
      if (!_current(epoch)) return;
      emit(
        const AuthGuest(
          warningMessage:
              'Đã xóa phiên thiết bị, chưa xác nhận thu hồi server.',
        ),
      );
    } finally {
      if (_logoutEpoch == epoch) _logoutEpoch = null;
    }
  }

  void cancelPendingSignIn() {
    _sessionEpoch++;
    extendedAuth?.cancelPendingSignIn();
    if (!isClosed && state is AuthLoading) emit(const AuthGuest());
  }

  Future<bool> signInWithGoogle() =>
      _extendedSignIn((repository) => repository.signInWithGoogle());

  Future<bool> signInWithPhoneOtp(String challengeId, String code) =>
      _extendedSignIn(
        (repository) => repository.signInWithPhoneOtp(challengeId, code),
      );

  Future<bool> _extendedSignIn(
    Future<Session?> Function(ExtendedAuthRepository) action,
  ) async {
    final repository = extendedAuth;
    if (repository == null || isClosed) return false;
    final previous = state;
    final epoch = ++_sessionEpoch;
    emit(const AuthLoading());
    try {
      final session = await action(repository);
      if (!_current(epoch)) return false;
      if (session == null) {
        emit(previous is AuthAuthenticated ? previous : const AuthGuest());
        return false;
      }
      emit(AuthAuthenticated(session));
      return true;
    } on XlandFailure catch (failure) {
      if (_current(epoch)) emit(AuthError(failure.message));
    } catch (_) {
      if (_current(epoch)) {
        emit(const AuthError('Không thể đăng nhập. Vui lòng thử lại.'));
      }
    }
    return false;
  }
}
