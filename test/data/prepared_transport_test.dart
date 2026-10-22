import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/api_transport.dart';
import 'package:xland_mobile/data/demo/prepared_snapshot.dart';
import 'package:xland_mobile/data/demo/prepared_transport.dart';
import 'package:xland_mobile/domain/failures/xland_failure.dart';

class MemorySessions implements SessionStore {
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

  @override
  Future<void> clearIfMatches({required String accessToken}) async {
    if (token == accessToken) token = null;
  }
}

class MemoryCache implements PreparedStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class Remote implements ApiTransport {
  Remote(this.work);
  final Future<ApiResponse> Function(ApiRequest) work;
  final calls = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) {
    calls.add(request);
    return work(request);
  }
}

final time = DateTime.utc(2026, 10, 22, 16);
Json property(String id, {bool saved = false, String price = '2400000000'}) => {
  'id': id,
  'title': 'Lô $id',
  'code': id,
  'provinceName': 'Hà Nội',
  'districtName': 'Long Biên',
  'region': 'north',
  'category': 'residential',
  'provinceCode': '01',
  'districtCode': '001',
  'landType': 'residential',
  'priceTotal': price,
  'areaM2': '120',
  'roadWidthM': '5',
  'updatedAt': '2026-10-22T12:00:00Z',
  'isSaved': saved,
};
ApiResponse list(List<Json> rows) => ApiResponse(
  statusCode: 200,
  body: {
    'data': rows,
    'meta': {'hasMore': false, 'nextCursor': null, 'total': rows.length},
  },
);
PreparedSnapshot snapshot() => PreparedSnapshot.fromJson({
  'version': 1,
  'preparedAt': time.toIso8601String(),
  'apiOrigin': 'https://api.xland.test/api/v1',
  'entries': {
    '/properties': list([property('old')]).body,
  },
  'media': <String, Object?>{},
  'tiles': <String, Object?>{},
});
const get = ApiRequest(method: 'GET', path: '/properties');
Future<void> settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

void main() {
  test('cached content appears first, then an admin-created property reaches the open screen', () async {
    final live = Completer<ApiResponse>();
    final remote = Remote((_) => live.future);
    final cache = PreparedTransport(
      remote: remote,
      sessions: MemorySessions(),
      snapshot: snapshot(),
      store: MemoryCache(),
      now: () => time,
    );
    final changed = cache.contentChanges.first;
    final initial = await cache.send(get);
    expect((initial.body['data']! as List).length, 1);
    live.complete(list([property('new-from-admin'), property('old')]));
    expect(await changed, contains('/properties'));
    final updated = await cache.send(get);
    expect(
      ((updated.body['data']! as List).first as Json)['id'],
      'new-from-admin',
    );
    cache.dispose();
  });

  test('manual reload starts a new server read after an older background read finishes', () async {
    final first = Completer<ApiResponse>(), second = Completer<ApiResponse>();
    var reads = 0;
    final remote = Remote((_) => (++reads == 1 ? first : second).future);
    final cache = PreparedTransport(
      remote: remote,
      sessions: MemorySessions(),
      snapshot: snapshot(),
      store: MemoryCache(),
      now: () => time,
    );
    await cache.send(get);
    final refreshing = cache.refreshContent('/properties');
    await settle();
    expect(reads, 1);
    first.complete(list([property('old')]));
    await settle();
    expect(reads, 2);
    second.complete(list([property('new-from-admin'), property('old')]));
    await refreshing;
    expect((await cache.send(get)).body['meta'], containsPair('total', 2));
    cache.dispose();
  });

  test('writes wait for the real acknowledgement and preserve the original request', () async {
    final ack = Completer<ApiResponse>();
    final remote = Remote(
      (r) async => r.method == 'PUT' ? ack.future : list([property('old')]),
    );
    final cache = PreparedTransport(
      remote: remote,
      sessions: MemorySessions(),
      snapshot: snapshot(),
      store: MemoryCache(),
      now: () => time,
    );
    await cache.send(get);
    await settle();
    const mutation = ApiRequest(
      method: 'PUT',
      path: '/properties/old/saved',
      idempotencyKey: 'request-1',
      body: {'check': 'unchanged'},
    );
    var completed = false;
    final writing = cache.send(mutation).then((r) {
      completed = true;
      return r;
    });
    await settle();
    expect(completed, false);
    expect(
      ((await cache.send(get)).body['data']! as List).first,
      containsPair('isSaved', false),
    );
    ack.complete(
      const ApiResponse(
        statusCode: 200,
        body: {
          'data': {'active': true, 'count': 1},
        },
      ),
    );
    await writing;
    expect(remote.calls.where((r) => r.method == 'PUT').single, same(mutation));
    expect(
      ((await cache.send(get)).body['data']! as List).first,
      containsPair('isSaved', true),
    );
    cache.dispose();
  });

  test(
    'failed writes do not patch the cache or enqueue a later retry',
    () async {
      var writes = 0;
      final remote = Remote((r) async {
        if (r.method != 'GET') {
          writes++;
          throw const XlandFailure(
            code: FailureCode.offline,
            message: 'offline',
          );
        }
        return list([property('old')]);
      });
      final cache = PreparedTransport(
        remote: remote,
        sessions: MemorySessions(),
        snapshot: snapshot(),
        store: MemoryCache(),
        now: () => time,
      );
      await cache.send(get);
      await settle();
      await expectLater(
        cache.send(
          const ApiRequest(method: 'PUT', path: '/properties/old/saved'),
        ),
        throwsA(isA<XlandFailure>()),
      );
      expect(
        ((await cache.send(get)).body['data']! as List).first,
        containsPair('isSaved', false),
      );
      await settle();
      expect(writes, 1);
      cache.dispose();
    },
  );

  test('an older background GET cannot undo a newer real write', () async {
    final old = Completer<ApiResponse>();
    final remote = Remote(
      (r) async => r.method == 'GET'
          ? old.future
          : const ApiResponse(
              statusCode: 200,
              body: {
                'data': {'active': true},
              },
            ),
    );
    final cache = PreparedTransport(
      remote: remote,
      sessions: MemorySessions(),
      snapshot: snapshot(),
      store: MemoryCache(),
      now: () => time,
    );
    await cache.send(get);
    await cache.send(
      const ApiRequest(method: 'PUT', path: '/properties/old/saved'),
    );
    old.complete(list([property('old')]));
    await settle();
    final data = (await cache.send(get)).body['data']! as List;
    expect(data.first, containsPair('isSaved', true));
    await settle();
    cache.dispose();
  });

  test('session, private history, availability and payment policy always remain live', () async {
    final remote = Remote(
      (_) async => const ApiResponse(statusCode: 200, body: {'data': null}),
    );
    final cache = PreparedTransport(
      remote: remote,
      sessions: MemorySessions(),
      snapshot: snapshot(),
      store: MemoryCache(),
      now: () => time,
    );
    for (final path in [
      '/auth/session',
      '/me/profile',
      '/me/bookings',
      '/booking-deposit-policy',
      '/properties/old/availability',
      '/payments/payment-1',
    ]) {
      await cache.send(ApiRequest(method: 'GET', path: path));
      await cache.send(ApiRequest(method: 'GET', path: path));
    }
    expect(remote.calls.length, 12);
    cache.dispose();
  });

  test('one authenticated account cannot reuse another account public flags or token', () async {
    final sessions = MemorySessions(), store = MemoryCache();
    final remote = Remote(
      (_) async =>
          list([property('old', saved: sessions.token == 'account-a')]),
    );
    final cache = PreparedTransport(
      remote: remote,
      sessions: sessions,
      snapshot: snapshot(),
      store: store,
      now: () => time,
    );
    sessions.token = 'account-a';
    expect(
      ((await cache.send(get)).body['data']! as List).first,
      containsPair('isSaved', true),
    );
    sessions.token = 'account-b';
    expect(
      ((await cache.send(get)).body['data']! as List).first,
      containsPair('isSaved', false),
    );
    expect(store.values.keys.join(), isNot(contains('account-a')));
    expect(store.values.values.join(), isNot(contains('account-a')));
    cache.dispose();
  });

  test(
    'public data survives restart but a session response is never persisted',
    () async {
      final sessions = MemorySessions()..token = 'account-a',
          store = MemoryCache();
      var reads = 0;
      final remote = Remote((r) async {
        reads++;
        return r.path == '/auth/session'
            ? const ApiResponse(
                statusCode: 200,
                body: {
                  'data': {'private': 'session-marker'},
                },
              )
            : list([property('old', saved: true)]);
      });
      final one = PreparedTransport(
        remote: remote,
        sessions: sessions,
        snapshot: snapshot(),
        store: store,
        now: () => time,
      );
      await one.send(get);
      await one.send(const ApiRequest(method: 'GET', path: '/auth/session'));
      one.dispose();
      final live = Completer<ApiResponse>();
      final two = PreparedTransport(
        remote: Remote((_) => live.future),
        sessions: sessions,
        snapshot: snapshot(),
        store: store,
        now: () => time,
      );
      expect(
        ((await two.send(get)).body['data']! as List).first,
        containsPair('isSaved', true),
      );
      expect(store.values.values.join(), isNot(contains('session-marker')));
      expect(reads, 2);
      live.complete(list([property('old', saved: true)]));
      await settle();
      two.dispose();
    },
  );

  test('expired snapshots require a live read instead of pretending they are current', () async {
    final remote = Remote((_) async => list([property('today')]));
    final cache = PreparedTransport(
      remote: remote,
      sessions: MemorySessions(),
      snapshot: snapshot(),
      store: MemoryCache(),
      now: () => time.add(const Duration(hours: 37)),
    );
    expect(
      ((await cache.send(get)).body['data']! as List).first,
      containsPair('id', 'today'),
    );
    expect(remote.calls.length, 1);
    cache.dispose();
  });

  test(
    'local filters preserve large monetary values, pagination and total counts',
    () {
      final s = snapshot();
      final body = list([
        property('high', price: '9007199254740993'),
        property('low', price: '2400000000'),
      ]).body;
      const request = ApiRequest(
        method: 'GET',
        path: '/properties',
        query: {
          'sort': 'price_desc',
          'limit': '1',
          'minPriceVnd': '3000000000',
        },
      );
      final response = s.project(request, body, {});
      expect(
        (response.body['data']! as List).single,
        containsPair('id', 'high'),
      );
      expect(response.body['meta'], containsPair('total', 1));
      expect(jsonEncode(response.body), contains('9007199254740993'));
    },
  );
}
