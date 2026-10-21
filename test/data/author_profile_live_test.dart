import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class _GuestSessions implements SessionStore {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> saveAccessToken({required String accessToken}) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> clearIfMatches({required String accessToken}) async {}
}

void main() {
  const base = String.fromEnvironment('XLAND_LIVE_API_BASE_URL');
  test(
    'real deployed API opens Ngọc Anh and only her public videos',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final feed = RemoteFeedRepository(
        RemoteGateway(
          HttpApiTransport(
            baseUrl: Uri.parse(base),
            client: client,
            sessions: _GuestSessions(),
            timeout: const Duration(seconds: 15),
          ),
        ),
      );
      const author = '4263a899-6bef-5103-aaf0-4afc2b410e1a';
      const source = 'f20c71d7-81f9-5f2e-a048-43d44c3f7a9c';
      final profile = await feed.getAuthorProfile(author);
      expect(profile.author.id, author);
      expect(profile.author.displayName, 'Ngọc Anh');
      expect(profile.consultantId, isNull);
      final videos = <FeedVideo>[];
      String? cursor;
      do {
        final page = await feed.getAuthorVideos(
          author,
          PageQuery(limit: 50, cursor: cursor),
        );
        videos.addAll(page.items);
        cursor = page.hasMore ? page.nextCursor : null;
      } while (cursor != null);
      expect(videos.map((v) => v.id), contains(source));
      expect(videos.every((v) => v.author.id == author), isTrue);
      expect(
        videos.first.property.consultantId,
        '66560e39-13d7-5d91-a2d8-c7b81313fdf1',
      );
    },
    skip: base.isEmpty
        ? 'Opt in with XLAND_LIVE_API_BASE_URL; GET requests only.'
        : false,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
