import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/demo/demo_media_repositories.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class _Guest implements SessionStore {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> saveAccessToken({required String accessToken}) async =>
      throw StateError('Guest probe must not create a session');
  @override
  Future<void> clear() async {}

  @override
  Future<void> clearIfMatches({required String accessToken}) async {}
}

Future<void> main() async {
  final client = http.Client();
  try {
    final source = HttpApiTransport(
      baseUrl: Uri.parse('http://127.0.0.1:3001/api/v1'),
      client: client,
      sessions: _Guest(),
      allowLocalHttp: true,
    );
    final repository = DemoMediaFeedRepository(
      RemoteFeedRepository(RemoteGateway(source)),
      DemoMediaOverlay(Uri.parse('http://127.0.0.1:5560')),
    );
    final page = await repository.getFeed(const PageQuery(limit: 2));
    final properties = page.items.map((v) => v.propertyId).toSet();
    if (page.items.length < 2 || properties.length < 2) {
      throw StateError('At least two videos/properties required');
    }
    for (final v in page.items) {
      if (v.propertyId != v.property.id ||
          v.media.url.toString() != 'http://127.0.0.1:5560/demo-video.mp4') {
        throw StateError('Typed feed identity/media mismatch');
      }
    }
    stdout.writeln(
      jsonEncode({
        'environment': 'supabase_mock_with_explicit_synthetic_media_overlay',
        'videoCount': page.items.length,
        'distinctPropertyCount': properties.length,
        'hasMore': page.hasMore,
        'videos': page.items
            .map(
              (v) => {
                'id': v.id,
                'propertyId': v.propertyId,
                'propertyCode': v.property.code,
                'mediaId': v.media.id,
                'mediaUrl': v.media.url.toString(),
                'isIllustrative': v.isIllustrative,
              },
            )
            .toList(),
        'feedPlaybackVerified': false,
      }),
    );
  } finally {
    client.close();
  }
}
