import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Records IDs/status and hashes; never auth bodies, headers, response data,
/// contacts, raw cursor or raw idempotency key.
class TraceClient extends http.BaseClient {
  TraceClient(this.delegate);
  final http.Client delegate;
  final List<Map<String, Object?>> records = [];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final watch = Stopwatch()..start();
    final auth = request.url.path.contains('/auth/');
    final body = request is http.Request ? request.bodyBytes : null;
    final key = request.headers['Idempotency-Key'];
    final record = <String, Object?>{
      'method': request.method,
      'path': request.url.path,
      'payloadSha256': auth || body == null
          ? null
          : sha256.convert(body).toString(),
      'keySha256': key == null
          ? null
          : sha256.convert(utf8.encode(key)).toString(),
      'authPayloadRedacted': auth,
    };
    try {
      final response = await delegate.send(request);
      record.addAll({
        'status': response.statusCode,
        'requestId': response.headers['x-request-id'],
      });
      return response;
    } catch (_) {
      record['transportError'] = true;
      rethrow;
    } finally {
      record['headersElapsedMs'] = watch.elapsedMilliseconds;
      records.add(record);
    }
  }

  @override
  void close() => delegate.close();
}
