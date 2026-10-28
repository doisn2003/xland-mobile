import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/mappers/domain_mappers.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/property_card.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_detail_page.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/property_children.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

Map<String, Object?> sample() {
  final data = wireObject(
    jsonDecode(File('test/data/fixtures/c3_samples.json').readAsStringSync()),
  );
  return wireObject(wireObject(data['samples'])['Property']);
}

class SubplotsRepository extends FakePropertyRepository {
  bool fail = false;
  final requests = <String?>[];
  @override
  Future<Page<Property>> getChildren(String propertyId, PageQuery page) async {
    requests.add(page.cursor);
    if (fail) {
      throw const XlandFailure(
        code: FailureCode.internalError,
        message: 'Thử tải lại danh sách',
      );
    }
    final start = page.cursor == null ? 0 : 4;
    return Page(
      items: List.generate(
        start == 0 ? 4 : 1,
        (i) => mapProperty({
          ...sample(),
          'id': 'child-${start + i}',
          'title': 'Lô con ${start + i}',
          'parentPropertyId': propertyId,
          'hasSubplots': i == 0,
          'isCorner': i == 1,
        }),
      ),
      hasMore: start == 0,
      nextCursor: start == 0 ? 'next' : null,
      total: 5,
    );
  }
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
    final icons=FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [360.0, 390.0, 430.0, 768.0, 1440.0]) {
    testWidgets('child grid has no overflow at $width and enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: createFakeDependencies(
            propertyRepo: SubplotsRepository(),
          ),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PropertyChildren(propertyId: 'parent'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (Platform.environment['CAPTURE_SUBPLOTS'] == 'true') {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('.local/subplots');
          await directory.create(recursive: true);
          await File('${directory.path}/mobile-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'legacy payload and new hierarchy decode without losing money precision',
    () {
      expect(mapProperty(sample()).hasSubplots, false);
      final p = mapProperty({
        ...sample(),
        'parentPropertyId': 'parent',
        'hasSubplots': true,
        'isCorner': true,
        'priceTotal': '9007199254740993',
      });
      expect(p.parentPropertyId, 'parent');
      expect(p.hasSubplots, true);
      expect(p.isCorner, true);
      expect(p.priceTotal.wireValue, '9007199254740993');
      expect(
        () => mapProperty({...sample(), 'hasSubplots': 'true'}),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'two-column pagination, retry and full child detail navigation at 360px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = SubplotsRepository();
      final deps = createFakeDependencies(propertyRepo: repo);
      final auth = AuthCubit(deps.account);
      addTearDown(auth.close);
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: BlocProvider.value(
            value: auth,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PropertyChildren(propertyId: 'parent'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PropertyCard), findsNWidgets(4));
      final a = tester.getRect(find.byType(PropertyCard).at(0)),
          b = tester.getRect(find.byType(PropertyCard).at(1));
      expect(a.top, b.top);
      expect(b.left, greaterThan(a.right));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Trang sau'));
      await tester.tap(find.text('Trang sau'));
      await tester.pumpAndSettle();
      expect(find.byType(PropertyCard), findsOneWidget);
      expect(repo.requests.last, 'next');
      expect(find.text('Trang 2'), findsOneWidget);
      repo.fail = true;
      await tester.tap(find.text('Trang trước'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(PropertyCard).first);
      await tester.tap(find.byType(PropertyCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(PropertyDetailPage), findsOneWidget);
      expect(
        tester
            .widget<PropertyDetailPage>(find.byType(PropertyDetailPage))
            .propertyId,
        'child-4',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
