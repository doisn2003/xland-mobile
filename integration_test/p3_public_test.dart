// W0 public reads only. This suite does not certify W1 UI/auth acceptance.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/demo/demo_media_repositories.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import 'support/trace_client.dart';

class GuestSessions implements SessionStore {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> saveAccessToken({required String accessToken}) async =>
      throw StateError('W0 must never sign in');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment('XLAND_API_BASE_URL');
  const media = String.fromEnvironment('XLAND_DEMO_MEDIA_BASE_URL');
  final client = TraceClient(http.Client());
  late RemoteGateway g;
  setUpAll(() {
    if (base.isEmpty) throw StateError('Explicit isolated API URL required');
    g = RemoteGateway(
      HttpApiTransport(
        baseUrl: Uri.parse(base),
        client: client,
        sessions: GuestSessions(),
        allowLocalHttp: true,
      ),
    );
  });
  tearDownAll(() {
    IntegrationTestWidgetsFlutterBinding.instance.reportData = {
      'http': client.records,
    };
    client.close();
  });
  testWidgets('E01/public: real feed identity, two pages and typed DEMO URL', (
    _,
  ) async {
    final feed = RemoteFeedRepository(g);
    final first = await feed.getFeed(const PageQuery(limit: 20));
    expect(first.items.length, 20);
    expect(first.hasMore, isTrue);
    final next = await feed.getFeed(
      PageQuery(limit: 20, cursor: first.nextCursor),
    );
    expect(
      first.items
          .map((v) => v.id)
          .toSet()
          .intersection(next.items.map((v) => v.id).toSet()),
      isEmpty,
    );
    final properties = RemotePropertyRepository(g);
    for (final v in first.items.take(2)) {
      expect((await feed.getVideo(v.id)).propertyId, v.propertyId);
      expect((await properties.getProperty(v.propertyId)).id, v.propertyId);
    }
    expect(first.items.take(2).map((v) => v.propertyId).toSet().length, 2);
    if (media.isNotEmpty) {
      final projected = DemoMediaOverlay(Uri.parse(media))
          .video(first.items.first);
      expect(projected.id, first.items.first.id);
      expect(projected.propertyId, first.items.first.propertyId);
      final response = await client.get(
        projected.media.url!,
        headers: {'Range': 'bytes=0-15'},
      );
      expect(response.statusCode, 206);
      expect(response.headers['content-type'], 'video/mp4');
      expect(response.bodyBytes.length, 16);
    }
  });
  testWidgets('E02/E09/public: same-ID property/legal/area, invalid UUID 404', (
    _,
  ) async {
    final video = (await RemoteFeedRepository(
      g,
    ).getFeed(const PageQuery(limit: 1))).items.single;
    final properties = RemotePropertyRepository(g);
    expect(
      (await properties.getLegal(video.propertyId)).propertyId,
      video.propertyId,
    );
    final area = await properties.getArea(video.propertyId);
    expect(area.propertyId, video.propertyId);
    expect(area.location.radiusM, greaterThan(0));
    expect(area.externalMapUrl, isNull);
    await expectLater(
      properties.getProperty('ffffffff-ffff-4fff-8fff-ffffffffffff'),
      throwsA(
        isA<XlandFailure>().having((e) => e.code, 'code', FailureCode.notFound),
      ),
    );
  });
  testWidgets('E04/public: guest private history is 401', (_) async {
    await expectLater(
      RemoteBookingRepository(g).getHistory(const PageQuery()),
      throwsA(
        isA<XlandFailure>().having(
          (e) => e.code,
          'code',
          FailureCode.unauthenticated,
        ),
      ),
    );
  });
  testWidgets('E08/public: current events and K01/K02 read-only IDs', (
    _,
  ) async {
    final events = RemoteEventRepository(g);
    final page = await events.getEvents(const PageQuery(limit: 10));
    expect(page.items, isNotEmpty);
    expect(
      (await events.getEvent(page.items.first.id)).id,
      page.items.first.id,
    );
    final clubs = RemoteClubRepository(g);
    final rows = await clubs.getClubs(const PageQuery());
    expect(rows.items, isNotEmpty);
    expect((await clubs.getClub(rows.items.first.id)).id, rows.items.first.id);
  });
}
