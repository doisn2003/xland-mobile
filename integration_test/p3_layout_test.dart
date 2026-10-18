// Guest layout matrix only. Does not substitute owner/forms/keyboard scenarios.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';
import 'package:xland_mobile/bootstrap/dev_main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const capture = bool.fromEnvironment('XLAND_P3_CAPTURE');
  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('E10/guest ${width.toInt()} scale$scale actual feed', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 860);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(const DevComposition());
        var initialized = false;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(seconds: 1));
          final players = tester.widgetList<VideoPlayer>(
            find.byType(VideoPlayer),
          );
          if (players.any((p) => p.controller.value.hasError)) {
            fail(
              'Actual source error: record as error capture; never label success',
            );
          }
          initialized = players.any((p) => p.controller.value.isInitialized);
          if (initialized) break;
        }
        expect(
          initialized,
          isTrue,
          reason: 'Success capture requires actual initialized feed video',
        );
        expect(tester.takeException(), isNull);
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await binding.takeScreenshot('E10_guest_${width.toInt()}_$scale');
        await tester.pumpWidget(const SizedBox.shrink());
      }, skip: !capture);
    }
  }
}
