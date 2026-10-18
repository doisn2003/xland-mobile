import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../integration_test/support/trace_client.dart';

void main() {
  test(
    'trace excludes auth payload/headers/query/response; preserves request ID',
    () async {
      final client = TraceClient(
        MockClient(
          (_) async => http.Response(
            '{"accessToken":"secret-response"}',
            200,
            headers: {'x-request-id': 'trace-canary'},
          ),
        ),
      );
      await client.post(
        Uri.parse(
          'https://api.example.test/api/v1/auth/sessions?cursor=private-cursor',
        ),
        headers: {'Authorization': 'Bearer private-token'},
        body: '{"password":"private-password"}',
      );
      final encoded = jsonEncode(client.records);
      for (final secret in [
        'private-cursor',
        'private-token',
        'private-password',
        'secret-response',
      ]) {
        expect(encoded.contains(secret), isFalse);
      }
      expect(client.records.single['requestId'], 'trace-canary');
      expect(client.records.single['payloadSha256'], isNull);
    },
  );
  test(
    'retry evidence has stable hashes without exposing payload/key values',
    () async {
      final client = TraceClient(
        MockClient((_) async => http.Response('{}', 200)),
      );
      for (var i = 0; i < 2; i++) {
        await client.post(
          Uri.parse('https://api.example.test/api/v1/bookings'),
          headers: {'Idempotency-Key': 'synthetic-key'},
          body: '{"contactPhone":"synthetic-phone"}',
        );
      }
      expect(
        client.records[0]['payloadSha256'],
        client.records[1]['payloadSha256'],
      );
      expect(client.records[0]['keySha256'], client.records[1]['keySha256']);
    expect(client.records[0]['keySha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(client.records[0]['payloadSha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(jsonEncode(client.records).contains('synthetic-'), isFalse);
    },
  );
}
