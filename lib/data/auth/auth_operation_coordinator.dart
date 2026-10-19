import '../../domain/failures/xland_failure.dart';

/// One instance per SessionStore, shared by every login method and logout.
final class AuthOperationCoordinator {
  Future<void> _tail = Future<void>.value();
  int _epoch = 0;

  void cancel() => _epoch++;

  Future<T> run<T>(
    Future<T> Function(AuthAttempt attempt) operation, {
    bool cancellable = true,
  }) {
    final epoch = ++_epoch;
    // Logout remains ordered but must still clear/revoke the old owner if a
    // later login is queued and then fails. New intents cancel sign-ins only.
    final attempt = AuthAttempt._(() => !cancellable || epoch == _epoch);
    final result = _tail.then((_) {
      attempt.check();
      return operation(attempt);
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

final class AuthAttempt {
  AuthAttempt._(this._current);
  final bool Function() _current;
  void check() {
    if (!_current()) {
      throw const XlandFailure(
        code: FailureCode.conflict,
        message: 'Yêu cầu đăng nhập đã được thay thế hoặc hủy.',
      );
    }
  }
}
