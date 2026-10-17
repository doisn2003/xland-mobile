import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/demo/demo_media_transport.dart';
import 'package:xland_mobile/data/datasources/remote/api_transport.dart';

final class _Transport implements ApiTransport {
  _Transport(this.response);
  final ApiResponse response;
  ApiRequest? last;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    last = request;
    return response;
  }
}

void main() {
  final item = <String, Object?>{
    'id': 'video-canonical',
    'propertyId': 'property-canonical',
    'isIllustrative': true,
    'media': <String, Object?>{
      'id': 'media-canonical',
      'kind': 'video',
      'url': null,
      'isIllustrative': true,
    },
  };
  test(
    'explicit demo preserves identity, original data and paging metadata',
    () async {
      final source = _Transport(
        ApiResponse(
          statusCode: 200,
          requestId: 'request-id',
          body: {
            'data': [item],
            'meta': {'nextCursor': 'opaque', 'hasMore': true},
          },
        ),
      );
      final demo = DemoMediaTransport(
        source,
        Uri.parse('http://127.0.0.1:5560'),
      );
      final response = await demo.send(
        const ApiRequest(method: 'GET', path: '/feed'),
      );
      final video =
          (response.body['data'] as List).single as Map<String, Object?>;
      expect(video['id'], item['id']);
      expect(video['propertyId'], item['propertyId']);
      expect(
        (video['media'] as Map)['url'],
        'http://127.0.0.1:5560/demo-video.mp4',
      );
      expect((video['media'] as Map)['altText'], contains('DEMO ONLY'));
      expect((item['media'] as Map)['url'], null);
      expect(response.body['meta'], same(source.response.body['meta']));
      expect(response.requestId, 'request-id');
    },
  );
  test('demo never alters writes, failures or existing real media', () async {
    final source = _Transport(
      ApiResponse(statusCode: 200, body: {'data': item}),
    );
    final demo = DemoMediaTransport(source, Uri.parse('http://127.0.0.1:5560'));
    const write = ApiRequest(
      method: 'POST',
      path: '/videos/video-canonical/comments',
      body: {'text': 'demo'},
      idempotencyKey: 'retained-original-key',
    );
    expect(await demo.send(write), same(source.response));
    expect(source.last, same(write));
    final failure = _Transport(
      const ApiResponse(
        statusCode: 401,
        body: {
          'error': {'code': 'UNAUTHENTICATED'},
        },
      ),
    );
    expect(
      await DemoMediaTransport(
        failure,
        demo.baseUrl,
      ).send(const ApiRequest(method: 'GET', path: '/feed')),
      same(failure.response),
    );
    final real = {
      ...item,
      'media': {
        ...item['media'] as Map<String, Object?>,
        'url': 'https://owned.example/video.mp4',
      },
    };
    final realSource = _Transport(
      ApiResponse(statusCode: 200, body: {'data': real}),
    );
    final response = await DemoMediaTransport(
      realSource,
      demo.baseUrl,
    ).send(const ApiRequest(method: 'GET', path: '/videos/canonical'));
    expect(response.body['data'], same(real));
  });
  test('demo error scenarios and external-origin guard are explicit', () async {
    final source = _Transport(
      ApiResponse(statusCode: 200, body: {'data': item}),
    );
    expect(
      () => DemoMediaTransport(source, Uri.parse('https://external.invalid')),
      throwsArgumentError,
    );
    final demo = DemoMediaTransport(
      source,
      Uri.parse('http://10.0.2.2:5560'),
      scenario: 'expired',
    );
    final response = await demo.send(
      const ApiRequest(method: 'GET', path: '/videos/canonical'),
    );
    expect(
      ((response.body['data'] as Map)['media'] as Map)['url'],
      'http://10.0.2.2:5560/expired',
    );
  });
}
