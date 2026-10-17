import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Opt-in synthetic local provider exercise; never used by production repositories.
/// No bearer token, document entitlement, or real property media is implied.
final class DemoAssetClient {
  DemoAssetClient(
    this.client,
    this.baseUrl, {
    this.timeout = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    if (baseUrl.scheme != 'http' ||
        !['127.0.0.1', 'localhost'].contains(baseUrl.host)) {
      throw ArgumentError('Synthetic demo requires a loopback HTTP origin');
    }
  }
  final http.Client client;
  final Uri baseUrl;
  final Duration timeout;
  final DateTime Function() now;

  Future<Uint8List> load(
    String path, {
    required String mimeType,
    required DateTime expiresAt,
    int maxBytes = 1024 * 1024,
  }) async {
    if (!expiresAt.isAfter(now())) throw StateError('Demo link expired');
    final uri = baseUrl.resolve(path);
    if (uri.origin != baseUrl.origin) {
      throw ArgumentError('Demo origin changed');
    }
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await client.send(request).timeout(timeout);
    final result = Completer<Uint8List>();
    final bytes = BytesBuilder(copy: false);
    StreamSubscription<List<int>>? subscription;
    try {
      if (response.statusCode != 200 ||
          response.headers['content-type']?.split(';').first != mimeType ||
          response.headers['x-xland-demo'] != 'synthetic-project-created') {
        throw StateError('Synthetic demo transfer unavailable or invalid');
      }
      subscription = response.stream.listen(
        (chunk) {
          if (result.isCompleted) return;
          if (bytes.length + chunk.length > maxBytes) {
            result.completeError(StateError('Demo exceeds byte limit'));
          } else {
            bytes.add(chunk);
          }
        },
        onError: (Object e, StackTrace st) {
          if (!result.isCompleted) result.completeError(e, st);
        },
        onDone: () {
          if (!result.isCompleted) result.complete(bytes.takeBytes());
        },
      );
      final data = await result.future.timeout(timeout);
      if (response.contentLength != null &&
          data.length != response.contentLength) {
        throw StateError('Incomplete demo transfer');
      }
      return data;
    } finally {
      if (subscription != null) {
        await subscription.cancel();
      } else {
        await response.stream.listen((_) {}).cancel();
      }
    }
  }
}
