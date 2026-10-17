import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/demo/demo_media_repositories.dart';
import 'package:xland_mobile/data/datasources/remote/api_transport.dart';
import 'package:xland_mobile/data/mappers/domain_mappers.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class _Transport implements ApiTransport {
  _Transport(this.body);
  final Map<String, Object?> body;
  ApiRequest? last;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    last = request;
    return ApiResponse(statusCode: 200, body: body);
  }
}

void main() {
  final fixture = jsonDecode(
    File('../brain/logs/agent-c/fixtures/v0.1.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final wire = Map<String, Object?>.from(
    (fixture['feedVideos'] as List).first as Map,
  );
  test('real typed repository parses wire BEFORE local demo overlay; identity and paging retained', () async {
    final source = _Transport({
      'data': [wire],
      'meta': {'hasMore': true, 'nextCursor': 'opaque-fixture', 'total': null},
    });
    final delegate = RemoteFeedRepository(RemoteGateway(source));
    final repo = DemoMediaFeedRepository(
      delegate,
      DemoMediaOverlay(Uri.parse('http://127.0.0.1:5560')),
    );
    final result = await repo.getFeed(const PageQuery(limit: 2));
    final video = result.items.single;
    expect(video.id, wire['id']);
    expect(video.propertyId, wire['propertyId']);
    expect(video.property.id, wire['propertyId']);
    expect(video.media.url.toString(), 'http://127.0.0.1:5560/demo-video.mp4');
    expect(result.nextCursor, 'opaque-fixture');
    expect(result.hasMore, true);
    expect((wire['media'] as Map)['url'], null);
    expect(
      () => mapMediaAsset({
        ...wire['media'] as Map<String, Object?>,
        'url': 'http://127.0.0.1:5560/demo-video.mp4',
      }),
      throwsFormatException,
      reason: 'Production HTTPS wire validation must remain strict',
    );
  });
  test(
    'mutations are delegated and existing HTTPS media never replaced',
    () async {
      final source = _Transport({
        'data': {'active': true, 'count': 1},
      });
      final overlay = DemoMediaOverlay(Uri.parse('http://127.0.0.1:5560'));
      final repo = DemoMediaFeedRepository(
        RemoteFeedRepository(RemoteGateway(source)),
        overlay,
      );
      expect((await repo.setLiked('video-id', true)).active, true);
      expect(source.last!.path, '/videos/video-id/like');
      expect(source.last!.method, 'PUT');
      final real = mapFeedVideo({
        ...wire,
        'media': {
          ...wire['media'] as Map<String, Object?>,
          'url': 'https://owned.example/video.mp4',
        },
      });
      expect(overlay.video(real), same(real));
    },
  );
  test('saved/consultant projections use same typed policy; error source and external origin are explicit', () async {
    final source = _Transport({
      'data': [wire],
      'meta': {'hasMore': false, 'nextCursor': null, 'total': null},
    });
    final overlay = DemoMediaOverlay(
      Uri.parse('http://10.0.2.2:5560'),
      scenario: 'expired',
    );
    final repo = DemoMediaFeedRepository(
      RemoteFeedRepository(RemoteGateway(source)),
      overlay,
    );
    expect(
      (await repo.getSavedVideos(const PageQuery())).items.single.media.url
          .toString(),
      'http://10.0.2.2:5560/expired',
    );
    final consultants = DemoMediaConsultantRepository(
      RemoteConsultantRepository(RemoteGateway(source)),
      overlay,
    );
    expect(
      (await consultants.getVideos(
        'consultant-id',
        const PageQuery(),
      )).items.single.media.url.toString(),
      'http://10.0.2.2:5560/expired',
    );
    expect(
      () => DemoMediaOverlay(Uri.parse('https://external.example')),
      throwsArgumentError,
    );
  });
}
