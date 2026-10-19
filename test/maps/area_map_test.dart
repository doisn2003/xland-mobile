import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:xland_mobile/domain/maps/area_map.dart';
import 'package:xland_mobile/domain/failures/xland_failure.dart';
import 'package:xland_mobile/data/datasources/remote/api_transport.dart';
import 'package:xland_mobile/data/maps/remote_area_map_repository.dart';
import 'package:xland_mobile/data/mappers/domain_mappers.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/presentation/features/area_map/area_map_cubit.dart';
import 'package:xland_mobile/presentation/features/area_map/area_map_panel.dart';
import 'package:xland_mobile/presentation/features/area_map/area_map_scope.dart';

const property = '10000000-0000-4000-8000-000000000001';
const label = 'Phường Long Biên, Hà Nội, Việt Nam';
final origin = Uri.parse('https://api.xland.test/api/v1');
Map<String, Object?> readyWire() => {
  'propertyId': property,
  'availability': 'ready',
  'provider': 'geoapify',
  'poiMode': 'none',
  'notice': 'Khu vực tham khảo.',
  'areaLabel': label,
  'publicArea': {
    'id': 'public-area',
    'label': label,
    'centerLatitude': 21.03,
    'centerLongitude': 105.88,
    'radiusM': 2000,
    'initialZoom': 12,
    'precision': 'administrative_area',
    'checkedAt': '2026-10-19T00:00:00Z',
    'sourceUpdatedAt': null,
  },
  'embedPageUrl': null,
  'tilePathTemplate': '/maps/tiles/{z}/{x}/{y}.png',
  'externalAreaMapUrl': Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': label,
  }).toString(),
  'externalDirectionsUrl': Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': label,
  }).toString(),
  'attribution': [
    {
      'label': '© OpenStreetMap contributors',
      'url': 'https://www.openstreetmap.org/copyright',
    },
    {'label': 'Powered by Geoapify', 'url': 'https://www.geoapify.com/'},
  ],
};

class _Transport implements ApiTransport {
  ApiRequest? sent;
  Object? error;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    sent = request;
    if (error != null) {
      throw error!;
    }
    return ApiResponse(statusCode: 200, body: {'data': readyWire()});
  }
}

class _Repository implements AreaMapRepository {
  _Repository(this.work);
  final Future<AreaMapPresentation> Function() work;
  @override
  Future<AreaMapPresentation> getAreaMap(String id) => work();
}

class _MemoryTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII=',
        ),
      );
}

void main() {
  test(
    'names-only properties do not fabricate a legacy coordinate at zero',
    () {
      final area = mapAreaInfo({
        'propertyId': property,
        'location': null,
        'amenities': <Object?>[],
        'photos': <Object?>[],
        'providerAttribution': 'XLand',
        'externalMapUrl': null,
      });
      expect(area.location, isNull);
    },
  );
  test(
    'AM01 uses gateway; pins tiles to API origin, preserves auth failure',
    () async {
      final transport = _Transport();
      final repo = RemoteAreaMapRepository(
        RemoteGateway(transport),
        apiBaseUrl: origin,
      );
      final map = await repo.getAreaMap(property);
      expect(map.isReady, isTrue);
      expect(
        map.tileUrlTemplate,
        'https://api.xland.test/maps/tiles/{z}/{x}/{y}.png',
      );
      expect(transport.sent!.path, '/properties/$property/area-map');
      expect(transport.sent!.body, isNull);
      expect(map.externalDirectionsUrl!.queryParameters, {
        'api': '1',
        'destination': label,
      });
      transport.error = const XlandFailure.unauthenticated();
      await expectLater(
        repo.getAreaMap(property),
        throwsA(isA<XlandFailure>()),
      );
      await expectLater(
        repo.getAreaMap('../other'),
        throwsA(isA<XlandFailure>()),
      );
    },
  );
  test('reject arbitrary tile hosts, exact precision, malformed/unsafe external links', () {
    final invalid = [
      {...readyWire(), 'propertyId': 'other'},
      {...readyWire()}..remove('areaLabel'),
      {...readyWire(), 'tilePathTemplate': 'https://evil.test/{z}/{x}/{y}'},
      {...readyWire(), 'provider': 'google_embed'},
      {...readyWire(), 'attribution': <Object?>[]},
      {
        ...readyWire(),
        'externalDirectionsUrl':
            'https://www.google.com/maps/dir/?api=1&destination=21,105',
      },
      {...readyWire(), 'externalAreaMapUrl': 'https://evil.test/'},
      {
        ...readyWire(),
        'publicArea': {
          ...(readyWire()['publicArea']! as Map<String, Object?>),
          'precision': 'parcel',
        },
      },
      {
        ...readyWire(),
        'publicArea': {
          ...(readyWire()['publicArea']! as Map<String, Object?>),
          'label': 'other',
        },
      },
    ];
    for (final data in invalid) {
      expect(
        () => mapAreaPresentation(data, property, origin),
        throwsFormatException,
      );
    }
  });
  test('HTTP limited to explicit local development; disabled still has Google name links', () {
    final local = Uri.parse('http://10.0.2.2:3004/api/v1');
    expect(
      () => mapAreaPresentation(readyWire(), property, local),
      throwsFormatException,
    );
    expect(
      mapAreaPresentation(
        readyWire(),
        property,
        local,
        allowLocalHttp: true,
      ).isReady,
      isTrue,
    );
    expect(
      () => mapAreaPresentation(
        readyWire(),
        property,
        Uri.parse('http://evil.test'),
        allowLocalHttp: true,
      ),
      throwsFormatException,
    );
    final disabled = {
      ...readyWire(),
      'availability': 'unavailable',
      'provider': 'none',
      'publicArea': null,
      'tilePathTemplate': null,
      'attribution': <Object?>[],
    };
    final map = mapAreaPresentation(disabled, property, origin);
    expect(map.isReady, isFalse);
    expect(map.externalDirectionsUrl, isNotNull);
    expect(map.area, isNull);
  });
  test(
    'cubit ignores stale/disposed response and refuses wrong property',
    () async {
      final first = Completer<AreaMapPresentation>(),
          second = Completer<AreaMapPresentation>();
      var calls = 0;
      final cubit = AreaMapCubit(
        _Repository(() => ++calls == 1 ? first.future : second.future),
        property,
      );
      final a = cubit.load(), b = cubit.load();
      final map = mapAreaPresentation(readyWire(), property, origin);
      second.complete(map);
      await b;
      first.complete(
        const AreaMapPresentation(
          propertyId: 'wrong',
          availability: AreaMapAvailability.unavailable,
          notice: 'wrong',
        ),
      );
      await a;
      expect(cubit.state.map, same(map));
      await cubit.close();
      final late = Completer<AreaMapPresentation>();
      final closing = AreaMapCubit(_Repository(() => late.future), property);
      final pending = closing.load();
      await closing.close();
      late.complete(map);
      await pending;
      final wrong = AreaMapCubit(
        _Repository(
          () async => const AreaMapPresentation(
            propertyId: 'wrong',
            availability: AreaMapAvailability.unavailable,
            notice: 'wrong',
          ),
        ),
        property,
      );
      await wrong.load();
      expect(wrong.state.error, isNotNull);
      await wrong.close();
    },
  );
  testWidgets('unconfigured and failed API show truthful retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AreaMapPanel(propertyId: property)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa được cấu hình'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: AreaMapScope(
          repository: _Repository(
            () async => throw const XlandFailure(
              code: FailureCode.offline,
              message: 'Không có kết nối',
            ),
          ),
          child: const Scaffold(body: AreaMapPanel(propertyId: property)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không có kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại bản đồ'));
    await tester.pumpAndSettle();
    expect(find.text('Không có kết nối'), findsOneWidget);
  });
  testWidgets(
    'Google buttons launch names, failure visible; tile failure retry; narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final map = mapAreaPresentation(readyWire(), property, origin);
      final opened = <Uri>[];
      ValueChanged<String>? fail;
      var renders = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: AreaMapScope(
              repository: _Repository(() async => map),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AreaMapPanel(
                    propertyId: property,
                    openLink: (uri) async {
                      opened.add(uri);
                      return false;
                    },
                    mapBuilder: (map, loaded, failed) {
                      fail = failed;
                      renders++;
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => loaded(),
                      );
                      return const SizedBox(height: 180);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in ['Mở Google Maps', 'Chỉ đường tới khu vực']) {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }
      expect(opened[0], map.externalAreaMapUrl);
      expect(opened[1], map.externalDirectionsUrl);
      expect(find.textContaining('Chưa mở được liên kết'), findsWidgets);
      fail!('Tạm hết hạn mức');
      await tester.pumpAndSettle();
      expect(find.text('Tạm hết hạn mức'), findsOneWidget);
      final before = renders;
      await tester.ensureVisible(find.text('Tải lại bản đồ'));
      await tester.tap(find.text('Tải lại bản đồ'));
      await tester.pumpAndSettle();
      expect(renders, greaterThan(before));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('real FlutterMap pans and recentres, without property pin', (
    tester,
  ) async {
    final map = mapAreaPresentation(readyWire(), property, origin);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AreaMapCanvas(
            map: map,
            tileProvider: _MemoryTiles(),
            onLoaded: () {},
            onError: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    expect(
      controller.camera.center,
      LatLng(map.area!.latitude, map.area!.longitude),
    );
    controller.move(const LatLng(21.1, 105.9), 13);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Về khu vực'));
    await tester.pumpAndSettle();
    expect(
      controller.camera.center,
      LatLng(map.area!.latitude, map.area!.longitude),
    );
    expect(controller.camera.zoom, 12);
    expect(find.byType(MarkerLayer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
