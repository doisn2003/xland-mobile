import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:xland_mobile/data/maps/remote_area_map_repository.dart';
import 'package:xland_mobile/domain/maps/area_map.dart';
import 'package:xland_mobile/presentation/features/area_map/area_map_panel.dart';
import 'package:xland_mobile/presentation/features/area_map/area_map_scope.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'area_map_test.dart' show readyWire, property, origin;

Map<String, Object?> planningWire({String region = 'ha-noi'}) => {
  ...readyWire(),
  'planning': {
    'availability': 'ready',
    'region': region,
    'notice':
        'Quy hoạch khu vực tham khảo; chưa xác định vị trí và ranh lô đất.',
    'source': {
      'label': 'BDS68',
      'sourceUrl': 'https://bds68.com.vn/quy-hoach/$region',
      'legendUrl': 'https://bds68.com.vn/quy-hoach/$region',
      'revision': 'test-v1',
      'tilePathTemplate': '/maps/planning/$region/test-v1/{z}/{x}/{y}.png',
      'minZoom': region == 'ha-noi' ? 10 : 12,
      'maxNativeZoom': 18,
      'publishedAt': null,
      'coverageBounds': null,
    },
  },
};

class _Repository implements AreaMapRepository {
  _Repository(this.map);
  final AreaMapPresentation map;
  @override
  Future<AreaMapPresentation> getAreaMap(String id) async => map;
}

class _RecordingTiles extends TileProvider {
  _RecordingTiles(this.requests);
  final List<String> requests;
  static final _base = File('test/maps/fixtures/base-tile.png')
      .readAsBytesSync();
  static final _planning = File('test/maps/fixtures/planning-tile.png')
      .readAsBytesSync();
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requests.add(
      '${options.urlTemplate}/${coordinates.z}/${coordinates.x}/${coordinates.y}',
    );
    return MemoryImage(
      options.urlTemplate!.contains('/maps/planning/') ? _planning : _base,
    );
  }
}

Future<void> showMap(
  WidgetTester tester,
  AreaMapPresentation map,
  List<String> requests, {
  List<Uri>? opened,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: AreaMapScope(
          repository: _Repository(map),
          createTileProvider: () => _RecordingTiles(requests),
          child: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: const ValueKey('planning-capture'),
                child: Material(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AreaMapCanvas(
                      key: ValueKey(map),
                      map: map,
                      onLoaded: () {},
                      onError: (_) {},
                      openLink: (url) async {
                        opened?.add(url);
                        return false;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final context = tester.element(find.byType(AreaMapCanvas));
    await precacheImage(MemoryImage(_RecordingTiles._base), context);
    if (context.mounted) {
      await precacheImage(MemoryImage(_RecordingTiles._planning), context);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  if (const bool.fromEnvironment('PLANNING_CAPTURE')) {
    setUpAll(() async {
      final fonts = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      await fonts.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
  }
  test('accepts exactly two planning regions and pins image URLs to the API origin', () {
    for (final region in ['ha-noi', 'hai-phong']) {
      final map = mapAreaPresentation(
        planningWire(region: region),
        property,
        origin,
      );
      expect(map.planning!.isReady, isTrue);
      expect(
        map.planning!.source!.tileUrlTemplate,
        'https://api.xland.test/maps/planning/$region/test-v1/{z}/{x}/{y}.png',
      );
      expect(map.planning!.source!.publishedAt, isNull);
    }
    expect(
      mapAreaPresentation(
        planningWire(region: 'da-nang'),
        property,
        origin,
      ).planning,
      isNull,
    );
    expect(mapAreaPresentation(readyWire(), property, origin).planning, isNull);
  });

  test('bad overlay metadata disables only planning and preserves a ready base map', () {
    for (final changes in [
      {'tilePathTemplate': 'https://evil.test/{z}/{x}/{y}.png'},
      {'revision': '../evil'},
      {'minZoom': 19, 'maxNativeZoom': 18},
      {
        'coverageBounds': [21, 105, 20, 106],
      },
      {'publishedAt': 'yesterday'},
      {'sourceUrl': 'javascript:alert(1)'},
    ]) {
      final raw = planningWire();
      final planning = raw['planning']! as Map<String, Object?>;
      planning['source'] = {
        ...planning['source']! as Map<String, Object?>,
        ...changes,
      };
      final map = mapAreaPresentation(raw, property, origin);
      expect(map.isReady, isTrue);
      expect(map.planning!.availability, PlanningAvailability.unavailable);
      expect(map.planning!.source, isNull);
    }
  });

  testWidgets(
    'toggle and loading controls preserve the live map and its camera',
    (tester) async {
      final requests = <String>[];
      final map = mapAreaPresentation(planningWire(), property, origin);
      await showMap(tester, map, requests);
      final originalMapState = tester.state(find.byType(FlutterMap));
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(21.03, 105.85), 14);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(FlutterMap)), same(originalMapState));
      expect(controller.camera.zoom, 14);
      expect(controller.camera.center.latitude, closeTo(21.03, 0.00001));
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(FlutterMap)), same(originalMapState));
      expect(controller.camera.zoom, 14);
    },
  );

  testWidgets(
    'unsupported/unconfigured properties never request overlay tiles or offer a slider',
    (tester) async {
      final requests = <String>[];
      for (final raw in [
        readyWire(),
        {
          ...readyWire(),
          'planning': {
            'availability': 'not_supported',
            'region': null,
            'notice': '',
            'source': null,
          },
        },
        {
          ...readyWire(),
          'planning': {
            'availability': 'unconfigured',
            'region': 'hai-phong',
            'notice': 'Chưa cấu hình nguồn quy hoạch cho khu vực này.',
            'source': null,
          },
        },
      ]) {
        await showMap(
          tester,
          mapAreaPresentation(raw, property, origin),
          requests,
        );
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.byType(Slider), findsNothing);
        expect(find.byType(TileLayer), findsOneWidget);
        expect(requests.any((url) => url.contains('/maps/planning/')), isFalse);
        expect(tester.takeException(), isNull);
      }
      expect(
        find.textContaining('Chưa cấu hình nguồn quy hoạch'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'opacity changes preserve camera and layer transport, disabled planning stops requests',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      await showMap(
        tester,
        mapAreaPresentation(planningWire(), property, origin),
        requests,
      );
      expect(requests.any((url) => url.contains('/maps/planning/')), isFalse);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.byType(TileLayer), findsNWidgets(2));
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final controller = map.mapController!;
      controller.move(const LatLng(21.1, 105.9), 18);
      await tester.pumpAndSettle();
      final overlay = tester.widgetList<TileLayer>(find.byType(TileLayer)).last;
      final before = requests.length;
      for (final opacity in [0.0, 0.5, 1.0]) {
        tester.widget<Slider>(find.byType(Slider)).onChanged!(opacity);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Opacity>(
                find.byKey(const ValueKey('planning-layer-opacity')),
              )
              .opacity,
          opacity,
        );
        expect(
          tester
              .widgetList<TileLayer>(find.byType(TileLayer))
              .last
              .tileProvider,
          same(overlay.tileProvider),
        );
        expect(controller.camera.center, const LatLng(21.1, 105.9));
        expect(controller.camera.zoom, 18);
        expect(requests.length, before);
      }
      expect(
        requests
            .where((url) => !url.contains('/maps/planning/'))
            .every((url) => !url.contains('.png/18/')),
        isTrue,
      );
      expect(find.byType(MarkerLayer), findsNothing);
      if (const bool.fromEnvironment('PLANNING_CAPTURE')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('planning-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final file = File('.local/planning-map-preview.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.byType(TileLayer), findsOneWidget);
      final planningRequests = requests
          .where((url) => url.contains('/maps/planning/'))
          .length;
      controller.move(const LatLng(21.2, 105.8), 13);
      await tester.pumpAndSettle();
      expect(
        requests.where((url) => url.contains('/maps/planning/')).length,
        planningRequests,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'planning failure is separate from base and retry recreates only the overlay',
    (tester) async {
      final requests = <String>[];
      await showMap(
        tester,
        mapAreaPresentation(planningWire(), property, origin),
        requests,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final layers = tester
          .widgetList<TileLayer>(find.byType(TileLayer))
          .toList();
      expect(layers.last.urlTemplate, contains('/maps/planning/'));
      final failedTile = TileImage(
        vsync: const TestVSync(),
        coordinates: const TileCoordinates(3249, 1803, 12),
        imageProvider: const AssetImage('unused'),
        onLoadComplete: (_) {},
        onLoadError: (_, _, _) {},
        tileDisplay: const TileDisplay.instantaneous(),
        errorImage: null,
        cancelLoading: Completer<void>(),
      );
      layers.last.errorTileCallback!(
        failedTile,
        const HttpException('Missing planning tile'),
        null,
      );
      failedTile.dispose();
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Một phần lớp quy hoạch'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      await tester.ensureVisible(find.text('Thử lại lớp quy hoạch'));
      await tester.tap(find.text('Thử lại lớp quy hoạch'));
      await tester.pumpAndSettle();
      final after = tester
          .widgetList<TileLayer>(find.byType(TileLayer))
          .toList();
      expect(after.first.tileProvider, same(layers.first.tileProvider));
      expect(after.last.tileProvider, isNot(same(layers.last.tileProvider)));
      expect(find.textContaining('Một phần lớp quy hoạch'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coverage and zoom gaps keep base visible and explain why the overlay is absent',
    (tester) async {
      final raw = planningWire();
      ((raw['planning']! as Map<String, Object?>)['source']!
          as Map<String, Object?>)['coverageBounds'] = [
        20.9,
        105.7,
        21.2,
        106.0,
      ];
      final requests = <String>[];
      await showMap(
        tester,
        mapAreaPresentation(raw, property, origin),
        requests,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(16, 108), 13);
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa có dữ liệu quy hoạch trong vùng đang xem.'),
        findsOneWidget,
      );
      expect(find.byType(TileLayer), findsOneWidget);
      controller.move(const LatLng(21.03, 105.88), 9);
      await tester.pumpAndSettle();
      expect(find.text('Phóng to từ mức 10 để xem quy hoạch.'), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);
      controller.move(const LatLng(21.03, 105.88), 13);
      await tester.pumpAndSettle();
      expect(find.byType(TileLayer), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fullscreen shares camera/opacity; legend keeps the date without source branding or external links',
    (tester) async {
      final requests = <String>[];
      final opened = <Uri>[];
      await showMap(
        tester,
        mapAreaPresentation(planningWire(), property, origin),
        requests,
        opened: opened,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xem toàn màn hình'));
      expect(find.textContaining('BDS68'), findsNothing);
      await tester.tap(find.text('Xem toàn màn hình'));
      await tester.pumpAndSettle();
      expect(find.textContaining('BDS68'), findsNothing);
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(21.1, 105.9), 17);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(0.4);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      final returned = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(returned.camera.center, const LatLng(21.1, 105.9));
      expect(returned.camera.zoom, 17);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0.4);
      await tester.ensureVisible(find.text('Chú giải'));
      await tester.tap(find.text('Chú giải'));
      await tester.pumpAndSettle();
      expect(find.text('Chú giải quy hoạch'), findsOneWidget);
      expect(
        find.text('Nguồn chưa cung cấp ngày công bố dữ liệu.'),
        findsWidgets,
      );
      expect(find.textContaining('BDS68'), findsNothing);
      expect(find.text('Xem chú giải tại nguồn'), findsNothing);
      expect(opened, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
