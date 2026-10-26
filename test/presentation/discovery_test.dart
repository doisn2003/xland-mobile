import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/widgets/login_prompt_sheet.dart';
import 'package:xland_mobile/presentation/features/discovery/pages/discovery_page.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/property_card.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/property_filter_sheet.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_detail_page.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'fakes/fake_xland_dependencies.dart';

Widget _buildTestHarness({
  required XlandDependencies dependencies,
  AuthCubit? authCubit,
}) {
  final cubit = authCubit ?? AuthCubit(dependencies.account);
  return DependenciesScope(
    dependencies: dependencies,
    child: BlocProvider<AuthCubit>.value(
      value: cubit,
      child: const MaterialApp(
        home: DiscoveryPage(),
      ),
    ),
  );
}

void main() {
  group('S01 Discovery & S09 Filter Sheet (P2-B1)', () {
    testWidgets('renders search bar, hero carousel, and initial properties', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(_buildTestHarness(dependencies: dependencies));
      await tester.pumpAndSettle();

      // Check search field
      expect(find.byType(TextField), findsOneWidget);

      // Verify category chips are removed
      expect(find.text('Đất nền'), findsNothing);
      expect(find.text('Công nghiệp'), findsNothing);

      // Check properties loaded from fake (XL-028, XL-029, XL-030, XL-031)
      expect(find.byType(PropertyCard), findsWidgets);
      expect(find.text('Đất nền Hòa Lạc'), findsOneWidget);
      // Community content follows the property catalog, per BUSINESS.
      await tester.scrollUntilVisible(find.text('Sự kiện XLand'),300,
        scrollable:find.descendant(of:find.byType(CustomScrollView),matching:find.byType(Scrollable)).first,maxScrolls:40);
      await tester.pumpAndSettle();
      final featured=(await dependencies.events.getEvents(const PageQuery(limit:1),status:EventStatus.open)).items.first;
      expect(find.text(featured.title), findsOneWidget);
    });

    testWidgets('searching by keyword filters property list', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(_buildTestHarness(dependencies: dependencies));
      await tester.pumpAndSettle();

      // Enter search term
      await tester.enterText(find.byType(TextField), 'Bắc Ninh');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Should find XL-030 and not find XL-028
      expect(find.text('Đất nền Bắc Ninh'), findsOneWidget);
      expect(find.text('Đất nền Hòa Lạc'), findsNothing);
    });

    testWidgets('switching subtabs filters appropriately', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(_buildTestHarness(dependencies: dependencies));
      await tester.pumpAndSettle();

      // Tap "Đã lưu" tab
      await tester.tap(find.text('Đã lưu'));
      await tester.pumpAndSettle();

      // Initially no saved properties in guest mode
      expect(find.text('Không tìm thấy lô đất phù hợp'), findsOneWidget);

      // Tap "Phù hợp" tab to return
      await tester.tap(find.text('Phù hợp'));
      await tester.pumpAndSettle();
      expect(find.byType(PropertyCard), findsWidgets);
    });

    testWidgets('tapping filter button opens S09 Filter Sheet with live criteria counter', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(_buildTestHarness(dependencies: dependencies));
      await tester.pumpAndSettle();

      // Tap filter icon
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Verify S09 Filter Sheet opens
      expect(find.byType(PropertyFilterSheet), findsOneWidget);
      expect(find.text('Tìm đất theo nhu cầu'), findsOneWidget);

      // Select a region chip
      await tester.tap(find.text('Miền Bắc').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify active criteria notice shows 1 criteria group
      expect(find.textContaining('Đã chọn 1 tiêu chí'), findsOneWidget);

      // Reset filters
      await tester.tap(find.text('Đặt lại'));
      await tester.pumpAndSettle();

      // Apply button should close sheet
      await tester.tap(find.textContaining('Xem'));
      await tester.pumpAndSettle();

      expect(find.byType(PropertyFilterSheet), findsNothing);
    });

    testWidgets('guest tapping bookmark triggers LoginPromptSheet intercept', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(_buildTestHarness(dependencies: dependencies));
      await tester.pumpAndSettle();

      // Tap first bookmark icon button
      final bookmarkIconFinder = find.byIcon(Icons.bookmark_border_rounded).first;
      await tester.tap(bookmarkIconFinder);
      await tester.pumpAndSettle();

      // Should open LoginPromptSheet
      expect(find.byType(LoginPromptSheet), findsOneWidget);
      expect(find.text('Lưu bất động sản'), findsOneWidget);
      expect(find.text('Đăng nhập ngay'), findsOneWidget);
      expect(find.textContaining('Để sau'), findsOneWidget);

      // Dismiss sheet
      await tester.tap(find.textContaining('Để sau'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPromptSheet), findsNothing);
    });

    testWidgets('tapping a property card opens PropertyDetailPage', (tester) async {
      final dependencies = createFakeDependencies();

      await tester.pumpWidget(_buildTestHarness(dependencies: dependencies));
      await tester.pumpAndSettle();

      // Scroll down so property card is fully visible
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap on property card
      final propertyCard = find.text('Đất nền Hòa Lạc');
      await tester.tap(propertyCard);
      await tester.pumpAndSettle();

      // Should navigate to PropertyDetailPage
      expect(find.byType(PropertyDetailPage), findsOneWidget);
      expect(find.text('Tổng quan'), findsOneWidget);
      expect(find.text('Hồ sơ'), findsOneWidget);
      expect(find.text('Khu vực'), findsOneWidget);
      expect(find.text('Tài chính'), findsOneWidget);
    });
  });
}
