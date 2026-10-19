import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xland_mobile/data/auth/auth_operation_coordinator.dart';
import 'package:xland_mobile/data/auth/google_identity_client.dart';
import 'package:xland_mobile/data/auth/remote_extended_auth_repository.dart';
import 'package:xland_mobile/data/datasources/remote/api_transport.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class MemoryStore implements SessionStore {
  String? token = 'A' * 43;
  @override
  Future<String?> readAccessToken() async => token;
  @override
  Future<void> saveAccessToken({required String accessToken}) async {
    token = accessToken;
  }

  @override
  Future<void> clear() async {
    token = null;
  }

  @override
  Future<void> clearIfMatches({required String accessToken}) async {
    if (token == accessToken) token = null;
  }
}

class TestGoogle implements GoogleIdentityClient {
  String? token = 'test-id-token';
  @override
  bool get available => true;
  @override
  Future<String?> authenticate() async => token;
}

Map<String, Object?> exchange(String owner) => {
  'accessToken': owner * 43,
  'session': {
    'profile': {
      'id': owner,
      'displayName': owner,
      'avatarUrl': null,
      'contactPhone': null,
      'contactVerified': false,
      'updatedAt': '2026-10-19T06:00:00Z',
    },
    'expiresAt': '2026-10-20T06:00:00Z',
  },
};
void main() {
  test('public auth never attaches bearer or clears the active owner on invalid proof', () async {
    final store = MemoryStore();
    final client = MockClient((request) async {
      expect(request.headers.containsKey('Authorization'), false);
      return http.Response(
        '{"error":{"code":"UNAUTHENTICATED","message":"invalid proof"}}',
        401,
      );
    });
    addTearDown(client.close);
    final transport = HttpApiTransport(
      baseUrl: Uri.parse('https://test.invalid/api/v1'),
      client: client,
      sessions: store,
    );
    for (final path in [
      '/auth/google/sessions',
      '/auth/phone/sessions',
      '/auth/phone/challenges',
      '/auth/capabilities',
    ]) {
      await expectLater(
        transport.send(
          ApiRequest(
            method: path.endsWith('capabilities') ? 'GET' : 'POST',
            path: path,
          ),
        ),
        throwsA(isA<XlandFailure>()),
      );
      expect(store.token, 'A' * 43);
    }
  });

  test('Google cancellation does not exchange credentials or change stored session', () async {
    final store = MemoryStore(), google = TestGoogle()..token = null;
    final client = MockClient(
      (_) async => throw StateError('No network expected'),
    );
    addTearDown(client.close);
    final repo = RemoteExtendedAuthRepository(
      gateway: RemoteGateway(
        HttpApiTransport(
          baseUrl: Uri.parse('https://test.invalid/api/v1'),
          client: client,
          sessions: store,
        ),
      ),
      sessions: store,
      coordinator: AuthOperationCoordinator(),
      google: google,
    );
    expect(await repo.signInWithGoogle(), isNull);
    expect(store.token, 'A' * 43);
  });

  test(
    'cancelling an in-flight OTP verification prevents a late session save',
    () async {
      final store = MemoryStore();
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final client = MockClient((request) {
        started.complete();
        return response.future;
      });
      addTearDown(client.close);
      final repo = RemoteExtendedAuthRepository(
        gateway: RemoteGateway(
          HttpApiTransport(
            baseUrl: Uri.parse('https://test.invalid/api/v1'),
            client: client,
            sessions: store,
          ),
        ),
        sessions: store,
        coordinator: AuthOperationCoordinator(),
      );
      final pending = repo.signInWithPhoneOtp('challenge', '123456');
      final expectation = expectLater(pending, throwsA(isA<XlandFailure>()));
      await started.future;
      repo.cancelPendingSignIn();
      response.complete(
        http.Response(jsonEncode({'data': exchange('B')}), 200),
      );
      await expectation;
      expect(store.token, 'A' * 43);
    },
  );

  test(
    'new Google login wins over a late OTP response on the same coordinator',
    () async {
      final store = MemoryStore(),
          first = Completer<http.Response>(),
          started = Completer<void>();
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('/phone/sessions')) {
          started.complete();
          return first.future;
        }
        expect(jsonDecode(request.body), {'idToken': 'test-id-token'});
        return http.Response(jsonEncode({'data': exchange('C')}), 200);
      });
      addTearDown(client.close);
      final repo = RemoteExtendedAuthRepository(
        gateway: RemoteGateway(
          HttpApiTransport(
            baseUrl: Uri.parse('https://test.invalid/api/v1'),
            client: client,
            sessions: store,
          ),
        ),
        sessions: store,
        coordinator: AuthOperationCoordinator(),
        google: TestGoogle(),
      );
      final old = repo.signInWithPhoneOtp('old', '123456');
      final expectation = expectLater(old, throwsA(isA<XlandFailure>()));
      await started.future;
      final current = repo.signInWithGoogle();
      first.complete(http.Response(jsonEncode({'data': exchange('B')}), 200));
      await expectation;
      expect((await current)!.profile.id, 'C');
      expect(store.token, 'C' * 43);
      expect(calls, 2);
    },
  );

  test(
    'timeout retry carries the same explicit key, not a second send operation',
    () async {
      final store = MemoryStore();
      final observed = <String?>[];
      final client = MockClient((request) async {
        observed.add(request.headers['Idempotency-Key']);
        expect(jsonDecode(request.body), {'phone': '0981234567'});
        if (observed.length == 1) throw TimeoutException('timeout');
        return http.Response(
          jsonEncode({
            'data': {
              'challengeId': 'challenge',
          'maskedPhone': '+84 *** *** 567',
              'expiresAt': '2026-10-19T06:05:00Z',
              'resendAt': '2026-10-19T06:01:00Z',
              'deliveryStatus': 'unknown',
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final repo = RemoteExtendedAuthRepository(
        gateway: RemoteGateway(
          HttpApiTransport(
            baseUrl: Uri.parse('https://test.invalid/api/v1'),
            client: client,
            sessions: store,
          ),
        ),
        sessions: store,
        coordinator: AuthOperationCoordinator(),
      );
      await expectLater(
        repo.requestPhoneOtp('0981234567', 'same-request-key-1'),
        throwsA(isA<XlandFailure>()),
      );
      expect(
        (await repo.requestPhoneOtp('0981234567', 'same-request-key-1')).id,
        'challenge',
      );
      expect(observed, ['same-request-key-1', 'same-request-key-1']);
    },
  );
}
