import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/widgets/login_prompt_sheet.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_detail_page.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/area_info_tab.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/finance_plan_tab.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/legal_summary_tab.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/property_overview_tab.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';

import 'fakes/fake_xland_dependencies.dart';

Widget _buildDetailHarness({
  required XlandDependencies dependencies,
  String propertyId = 'XL-028',
  VoidCallback? onBookingTap,
}) {
  final authCubit = AuthCubit(dependencies.account);
  return DependenciesScope(
    dependencies: dependencies,
    child: BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp(
        home: PropertyDetailPage(
          propertyId: propertyId,
          onBookingTap: onBookingTap,
        ),
      ),
    ),
  );
}

void main() {
  group('S02, S03, S04, S05 Property Detail Tabs (P2-B2)', () {
    testWidgets(
      'renders S02 Overview tab with media gallery, metrics grid, highlights, and consultant',
      (tester) async {
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(dependencies: dependencies),
        );
        await tester.pumpAndSettle();

        // Check S02 Overview is active tab
        expect(find.byType(PropertyOverviewTab), findsOneWidget);

        // Check 2x3 metrics grid (Diện tích, Mặt tiền, Chiều sâu, Đường vào, Hướng, Loại đất)
        expect(find.text('Diện tích'), findsOneWidget);
        expect(find.text('120 m²'), findsOneWidget);
        expect(find.text('Hướng'), findsOneWidget);
        expect(find.text('Loại đất'), findsOneWidget);

        // Check Highlights section
        expect(find.text('Điểm đáng chú ý'), findsOneWidget);
        expect(find.byType(RichText), findsWidgets);

        // Check Legal progress card
        expect(find.text('Hồ sơ đã đối chiếu 4/6'), findsOneWidget);
        expect(find.text('2 mục cần bổ sung'), findsOneWidget);

        // Check Consultant footer
        expect(find.text('Chuyên viên tư vấn'), findsOneWidget);
        expect(find.text('Minh Anh'), findsOneWidget);
      },
    );

    testWidgets(
      'switches to S03 Legal Checklist tab and verifies checklist items and document grant',
      (tester) async {
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(dependencies: dependencies),
        );
        await tester.pumpAndSettle();

        // Tap on S03 "Pháp lý" tab
        await tester.tap(find.text('Hồ sơ'));
        await tester.pumpAndSettle();

        expect(find.byType(LegalSummaryTab), findsOneWidget);

        // Verify checklist items (verified and pending)
        expect(find.text('Giấy chứng nhận'), findsOneWidget);
        expect(find.text('Người có quyền bán'), findsOneWidget);
        expect(find.text('Thông tin quy hoạch'), findsOneWidget);

        // Check documents section
        expect(find.text('Tài liệu được chia sẻ'), findsOneWidget);
        expect(find.text('Bản chụp giấy tờ'), findsOneWidget);
        expect(find.text('Chờ bổ sung'), findsWidgets);
      },
    );

    testWidgets(
      'switches to S04 Area Info tab and displays POI segments and amenities list',
      (tester) async {
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(dependencies: dependencies),
        );
        await tester.pumpAndSettle();

        // Tap on S04 "Khu vực" tab
        await tester.tap(find.text('Khu vực'));
        await tester.pumpAndSettle();

        expect(find.byType(AreaInfoTab), findsOneWidget);

        // A-19: absent public-area configuration must not present the old
        // property-radius placeholder as a real Google map.
        expect(
          find.textContaining('Bản đồ chưa được cấu hình'),
          findsOneWidget,
        );
        expect(
          find.text('Địa chỉ'),
          findsOneWidget,
        );
        expect(find.text('Bán kính: 1000m'), findsNothing);

        // Check segment buttons: Tất cả, Tiện ích, Giao thông, Đời sống
        expect(find.text('Tất cả'), findsOneWidget);
        expect(find.text('Tiện ích'), findsOneWidget);
        expect(find.text('Giao thông'), findsOneWidget);
        expect(find.text('Đời sống'), findsOneWidget);

        // Check amenities list item
        expect(find.text('Trường học'), findsOneWidget);
        expect(find.text('1 - 3 km'), findsWidgets);
      },
    );

    testWidgets(
      'switches to S05 Finance Plan tab and verifies disclaimer notice',
      (tester) async {
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(dependencies: dependencies),
        );
        await tester.pumpAndSettle();

        // Tap on S05 "Tài chính" tab
        await tester.tap(find.text('Tài chính'));
        await tester.pumpAndSettle();

        expect(find.byType(FinancePlanTab), findsOneWidget);

        // Verify disclaimer notice is displayed without internal codes
        expect(find.text('Kế hoạch tài chính & Vay vốn'), findsOneWidget);
        expect(find.textContaining('Ước tính minh họa'), findsOneWidget);

        // Verify CTA
        expect(find.text('Đăng ký tư vấn gói vay ngân hàng'), findsOneWidget);
      },
    );

    testWidgets(
      'guest tapping bottom CTA opens booking flow without blocking at view time',
      (tester) async {
        bool bookingOpened = false;
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(
            dependencies: dependencies,
            onBookingTap: () => bookingOpened = true,
          ),
        );
        await tester.pumpAndSettle();

        // Tap on "Xem thực địa" bottom CTA
        await tester.tap(find.text('Đặt lịch thực địa'));
        await tester.pumpAndSettle();

        // Verify booking flow is opened directly without login gate intercept
        expect(bookingOpened, isTrue);
        expect(find.byType(LoginPromptSheet), findsNothing);
      },
    );

    testWidgets(
      'guest tapping bookmark triggers LoginPromptSheet for bookmark action',
      (tester) async {
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(dependencies: dependencies),
        );
        await tester.pumpAndSettle();

        // Tap on bookmark icon
        await tester.tap(find.bySemanticsLabel('Lưu'));
        await tester.pumpAndSettle();

        // Verify LoginPromptSheet is displayed
        expect(find.byType(LoginPromptSheet), findsOneWidget);
        expect(find.text('Lưu bất động sản'), findsOneWidget);
        expect(find.text('Đăng nhập ngay'), findsOneWidget);
      },
    );

    testWidgets(
      'S05 Finance Plan calculates both methods accurately (equal installment & declining balance)',
      (tester) async {
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(dependencies: dependencies),
        );
        await tester.pumpAndSettle();

        // Switch to S05 "Tài chính" tab
        await tester.tap(find.text('Tài chính'));
        await tester.pumpAndSettle();

        // Default: equalInstallment (50% = 1.2B loan, 20 yrs = 240 mo, 9% annual rate)
        expect(
          find.text('Khoản trả hàng tháng ước tính; kỳ cuối có điều chỉnh'),
          findsOneWidget,
        );
        expect(find.text('10.796.711 đ'), findsOneWidget);

        // Switch to decliningBalance
        final decliningChip = find.text('Dư nợ giảm dần');
        await tester.ensureVisible(decliningChip);
        await tester.pumpAndSettle();
        await tester.tap(decliningChip);
        await tester.pumpAndSettle();

        expect(find.text('Khoản trả tháng đầu (giảm dần)'), findsOneWidget);
        expect(find.text('14.000.000 đ'), findsOneWidget);
      },
    );

    testWidgets(
      'S05 guest tapping "Lưu kế hoạch tài chính" triggers LoginPromptSheet',
      (tester) async {
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(dependencies: dependencies),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tài chính'));
        await tester.pumpAndSettle();

        final saveButton = find.text('Lưu kế hoạch tài chính');
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(find.byType(LoginPromptSheet), findsOneWidget);
        expect(find.text('Đăng nhập để lưu kế hoạch'), findsOneWidget);
      },
    );

    testWidgets(
      'S05 custom loan term "Khác" shows input and updates calculation',
      (tester) async {
        final dependencies = createFakeDependencies();

        await tester.pumpWidget(
          _buildDetailHarness(dependencies: dependencies),
        );
        await tester.pumpAndSettle();

        // Switch to S05 "Tài chính" tab
        await tester.tap(find.text('Tài chính'));
        await tester.pumpAndSettle();

        // Scroll until "Khác" chip is visible
        final customChip = find.text('Khác');
        await tester.scrollUntilVisible(
          customChip,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(customChip);
        await tester.pumpAndSettle();

        // Custom input field should appear (second TextFormField on page, after disabled price field)
        final customInput = find.byType(TextFormField).last;
        expect(customInput, findsOneWidget);

        // Enter 12 years
        await tester.enterText(customInput, '12');
        await tester.pumpAndSettle();

        expect(find.text('144 tháng'), findsOneWidget);
        expect(find.text('Khác: 12 năm'), findsOneWidget);
      },
    );
  });
}
