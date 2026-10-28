import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/app/xland_app.dart';
import 'package:xland_mobile/presentation/features/feed/widgets/video_player_item.dart';
import 'package:xland_mobile/presentation/shared/widgets/navbar.dart';

import 'fakes/fake_xland_dependencies.dart';

void main() {
  for (final width in [360.0, 430.0]) {
    testWidgets(
      'navbar pushes the feed and its CTAs at width $width, including safe area and large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          XLandApp(
            dependencies: createFakeDependencies(),
          ),
        );
        await tester.pumpAndSettle();
        final feed = find.byType(PageView).first;
        final initialBounds = tester.getRect(feed);
        final originalPlayer = tester.state(find.byType(VideoPlayerItem).first);
        final beforeCta = tester.getRect(find.text('Xem chi tiết'));
        final initialBarriers = find.byType(ModalBarrier).evaluate().length;
        expect(find.byType(XLandBottomNavBar), findsNothing);

        await tester.tap(find.byTooltip('Mở điều hướng'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        final halfwayBounds = tester.getRect(feed);
        expect(halfwayBounds.height, lessThan(initialBounds.height));
        await tester.pumpAndSettle();

        final navbar = find.byType(XLandBottomNavBar);
        final navBounds = tester.getRect(navbar);
        final expandedBounds = tester.getRect(feed);
        expect(
          initialBounds.height - expandedBounds.height,
          closeTo(navBounds.height, 0.1),
        );
        expect(expandedBounds.bottom, closeTo(navBounds.top, 0.1));
        expect(
          tester.getRect(find.text('Xem chi tiết')).bottom,
          lessThan(navBounds.top),
        );
        expect(
          tester.getRect(find.text('Xem thực địa')).bottom,
          lessThan(navBounds.top),
        );
        expect(
          tester.getRect(find.text('Xem chi tiết')).bottom,
          lessThan(beforeCta.bottom),
        );
        expect(
          tester.state(find.byType(VideoPlayerItem).first),
          same(originalPlayer),
        );
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(ModalBarrier), findsNWidgets(initialBarriers));
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Ẩn thanh điều hướng'));
        await tester.pumpAndSettle();
        expect(tester.getRect(feed), initialBounds);
        expect(find.byType(XLandBottomNavBar), findsNothing);
        expect(
          tester.state(find.byType(VideoPlayerItem).first),
          same(originalPlayer),
        );

        await tester.tap(find.byTooltip('Mở điều hướng'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: navbar, matching: find.text('Tôi')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Tài khoản của tôi'), findsOneWidget);
        await tester.tap(
          find.descendant(of: navbar, matching: find.text('Trang chủ')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(XLandBottomNavBar), findsNothing);
        expect(tester.getRect(feed), initialBounds);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
