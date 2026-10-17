import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xland_mobile/data/demo/demo_asset_client.dart';

void main() {
  test('demo rejects expiry and external origin before sending', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('x', 200);
    });
    addTearDown(client.close);
    final demo = DemoAssetClient(client, Uri.parse('http://127.0.0.1:5560'));
    await expectLater(
      demo.load(
        '/demo-guide.txt',
        mimeType: 'text/plain',
        expiresAt: DateTime(2000),
      ),
      throwsStateError,
    );
    await expectLater(
      demo.load(
        'https://external.invalid/file',
        mimeType: 'text/plain',
        expiresAt: DateTime(2100),
      ),
      throwsArgumentError,
    );
    expect(calls, 0);
  });
  test(
    'demo timeout cancels stream; no completed download is reported',
    () async {
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          stream.stream,
          200,
          headers: {
            'content-type': 'text/plain',
            'x-xland-demo': 'synthetic-project-created',
          },
        ),
      );
      addTearDown(client.close);
      final demo = DemoAssetClient(
        client,
        Uri.parse('http://127.0.0.1:5560'),
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        demo.load(
          '/demo-guide.txt',
          mimeType: 'text/plain',
          expiresAt: DateTime(2100),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(cancelled, true);
      await stream.close();
    },
  );
}
