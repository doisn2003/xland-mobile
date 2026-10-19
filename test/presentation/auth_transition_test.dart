import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_state.dart';
import 'fakes/fake_xland_dependencies.dart';

Session session(String id)=>Session(profile:UserProfile(id:id,displayName:id,
  contactVerified:false,updatedAt:DateTime.utc(2026)),expiresAt:DateTime.now().add(const Duration(days:1)));
class DeferredSessionAccount extends FakeAccountRepository {
  final pending=Completer<Session?>();
  @override Future<Session?> getSession()=>pending.future;
  @override Future<Session> signIn(SignInInput input) async=>session(input.username);
}

class InvalidatingAccount extends FakeAccountRepository implements AccountSessionEvents {
  final invalidations=StreamController<void>.broadcast(sync:true);
  @override Stream<void> get sessionInvalidations=>invalidations.stream;
}
class PendingLoginAccount extends InvalidatingAccount {
  final login=Completer<Session>();
  @override Future<Session> signIn(SignInInput input)=>login.future;
}
class InvalidatingLogoutFailureAccount extends InvalidatingAccount {
  @override Future<void> signOut() async {
    invalidations.add(null);
    throw const XlandFailure(code:FailureCode.offline,message:'Server revocation not confirmed');
  }
}

void main(){
  test('local session invalidation preserves a failed remote logout warning',() async {
    final account=InvalidatingLogoutFailureAccount();final cubit=AuthCubit(account);
    addTearDown(()=>account.invalidations.close());addTearDown(cubit.close);
    await cubit.signIn(username:'owner_a',password:'review_password');
    await cubit.signOut();
    expect((cubit.state as AuthGuest).hasRevokeWarning,true);
  });
  test('an earlier logout invalidation does not cancel a pending newer login',() async {
    final account=PendingLoginAccount();final cubit=AuthCubit(account);
    addTearDown(()=>account.invalidations.close());addTearDown(cubit.close);
    final login=cubit.signIn(username:'owner_b',password:'review_password');
    account.invalidations.add(null);
    expect(cubit.state,isA<AuthLoading>());
    account.login.complete(session('owner_b'));
    expect(await login,true);
    expect((cubit.state as AuthAuthenticated).session.profile.id,'owner_b');
  });
  test('a cleared active session immediately returns UI auth to guest',() async {
    final account=InvalidatingAccount();final cubit=AuthCubit(account);
    addTearDown(()=>account.invalidations.close());addTearDown(cubit.close);
    await cubit.signIn(username:'owner_a',password:'review_password');
    expect(cubit.state,isA<AuthAuthenticated>());
    account.invalidations.add(null);
    expect(cubit.state,isA<AuthGuest>());
  });
  test('an old startup session read cannot replace a later login',() async {
    final account=DeferredSessionAccount();
    final cubit=AuthCubit(account);addTearDown(cubit.close);
    final startup=cubit.checkSession();
    await cubit.signIn(username:'owner_b',password:'review_password');
    account.pending.complete(session('owner_a'));await startup;
    expect((cubit.state as AuthAuthenticated).session.profile.id,'owner_b');
  });
  test('an old startup session read cannot undo logout',() async {
    final account=DeferredSessionAccount();final cubit=AuthCubit(account);addTearDown(cubit.close);
    final startup=cubit.checkSession();
    await cubit.signOut();
    account.pending.complete(session('owner_a'));await startup;
    expect(cubit.state,isA<AuthGuest>());
  });
}
