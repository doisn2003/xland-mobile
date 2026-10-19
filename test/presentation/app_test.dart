import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/app/xland_app.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/gallery/component_gallery_page.dart';
import 'fakes/fake_xland_dependencies.dart';

void main() {
  group('XLandApp Boot & Constructor DI', () {
    testWidgets('XLandApp instantiates with pure Dart dependencies and renders MainNavigationShell', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(
        XLandApp(
          dependencies: dependencies,
          showGallery: false,
        ),
      );

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.text('Khám phá'), findsNothing);
    });

    testWidgets('XLandApp renders ComponentGalleryPage when showGallery is true and back button returns to Shell', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(
        XLandApp(
          dependencies: dependencies,
          showGallery: true,
        ),
      );

      expect(find.byType(ComponentGalleryPage), findsOneWidget);
      expect(find.text('Component Gallery'), findsOneWidget);
      expect(find.text('1. Color Tokens (MP & QƯ)'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      // Should return to MainNavigationShell
      expect(find.byType(ComponentGalleryPage), findsNothing);
      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('XLandApp opens gallery from Shell and back button pops gallery preserving active tab', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(
        XLandApp(
          dependencies: dependencies,
          showGallery: false,
        ),
      );

      expect(find.byType(MainNavigationShell), findsOneWidget);

      // Switch to Tab 3: "Tôi"
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mở điều hướng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tôi'));
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản của tôi'), findsOneWidget);
      expect(find.text('Component Gallery (Dev)'), findsOneWidget);

      // Open gallery from dev entry in Tab 3
      await tester.ensureVisible(find.text('Component Gallery (Dev)'));
      await tester.tap(find.text('Component Gallery (Dev)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ComponentGalleryPage), findsOneWidget);
      expect(find.text('Component Gallery'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      // Gallery is popped, and user is back on Tab 3 with active tab preserved
      expect(find.byType(ComponentGalleryPage), findsNothing);
      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.text('Tài khoản của tôi'), findsOneWidget);
      expect(find.text('Xem thực địa'), findsNothing);
    });

    testWidgets('XLandApp opens gallery from Tab 0 top action and back button returns to Tab 0', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(
        XLandApp(
          dependencies: dependencies,
          showGallery: false,
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mở điều hướng'));
      await tester.pumpAndSettle();
      expect(find.text('Gallery'), findsOneWidget);
      await tester.tap(find.text('Gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ComponentGalleryPage), findsOneWidget);

      // Tap back button
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      // Returns to Tab 0
      expect(find.byType(ComponentGalleryPage), findsNothing);
      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.text('Xem thực địa'), findsOneWidget);
    });
  });
}
