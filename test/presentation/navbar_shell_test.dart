import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

void main() {
  // Keep infinite decorative animation static in non-animation regression tests.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  group('Navbar & Main Navigation Shell', () {
    testWidgets('XLandBottomNavBar renders all 4 required tabs in order', (tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            bottomNavigationBar: XLandBottomNavBar(
              currentIndex: selected,
              onTap: (index) => selected = index,
            ),
          ),
        ),
      );

      expect(find.text('Trang chủ'), findsOneWidget);
      expect(find.text('Khám phá'), findsOneWidget);
      expect(find.text('Giao dịch'), findsOneWidget);
      expect(find.text('Tôi'), findsOneWidget);

      await tester.tap(find.text('Khám phá'));
      await tester.pump();
      expect(selected, 1);

      await tester.tap(find.text('Giao dịch'));
      await tester.pump();
      expect(selected, 2);

      await tester.tap(find.text('Tôi'));
      await tester.pump();
      expect(selected, 3);
    });

    testWidgets('MainNavigationShell displays tab placeholders and switches content correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationShell(),
        ),
      );

      // Initially on Tab 0: Trang chủ
      expect(find.text('Tab Trang chủ (S00) — Đang ở bước UI Foundation Phase 1. Chưa kết nối video feed thật.'), findsOneWidget);
      expect(find.text('Đất nền KCN Hòa Lạc — Vị trí kim cương'), findsOneWidget);

      // Switch to Tab 1: Khám phá
      await tester.tap(find.bySemanticsLabel('Mở điều hướng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khám phá'));
      await tester.pumpAndSettle();
      expect(find.text('Tab Khám phá (S01/S09) — UI Foundation Phase 1. Các lô đất hiển thị dạng placeholder chuẩn.'), findsOneWidget);

      // Switch to Tab 2: Giao dịch
      await tester.tap(find.text('Giao dịch'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử đặt lịch thực địa'), findsOneWidget);
      expect(find.text('Tính năng sắp ra mắt'), findsOneWidget);

      // Switch to Tab 3: Tôi
      await tester.tap(find.text('Tôi'));
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản của tôi'), findsOneWidget);
      expect(find.text('Khách hàng XLand'), findsOneWidget);
    });
  });
}
