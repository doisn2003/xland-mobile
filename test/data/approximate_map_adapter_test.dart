import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xland_mobile/data/providers/approximate_map_adapter.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

const location = ApproximateLocation(
  latitude: 10.8,
  longitude: 106.7,
  radiusM: 1000,
  label: 'DEMO approximate area',
);
Matcher failure(FailureCode code) =>
    isA<XlandFailure>().having((e) => e.code, 'code', code);

void main() {
  test('unconfigured provider fails honestly without network', () async {
    final client = MockClient((_) => throw StateError('Must not request'));
    await expectLater(
      ApproximateMapAdapter(client: client).load(location),
      throwsA(failure(FailureCode.featureNotEnabled)),
    );
  });
  test('only approximate point reaches approved HTTPS factory', () async {
    final adapter = ApproximateMapAdapter(
      client: MockClient((r) async {
        expect(r.url.host, 'maps.example.test');
        expect(r.followRedirects, isFalse);
        return http.Response.bytes(
          [137, 80, 78, 71],
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
      allowedHost: 'maps.example.test',
      attribution: 'DEMO test provider',
      endpoint: (p) {
        expect(p.radiusM, 1000);
        return Uri.https('maps.example.test', '/preview');
      },
    );
    expect(await adapter.load(location), [137, 80, 78, 71]);
  });
  for (final status in [302, 403, 429, 503]) {
    test('provider $status is an error, never a successful map', () async {
      final adapter = ApproximateMapAdapter(
        client: MockClient((_) async => http.Response('', status)),
        endpoint: (_) => Uri.https('maps.example.test', '/preview'),
        allowedHost: 'maps.example.test',
        attribution: 'DEMO',
      );
      await expectLater(
        adapter.load(location),
        throwsA(
          failure(
            status == 429
                ? FailureCode.rateLimited
                : FailureCode.upstreamUnavailable,
          ),
        ),
      );
    });
  }
  for (final mode in ['offline', 'timeout', 'mime', 'empty', 'host']) {
    test('map $mode remains distinguishable from success', () async {
      final adapter = ApproximateMapAdapter(
        client: MockClient((_) async {
          if (mode == 'offline') throw http.ClientException('synthetic');
          if (mode == 'timeout') throw TimeoutException('synthetic');
          return http.Response(
            mode == 'empty' ? '' : '<html>error</html>',
            200,
            headers: {
              'content-type': mode == 'mime' ? 'text/html' : 'image/png',
            },
          );
        }),
        endpoint: (_) => Uri.https(
          mode == 'host' ? 'unapproved.test' : 'maps.example.test',
          '/preview',
        ),
        allowedHost: 'maps.example.test',
        attribution: 'DEMO',
      );
      await expectLater(
        adapter.load(location),
        throwsA(
          mode == 'host'
              ? isA<ArgumentError>()
              : failure(switch (mode) {
                  'offline' => FailureCode.offline,
                  'timeout' => FailureCode.timeout,
                  _ => FailureCode.upstreamUnavailable,
                }),
        ),
      );
    });
  }
}
