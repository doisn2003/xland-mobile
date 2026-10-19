import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xland_mobile/data/auth/remote_extended_auth_repository.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import 'extended_auth_test.dart' show MemoryStore, TestGoogle, exchange;

void main() {
  test('one coordinator prevents late username login from replacing newer Google owner', () async {
    final store = MemoryStore(),
        first = Completer<http.Response>(),
        started = Completer<void>();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/sessions')) {
        started.complete();
        return first.future;
      }
      return http.Response(jsonEncode({'data': exchange('G')}), 200);
    });
    addTearDown(client.close);
    final gateway = RemoteGateway(
      HttpApiTransport(
        baseUrl: Uri.parse('https://test.invalid/api/v1'),
        client: client,
        sessions: store,
      ),
    );
    final account = RemoteAccountRepository(gateway, store);
    final extension = RemoteExtendedAuthRepository(
      gateway: gateway,
      sessions: store,
      coordinator: account.authCoordinator,
      google: TestGoogle(),
    );
    final old = account.signIn(
      const SignInInput(username: 'owner_old', password: 'test_password'),
    );
    final oldFailure = expectLater(old, throwsA(isA<XlandFailure>()));
    await started.future;
    final current = extension.signInWithGoogle();
    first.complete(http.Response(jsonEncode({'data': exchange('U')}), 200));
    await oldFailure;
    expect((await current)!.profile.id, 'G');
    expect(store.token, 'G' * 43);
  });

  test('one coordinator prevents late Google login from replacing newer username owner', () async {
    final store = MemoryStore(),
        first = Completer<http.Response>(),
        started = Completer<void>();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/google/sessions')) {
        started.complete();
        return first.future;
      }
      return http.Response(jsonEncode({'data': exchange('U')}), 200);
    });
    addTearDown(client.close);
    final gateway = RemoteGateway(
      HttpApiTransport(
        baseUrl: Uri.parse('https://test.invalid/api/v1'),
        client: client,
        sessions: store,
      ),
    );
    final account = RemoteAccountRepository(gateway, store);
    final extension = RemoteExtendedAuthRepository(
      gateway: gateway,
      sessions: store,
      coordinator: account.authCoordinator,
      google: TestGoogle(),
    );
    final old = extension.signInWithGoogle();
    final oldFailure = expectLater(old, throwsA(isA<XlandFailure>()));
    await started.future;
    final current = account.signIn(
      const SignInInput(username: 'owner_new', password: 'test_password'),
    );
    first.complete(http.Response(jsonEncode({'data': exchange('G')}), 200));
    await oldFailure;
    expect((await current).profile.id, 'U');
    expect(store.token, 'U' * 43);
  });

  test('queued logout still revokes/clears old owner when a later username login fails', () async {
    final store = MemoryStore(),
        first = Completer<http.Response>(),
        started = Completer<void>();
    var revoked = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/google/sessions')) {
        started.complete();
        return first.future;
      }
      if (request.method == 'DELETE') {
        revoked = true;
        expect(request.headers['Authorization'], 'Bearer ${'A' * 43}');
        return http.Response('{"data":null}', 200);
      }
      expect(revoked, true);
      expect(request.headers.containsKey('Authorization'), false);
      return http.Response(
        '{"error":{"code":"UNAUTHENTICATED","message":"invalid login"}}',
        401,
      );
    });
    addTearDown(client.close);
    final gateway = RemoteGateway(
      HttpApiTransport(
        baseUrl: Uri.parse('https://test.invalid/api/v1'),
        client: client,
        sessions: store,
      ),
    );
    final account = RemoteAccountRepository(gateway, store);
    final extension = RemoteExtendedAuthRepository(
      gateway: gateway,
      sessions: store,
      coordinator: account.authCoordinator,
      google: TestGoogle(),
    );
    final old = extension.signInWithGoogle();
    final oldFailure = expectLater(old, throwsA(isA<XlandFailure>()));
    await started.future;
    final logout = account.signOut();
    final failed = account.signIn(
      const SignInInput(username: 'owner_bad', password: 'wrong_password'),
    );
    final failedExpectation = expectLater(failed, throwsA(isA<XlandFailure>()));
    first.complete(http.Response(jsonEncode({'data': exchange('G')}), 200));
    await oldFailure;
    await logout;
    await failedExpectation;
    expect(revoked, true);
    expect(store.token, isNull);
  });

  test('cancelling a username login through the injected extension blocks late secure save', () async {
    final store = MemoryStore(),
        response = Completer<http.Response>(),
        started = Completer<void>();
    final client = MockClient((_) {
      started.complete();
      return response.future;
    });
    addTearDown(client.close);
    final gateway = RemoteGateway(
      HttpApiTransport(
        baseUrl: Uri.parse('https://test.invalid/api/v1'),
        client: client,
        sessions: store,
      ),
    );
    final account = RemoteAccountRepository(gateway, store);
    final extension = RemoteExtendedAuthRepository(
      gateway: gateway,
      sessions: store,
      coordinator: account.authCoordinator,
    );
    final pending = account.signIn(
      const SignInInput(username: 'old_owner', password: 'test_password'),
    );
    final failure = expectLater(pending, throwsA(isA<XlandFailure>()));
    await started.future;
    extension.cancelPendingSignIn();
    response.complete(http.Response(jsonEncode({'data': exchange('U')}), 200));
    await failure;
    expect(store.token, 'A' * 43);
  });
}
