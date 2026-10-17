import '../datasources/remote/api_transport.dart';

/// Explicit development overlay: keep real API identity, paging, auth and writes.
/// Only illustrative videos with no source receive project-generated demo media.
final class DemoMediaTransport implements ApiTransport {
  DemoMediaTransport(this.delegate, this.baseUrl, {this.scenario = 'normal'}) {
    if (baseUrl.scheme != 'http' ||
        !['localhost', '127.0.0.1', '10.0.2.2'].contains(baseUrl.host) ||
        !['normal', 'expired', 'unavailable'].contains(scenario)) {
      throw ArgumentError('Synthetic media requires an explicit local demo');
    }
  }
  final ApiTransport delegate;
  final Uri baseUrl;
  final String scenario;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final response = await delegate.send(request);
    final videoPath =
        request.path == '/feed' ||
        request.path == '/me/saved-videos' ||
        RegExp(r'^/consultants/[^/]+/videos$').hasMatch(request.path) ||
        RegExp(r'^/videos/[^/]+$').hasMatch(request.path);
    if (request.method != 'GET' || !videoPath || response.statusCode != 200) {
      return response;
    }
    Object? overlay(Object? value) {
      if (value is! Map<String, Object?>) return value;
      final media = value['media'];
      if (value['isIllustrative'] != true ||
          media is! Map<String, Object?> ||
          media['isIllustrative'] != true ||
          media['kind'] != 'video' ||
          media['url'] != null) {
        return value;
      }
      final path = switch (scenario) {
        'expired' => '/expired',
        'unavailable' => '/broken',
        _ => '/demo-video.mp4',
      };
      return <String, Object?>{
        ...value,
        'media': <String, Object?>{
          ...media,
          'url': baseUrl.resolve(path).toString(),
          'thumbnailUrl': baseUrl.resolve('/demo-poster.png').toString(),
          'durationSeconds': 4,
          'altText':
              'XLAND DEMO ONLY — video tổng hợp, không phải cảnh đất thật',
        },
      };
    }

    final data = response.body['data'];
    return ApiResponse(
      statusCode: response.statusCode,
      requestId: response.requestId,
      body: {
        ...response.body,
        'data': data is List ? data.map(overlay).toList() : overlay(data),
      },
    );
  }
}
