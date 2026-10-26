// Regression test suite for Phase 1 responsive layout matrix & label clipping checks.
// Covers 6 combinations: Widths (360, 390, 430) x Text Scale Factors (1.0, 1.3).
//
// Font Origin & Licensing:
// - Roboto Regular & Medium: Apache License 2.0 (Google), loaded dynamically from Flutter SDK engine:
//   engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf
//   engine/src/flutter/txt/third_party/fonts/Roboto-Medium.ttf
// - MaterialIcons: Apache License 2.0 (Google), loaded dynamically from Flutter SDK artifacts:
//   bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf
// Fonts are used strictly for test execution and rasterization; no fonts are bundled into application assets.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/app/xland_app.dart';
import 'package:xland_mobile/presentation/gallery/component_gallery_page.dart';
import 'package:xland_mobile/presentation/shared/widgets/navbar.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'fakes/fake_xland_dependencies.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

  setUpAll(() async {
    const sdk = 'C:/Users/Admin/AppData/Local/XLandTools/flutter';
    final textFonts = FontLoader('Roboto');
    for (final file in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final fontPath = '$sdk/engine/src/flutter/txt/third_party/fonts/$file';
      if (File(fontPath).existsSync()) {
        textFonts.addFont(
          File(fontPath).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
    }
    await textFonts.load();

    final icons = FontLoader('MaterialIcons');
    final iconPath = '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(iconPath).existsSync()) {
      icons.addFont(
        File(iconPath).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await icons.load();
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Responsive Matrix width=$width scale=$scale (P1-008 & P1-009 regression)', (tester) async {
        final failures = <String>[];
        final priorError = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.presentError(details);
          priorError?.call(details);
        };
        addTearDown(() => FlutterError.onError = priorError);

        void checkStage(String stage) {
          final error = tester.takeException();
          if (error != null) {
            failures.add('$stage: $error');
          }
        }

        void checkFullLabels(Iterable<String> labels) {
          for (final label in labels) {
            final matches = find.text(label);
            if (matches.evaluate().isEmpty) continue;
            final paragraph = tester.renderObject<RenderParagraph>(matches.first);
            if (paragraph.didExceedMaxLines) {
              failures.add('Clipped required label: $label');
            }
          }
        }

        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final captureKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: XLandApp(dependencies: createFakeDependencies()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        checkStage('initial shell');

        final navContext = tester.element(find.byType(MainNavigationShell));
        expect(MediaQuery.textScalerOf(navContext).scale(10), closeTo(10 * scale, 0.01));

        Future<void> capture(String name) async {
          if (!((width == 390 && scale == 1.0) || (width == 360 && scale == 1.3))) return;
          await tester.runAsync(() async {
            final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1);
            final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory(Platform.environment['SCREENSHOT_DIR'] ??
                'C:/OwnProject/XLAND-PROJECT/brain/logs/agent-b/evidence/screenshots');
            await directory.create(recursive: true);
            await File('${directory.path}/${width.toInt()}-$scale-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }

        // 1. Check all 4 shell tabs and verify CTA labels
        for (final tab in ['Trang chủ', 'Khám phá', 'Sự kiện', 'Tôi']) {
          if (find.byType(XLandBottomNavBar).evaluate().isEmpty) {
            await tester.tap(find.byTooltip('Mở điều hướng'));
            await tester.pumpAndSettle();
            await tester.tap(find.text(tab));
          } else {
            await tester.tap(find.descendant(of: find.byType(XLandBottomNavBar), matching: find.text(tab)));
          }
          await tester.pumpAndSettle();
          checkStage('tab=$tab width=$width scale=$scale');
          if (tab == 'Trang chủ') {
            checkFullLabels(['Xem chi tiết', 'Xem thực địa']);
            await capture('shell-cta');
          }
          await capture('shell-${['Trang chủ', 'Khám phá', 'Sự kiện', 'Tôi'].indexOf(tab)}');
        }

        // 2. Open Component Gallery from Tab 3 (Tôi)
        await tester.ensureVisible(find.text('Component Gallery (Dev)'));
        await tester.pump();
        await tester.tap(find.text('Component Gallery (Dev)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(ComponentGalleryPage), findsOneWidget);
        checkStage('gallery initial');

        // Verify UnderlineTabBar labels are not clipped (P1-009)
        checkFullLabels(['Tổng quan', 'Hồ sơ', 'Khu vực', 'Tài chính']);
        await capture('gallery-0');

        // 3. Scroll through gallery sections and check for RenderFlex overflow (P1-008)
        final scrollable = find.descendant(of: find.byType(ComponentGalleryPage), matching: find.byType(Scrollable)).first;
        for (var step = 1; step <= 12; step++) {
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          checkStage('gallery scroll=$step');
          if (step == 3) {
            // Step 3 showcases Logo Variants
            await capture('gallery-3-logo');
          }
          if (step == 6) {
            // Step 6 showcases Form & Tabs
            checkFullLabels(['Tổng quan', 'Hồ sơ', 'Khu vực', 'Tài chính']);
            await capture('gallery-6-tabs');
          }
          if ([9, 12].contains(step)) {
            await capture('gallery-$step');
          }
        }

        // 4. Tap Back button and verify navigation pops to Tab 3 (active tab preserved)
        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();
        expect(find.byType(ComponentGalleryPage), findsNothing);
        expect(find.text('Tài khoản của tôi'), findsOneWidget);
        checkStage('back preserves tab');

        expect(
          failures,
          isEmpty,
          reason: 'All layout overflows and clipped required labels must be fixed across 6 combinations.',
        );
      });
    }
  }
}
