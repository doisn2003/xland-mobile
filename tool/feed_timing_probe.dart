import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class _Guest implements SessionStore {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> saveAccessToken({required String accessToken}) async =>
      throw StateError('Read-only guest timing probe');
}

Future<void> main(List<String> args) async {
  final base = Uri.parse(args.single);
  if (base.host != '127.0.0.1') {
    throw ArgumentError('Timing probe requires the owned loopback API');
  }
  final client = http.Client();
  final results = <Map<String, Object?>>[];
  try {
    final transport = HttpApiTransport(
      baseUrl: base,
      client: client,
      sessions: _Guest(),
      allowLocalHttp: true,
    );
    final repository = RemoteFeedRepository(RemoteGateway(transport));
    for (final limit in [10, 20, 50]) {
      for (var sample = 0; sample < 3; sample++) {
        String? cursor;
        final seen = <String>{};
        for (var page = 0; page < 2; page++) {
          final watch = Stopwatch()..start();
          final value = await repository.getFeed(
            PageQuery(limit: limit, cursor: cursor),
          );
          watch.stop();
          if (value.items.isEmpty || value.items.any((v) => !seen.add(v.id))) {
            throw StateError('Nonempty disjoint first/next pages required');
          }
          results.add({
            'limit': limit,
            'page': page,
            'sample': sample,
            'milliseconds': watch.elapsedMilliseconds,
            'items': value.items.length,
            'hasMore': value.hasMore,
          });
          cursor = value.nextCursor;
          if (page == 0 && cursor == null) {
            throw StateError('Fixture must exercise a real next cursor');
          }
        }
      }
    }
    final summaries = <Map<String, Object?>>[];
    for (final limit in [10, 20, 50]) {
      for (var page = 0; page < 2; page++) {
        final times =
            results
                .where((r) => r['limit'] == limit && r['page'] == page)
                .map((r) => r['milliseconds']! as int)
                .toList()
              ..sort();
        summaries.add({
          'limit': limit,
          'page': page,
          'samples': times.length,
          'minMs': times.first,
          'medianMs': times[times.length ~/ 2],
          'maxMs': times.last,
        });
      }
    }
    stdout.writeln(
      jsonEncode({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'transportTimeoutSeconds': transport.timeout.inSeconds,
        'results': results,
        'summaries': summaries,
        'readOnlyGuest': true,
        'slaClaim': false,
      }),
    );
  } finally {
    client.close();
  }
}
