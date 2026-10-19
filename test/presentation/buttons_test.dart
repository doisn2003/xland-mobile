import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

void main() {
  group('Buttons & Action Interactions', () {
    testWidgets('PrimaryButton renders label and fires callback on tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrimaryButton(
              label: 'Đặt lịch thực địa',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Đặt lịch thực địa'), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('PrimaryButton displays spinner and ignores taps when isSubmitting is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrimaryButton(
              label: 'Đặt lịch thực địa',
              isSubmitting: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Đang xử lý...'), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('PrimaryButton ignores taps when onPressed is null (disabled)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: PrimaryButton(
              label: 'Tiếp tục',
              onPressed: null,
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('OutlineButton renders with brand styling and fires callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OutlineButton(
              label: 'Xem chi tiết',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Xem chi tiết'), findsOneWidget);
      await tester.tap(find.byType(OutlineButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('IconActionButton satisfies minimum 48x48 hit target and shows badge', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: IconActionButton(
                icon: Icons.notifications_none_rounded,
                semanticLabel: 'Thông báo',
                badgeCount: 5,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(IconActionButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.byType(IconActionButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
