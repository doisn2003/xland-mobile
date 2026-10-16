import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/mappers/domain_mappers.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class _SessionStore implements SessionStore {
  String? token;
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
}

void main() {
  final fixture = wireObject(
    jsonDecode(File('test/data/fixtures/c3_samples.json').readAsStringSync()),
  );
  final samples = wireObject(fixture['samples']);
  HttpApiTransport transport(
    http.Client client,
    _SessionStore store, {
    Duration? timeout,
  }) => HttpApiTransport(
    baseUrl: Uri.parse('https://example.invalid/api/v1'),
    client: client,
    sessions: store,
    timeout: timeout ?? const Duration(seconds: 1),
  );
  TypeMatcher<XlandFailure> failure(FailureCode code) =>
      isA<XlandFailure>().having((e) => e.code, 'code', code);
  const filter = PropertyFilter(
    regions: [Region.north],
    areaBands: [AreaBand.from100To200],
    landTypes: [],
    savedOnly: false,
    sort: PropertySort.priceAsc,
  );

  test(
    'wire mapper keeps exact VND and null media; unknown enums are rejected',
    () {
      final property = Map<String, Object?>.from(
        wireObject(samples['Property']),
      );
      property['priceTotal'] = '9007199254740993';
      final mapped = mapProperty(property);
      expect(mapped.priceTotal.wireValue, '9007199254740993');
      expect(mapped.media.first.url, isNull);
      property['status'] = 'unknown-success';
      expect(() => mapProperty(property), throwsFormatException);
    },
  );
  test('legal mapper requires typed size and preserves pending date null', () {
    final summary = mapLegalSummary(samples['LegalSummary']);
    expect(summary.verifiedCount, 4);
    expect(summary.totalCount, 6);
    expect(summary.items.last.checkedDate, isNull);
    expect(summary.documents.first.sizeBytes, 2300000);
    final bad = Map<String, Object?>.from(wireObject(samples['Property']));
    bad['priceTotal'] = 2400000000;
    expect(() => mapProperty(bad), throwsFormatException);
  });
  test('search maps envelope and encodes area/category/open upper budget without display money', () async {
    final store = _SessionStore();
    final client = MockClient((req) async {
      expect(req.url.queryParameters['areaBands'], 'from_100_to_200');
      expect(req.url.queryParameters.containsKey('maxPriceVnd'), isFalse);
      expect(req.url.queryParameters['sort'], 'price_asc');
      return http.Response(
        jsonEncode({
          'data': [samples['Property']],
          'meta': {
            'total': 4,
            'selectedCriteriaCount': 2,
            'nextCursor': 'opaque-cursor',
            'hasMore': true,
          },
        }),
        200,
        headers: {
          'x-request-id': 'search-1',
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    final result = await RemotePropertyRepository(
      RemoteGateway(transport(client, store)),
    ).search(filter, const PageQuery(limit: 1));
    expect(result.total, 4);
    expect(result.page.nextCursor, 'opaque-cursor');
    expect(result.page.items.single.code, 'XL-028');
    client.close();
  });
  test('login keeps password bytes, stores opaque token only in data and logout revokes', () async {
    final store = _SessionStore();
    final token = 'A' * 43;
    var revoked = false;
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        final body = wireObject(jsonDecode(req.body));
        expect(body['username'], ' Demo ');
        expect(body['password'], ' password with spaces ');
        expect(req.headers.containsKey('authorization'), isFalse);
        return http.Response(
          jsonEncode({
            'data': {'accessToken': token, 'session': samples['Session']},
          }),
          200,
        );
      }
      expect(req.headers['authorization'], 'Bearer $token');
      revoked = true;
      return http.Response('{"data":null}', 200);
    });
    final repo = RemoteAccountRepository(
      RemoteGateway(transport(client, store)),
      store,
    );
    final session = await repo.signIn(
      const SignInInput(username: ' Demo ', password: ' password with spaces '),
    );
    expect(session.profile.displayName, 'Anh Nam');
    expect(store.token, token);
    await repo.signOut();
    expect(revoked, isTrue);
    expect(store.token, isNull);
    client.close();
  });
  test('401 clears local session and getSession becomes null while other calls fail', () async {
    final store = _SessionStore()..token = 'B' * 43;
    final client = MockClient(
      (_) async => http.Response(
        '{"error":{"code":"UNAUTHENTICATED","message":"Đăng nhập lại"},"requestId":"auth-1"}',
        401,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'x-request-id': 'auth-1',
        },
      ),
    );
    final repo = RemoteAccountRepository(
      RemoteGateway(transport(client, store)),
      store,
    );
    expect(await repo.getSession(), isNull);
    expect(store.token, isNull);
    await expectLater(
      repo.getProfile(),
      throwsA(failure(FailureCode.unauthenticated)),
    );
    client.close();
  });
  test('policy failure preserves stable code/request ID and does not become success', () async {
    final store = _SessionStore();
    final client = MockClient(
      (_) async => http.Response(
        '{"error":{"code":"POLICY_NOT_CONFIGURED","message":"Policy pending"}}',
        409,
        headers: {'x-request-id': 'policy-1'},
      ),
    );
    await expectLater(
      RemotePropertyRepository(RemoteGateway(transport(client, store)))
          .getProperty('id'),
      throwsA(
        failure(FailureCode.policyNotConfigured)
            .having((e) => e.requestId, 'request ID', 'policy-1'),
      ),
    );
    client.close();
  });
  test('timeout does not auto-retry or report a saved mutation', () async {
    final pending = Completer<http.Response>();
    var attempts = 0;
    final client = MockClient((_) {
      attempts++;
      return pending.future;
    });
    final repo = RemotePropertyRepository(
      RemoteGateway(
        transport(
          client,
          _SessionStore(),
          timeout: const Duration(milliseconds: 5),
        ),
      ),
    );
    await expectLater(
      repo.setSaved('id', true),
      throwsA(failure(FailureCode.timeout)),
    );
    expect(attempts, 1);
    pending.complete(
      http.Response('{"data":{"active":true,"count":null}}', 200),
    );
    client.close();
  });
  test('not-yet-wired feature fails explicitly before network', () async {
    final client = MockClient(
      (_) async => throw StateError('must not call network'),
    );
    final repo = RemoteAccountRepository(
      RemoteGateway(
        transport(client, _SessionStore()),
        availableOperations: const {'U05'},
      ),
      _SessionStore(),
    );
    await expectLater(
      repo.getSettings(),
      throwsA(failure(FailureCode.featureNotEnabled)),
    );
    client.close();
  });
  test('unknown response enum becomes typed failure with request ID', () async {
    final property = Map<String, Object?>.from(wireObject(samples['Property']))
      ..['status'] = 'unexpected_status';
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'data': property}),
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'x-request-id': 'mapping-1',
        },
      ),
    );
    await expectLater(
      RemotePropertyRepository(
        RemoteGateway(transport(client, _SessionStore())),
      ).getProperty('id'),
      throwsA(
        failure(FailureCode.internalError)
            .having((e) => e.requestId, 'request ID', 'mapping-1'),
      ),
    );
    client.close();
  });
  test('invalid JSON and malformed login preserve request ID and do not store a token', () async {
    final store = _SessionStore();
    final client = MockClient(
      (_) async =>
          http.Response('not json', 200, headers: {'x-request-id': 'json-1'}),
    );
    await expectLater(
      RemotePropertyRepository(RemoteGateway(transport(client, store)))
          .getProperty('id'),
      throwsA(
        failure(FailureCode.internalError)
            .having((e) => e.requestId, 'request ID', 'json-1'),
      ),
    );
    client.close();
    final loginClient = MockClient(
      (_) async => http.Response(
        '{"data":{"accessToken":"invalid","session":{}}}',
        200,
        headers: {'x-request-id': 'login-1'},
      ),
    );
    final repo = RemoteAccountRepository(
      RemoteGateway(transport(loginClient, store)),
      store,
    );
    await expectLater(
      repo.signIn(
        const SignInInput(username: 'demo', password: 'valid-password'),
      ),
      throwsA(
        failure(FailureCode.internalError)
            .having((e) => e.requestId, 'request ID', 'login-1'),
      ),
    );
    expect(store.token, isNull);
    loginClient.close();
  });
  test('failed logout clears local token while reporting server revocation failure', () async {
    final store = _SessionStore()..token = 'C' * 43;
    final client = MockClient(
      (_) async => throw http.ClientException('unavailable'),
    );
    final repo = RemoteAccountRepository(
      RemoteGateway(transport(client, store)),
      store,
    );
    await expectLater(repo.signOut(), throwsA(failure(FailureCode.offline)));
    expect(store.token, isNull);
    client.close();
  });
}
