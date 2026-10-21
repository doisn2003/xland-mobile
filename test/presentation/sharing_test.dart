import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/app/content_link.dart';
import 'package:xland_mobile/presentation/app/xland_app.dart';
import 'package:xland_mobile/presentation/features/feed/pages/shared_video_page.dart';
import 'package:xland_mobile/presentation/features/feed/widgets/video_player_item.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_detail_page.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/shared/sharing/share_sheet.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

const _propertyId = '00000000-0000-4000-8000-000000000005';
const _videoId = '00000000-0000-4000-8000-000000000020';
const _url = 'https://${ContentLink.host}/properties/$_propertyId';
const _channel = MethodChannel('dev.fluttercommunity.plus/share');

class _SharedFeed extends FakeFeedRepository {
  String? requestedId;
  bool missing = false;

  @override
  Future<FeedVideo> getVideo(String videoId) async {
    requestedId = videoId;
    if (missing) throw const XlandFailure.notFound();
    // The requested UUID is deliberately absent from the regular feed page.
    final source = await super.getVideo('feed-001');
    return FeedVideo(
      id: videoId,
      propertyId: source.propertyId,
      author: source.author,
      media: const MediaAsset(
        id: 'shared',
        kind: MediaKind.video,
        altText: 'Video được chia sẻ',
        isIllustrative: true,
      ),
      caption: 'Video riêng từ liên kết',
      approximateArea: source.approximateArea,
      property: source.property,
      likeCount: 0,
      commentCount: 0,
      viewCount: 0,
      isLiked: false,
      isSaved: false,
      publishedAt: source.publishedAt,
      isIllustrative: true,
    );
  }
}

XlandDependencies _deps(_SharedFeed feed) {
  final d = createFakeDependencies();
  return XlandDependencies(
    properties: d.properties,
    feed: feed,
    consultants: d.consultants,
    events: d.events,
    bookings: d.bookings,
    payments: d.payments,
    account: d.account,
    clubs: d.clubs,
    finance: d.finance,
    support: d.support,
    guestPreferences: d.guestPreferences,
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final shareCalls = <MethodCall>[];
  String? clipboard;
  Future<Object?> Function(MethodCall)? shareHandler;
  setUp(() {
    shareCalls.clear();
    clipboard = null;
    shareHandler = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      shareCalls.add(call);
      return shareHandler == null ? '' : shareHandler!(call);
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
  });
  tearDown(() {
    binding.platformDispatcher.clearDefaultRouteNameTestValue();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  test('only supported hosts, schemes, UUIDs and content paths navigate', () {
    for (final prefix in ['', 'https://${ContentLink.host}', 'xland://share']) {
      expect(
        ContentLink.parse('$prefix/videos/$_videoId?utm_source=zalo')?.id,
        _videoId,
      );
    }
    for (final url in [
      'https://evil.example/videos/$_videoId',
      '//evil.example/videos/$_videoId',
      'http://${ContentLink.host}/videos/$_videoId',
      '/videos/not-an-id',
      '/videos/$_videoId/extra',
      'xland://login/videos/$_videoId',
      '/account/$_videoId',
      '/videos/%2f$_videoId',
      '/videos/%FF',
    ]) {
      expect(ContentLink.parse(url), isNull, reason: url);
    }
  });

  testWidgets(
    'link loads first; copy writes only URL; native share has anchor and cancel is quiet',
    (tester) async {
      final loaded = Completer<ShareLink>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareSheet(title: 'Lô đất', loadLink: () => loaded.future),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(shareCalls, isEmpty);
      loaded.complete(
        ShareLink(url: Uri.parse(_url), title: 'Đất nền Hòa Lạc'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sao chép liên kết'));
      await tester.pumpAndSettle();
      expect(clipboard, _url);
      expect(find.text('Đã sao chép liên kết'), findsOneWidget);
      await tester.tap(find.text('Chia sẻ qua ứng dụng'));
      await tester.pumpAndSettle();
      expect(shareCalls, hasLength(1));
      final args = shareCalls.single.arguments as Map;
      expect(args['uri'], _url);
      expect(args['subject'], 'Đất nền Hòa Lạc');
      expect(args['originWidth'] as double, greaterThan(0));
      expect(find.textContaining('Thiết bị chưa mở'), findsNothing);
    },
  );

  testWidgets(
    'fetch failure can retry; native failure retains copy and no raw exception',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareSheet(
              title: 'Lô đất',
              loadLink: () async {
                if (++attempts == 1) throw StateError('private diagnostic');
                return ShareLink(url: Uri.parse(_url), title: 'Lô đất');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('private diagnostic'), findsNothing);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      shareHandler = (_) async => throw PlatformException(
        code: 'unavailable',
        message: 'private native diagnostic',
      );
      await tester.tap(find.text('Chia sẻ qua ứng dụng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Thiết bị chưa mở'), findsOneWidget);
      expect(find.textContaining('private native'), findsNothing);
      await tester.tap(find.text('Sao chép liên kết'));
      await tester.pumpAndSettle();
      expect(clipboard, _url);
    },
  );

  testWidgets(
    'closing sheet during link fetch does not update disposed state',
    (tester) async {
      final loaded = Completer<ShareLink>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareSheet(title: 'Video', loadLink: () => loaded.future),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      loaded.complete(ShareLink(url: Uri.parse(_url), title: 'Video'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('share sheet remains usable at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => ShareSheet.show(
                    context,
                    title: 'Lô đất',
                    loadLink: () async => ShareLink(
                      url: Uri.parse(_url),
                      title: 'Đất nền Hòa Lạc — thông tin chi tiết lô đất được chia sẻ',
                    ),
                  ),
                  child: const Text('Mở chia sẻ'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở chia sẻ'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sao chép liên kết'));
      await tester.tap(find.text('Sao chép liên kết'));
      await tester.pumpAndSettle();
      expect(clipboard, _url);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'both property and feed buttons open the same share flow for guests',
    (tester) async {
      await tester.pumpWidget(XLandApp(dependencies: createFakeDependencies()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.share_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(ShareSheet), findsOneWidget);
      expect(find.text('Chia sẻ qua ứng dụng'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      await binding.handlePushRoute('/properties/$_propertyId');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(ShareSheet), findsOneWidget);
      expect(find.text('Sao chép liên kết'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cold HTTPS property link opens exact detail with home underneath',
    (tester) async {
      binding.platformDispatcher.defaultRouteNameTestValue = _url;
      await tester.pumpWidget(XLandApp(dependencies: createFakeDependencies()));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PropertyDetailPage>(find.byType(PropertyDetailPage))
            .propertyId,
        _propertyId,
      );
      expect(
        find.byType(MainNavigationShell, skipOffstage: false),
        findsOneWidget,
      );
      final hiddenVideos = tester.widgetList<VideoPlayerItem>(
        find.byType(VideoPlayerItem, skipOffstage: false),
      );
      expect(hiddenVideos.every((v) => !v.isCurrent), isTrue);
      Navigator.of(tester.element(find.byType(PropertyDetailPage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigationShell), findsOneWidget);
    },
  );

  testWidgets(
    'warm and cold video links fetch exact ID outside feed; deleted video is recoverable',
    (tester) async {
      final feed = _SharedFeed();
      binding.platformDispatcher.defaultRouteNameTestValue =
          'xland://share/videos/$_videoId';
      await tester.pumpWidget(XLandApp(dependencies: _deps(feed)));
      await tester.pumpAndSettle();
      expect(feed.requestedId, _videoId);
      expect(
        tester.widget<VideoPlayerItem>(find.byType(VideoPlayerItem)).video.id,
        _videoId,
      );
      expect(find.byType(SharedVideoPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(SharedVideoPage))).pop();
      await tester.pumpAndSettle();
      feed.missing = true;
      await binding.handlePushRoute(
        'https://${ContentLink.host}/videos/$_videoId',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Video không còn khả dụng hoặc đã được gỡ.'),
        findsOneWidget,
      );
      feed.missing = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<VideoPlayerItem>(find.byType(VideoPlayerItem)).video.id,
        _videoId,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
