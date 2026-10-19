import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_state.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_sheet.dart';
import 'package:xland_mobile/presentation/features/consultant/pages/consultant_profile_page.dart';
import 'package:xland_mobile/presentation/features/events/pages/event_detail_page.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/finance_plan_tab.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/theme/app_theme.dart';

import 'fakes/fake_xland_dependencies.dart';

Widget _buildTestApp({
  required Widget child,
  required XlandDependencies deps,
  AuthState? initialAuth,
}) {
  return DependenciesScope(
    dependencies: deps,
    child: BlocProvider<AuthCubit>(
      create: (_) {
        final cubit = AuthCubit(deps.account);
        if (initialAuth != null) {
          cubit.emit(initialAuth);
        } else {
          cubit.checkSession();
        }
        return cubit;
      },
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('W2 S05: Finance Plan Loan Advice with Consent', () {
    testWidgets('Loan advice sheet requires consent and submits support ticket', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deps = createFakeDependencies();
      await tester.pumpWidget(
        _buildTestApp(
          child: FinancePlanTab(property: FakePropertyRepository.sampleProperty),
          deps: deps,
        ),
      );
      await tester.pumpAndSettle();

      // Find "Đăng ký tư vấn gói vay ngân hàng" button
      final adviceBtn = find.text('Đăng ký tư vấn gói vay ngân hàng');
      expect(adviceBtn, findsOneWidget);
      await tester.ensureVisible(adviceBtn);
      await tester.tap(adviceBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet appears
      expect(find.text('Đăng ký tư vấn gói vay ngân hàng'), findsWidgets);
      expect(find.text('Gửi yêu cầu tư vấn'), findsOneWidget);

      // Submit is disabled without consent
      final submitBtn = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('Gửi yêu cầu tư vấn'), matching: find.byType(ElevatedButton)),
      );
      expect(submitBtn.onPressed, isNull);

      // Enter name and phone
      final sheetFields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(sheetFields.at(0), 'Trần Minh');
      await tester.enterText(sheetFields.at(1), '0912345678');

      // Check consent
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Now submit button is enabled
      final submitBtnActive = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('Gửi yêu cầu tư vấn'), matching: find.byType(ElevatedButton)),
      );
      expect(submitBtnActive.onPressed, isNotNull);

      // Tap submit
      await tester.tap(find.text('Gửi yêu cầu tư vấn'));
      await tester.pumpAndSettle();

      // Verify ticket was submitted to fake support repository
      final requests = await deps.support.getRequests(const PageQuery());
      expect(requests.items.length, equals(1));
      expect(requests.items.first.kind, equals(SupportKind.loanAdvice));

      // SnackBar notice is displayed
      expect(find.text('Yêu cầu tư vấn đã được tiếp nhận. Chuyên viên sẽ liên hệ trong giờ làm việc.'), findsOneWidget);
    });
  });

  group('W2 B3: S06 Consultant Profile Page', () {
    testWidgets('ConsultantProfilePage renders header, switches 3 tabs, and handles follow/ticket', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deps = createFakeDependencies();
      final session = Session(
        profile: UserProfile(
          id: 'user-01',
          displayName: 'Lê Hoàng',
          contactPhone: '0988776655',
          contactVerified: true,
          updatedAt: DateTime.utc(2026, 10, 16),
        ),
        expiresAt: DateTime.utc(2026, 12, 31),
      );
      await tester.pumpWidget(
        _buildTestApp(
          child: const ConsultantProfilePage(consultantId: '00000000-0000-4000-8000-000000000030'),
          deps: deps,
          initialAuth: AuthAuthenticated(session),
        ),
      );
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('Minh Anh'), findsWidgets);
      expect(find.text('4,9/5'), findsOneWidget);
      expect(find.text('1250'), findsOneWidget);

      // Follow toggle
      expect(find.text('Theo dõi'), findsWidgets);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Theo dõi'));
      await tester.pumpAndSettle();
      expect(find.text('Đang theo dõi'), findsOneWidget);
      expect(find.text('1251'), findsOneWidget);

      // Tab 0: Giới thiệu is default
      expect(find.widgetWithText(Tab, 'Video'), findsOneWidget);

      // Tab 1: Video thực địa
      await tester.tap(find.widgetWithText(Tab, 'Video'));
      await tester.pumpAndSettle();
      expect(find.text('Khảo sát thực địa đất nền phân lô Hòa Lạc, pháp lý minh bạch 100%'), findsOneWidget);

      // Tab 2: BĐS phụ trách
      await tester.tap(find.widgetWithText(Tab, 'Lô đang bán'));
      await tester.pumpAndSettle();
      expect(find.text('Đất nền Hòa Lạc'), findsOneWidget);

      // Open Support Ticket Sheet
      await tester.tap(find.text('Hẹn tư vấn với Minh Anh'));
      await tester.pumpAndSettle();

      expect(find.text('Đặt lịch & Yêu cầu hỗ trợ'), findsOneWidget);
      expect(find.text('Phiếu hỗ trợ chuyên viên'), findsOneWidget);

      // Fill and submit ticket
      final sheetFields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(sheetFields.at(0), 'Lê Hoàng');
      await tester.enterText(sheetFields.at(1), '0988776655');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi phiếu yêu cầu'));
      await tester.pumpAndSettle();

      final requests = await deps.support.getRequests(const PageQuery());
      expect(requests.items.any((r) => r.kind == SupportKind.consultantAppointment), isTrue);
    });
  });

  group('W2 B3: S07 Event Detail Page', () {
    testWidgets('EventDetailPage renders details, capacity, and handles registration with payment notice', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deps = createFakeDependencies();
      final session = Session(
        profile: UserProfile(
          id: 'user-01',
          displayName: 'Ngô Bá',
          contactPhone: '0933221100',
          contactVerified: true,
          updatedAt: DateTime.utc(2026, 10, 16),
        ),
        expiresAt: DateTime.utc(2026, 12, 31),
      );
      await tester.pumpWidget(
        _buildTestApp(
          child: const EventDetailPage(eventId: 'ev-001'),
          deps: deps,
          initialAuth: AuthAuthenticated(session),
        ),
      );
      await tester.pumpAndSettle();

      // Event details
      expect(find.text('Tọa đàm đầu tư đất nền vùng ven & KCN công nghệ cao Hòa Lạc 2026'), findsOneWidget);
      expect(find.text('Trung tâm Đổi mới Sáng tạo Quốc gia NIC Hòa Lạc'), findsOneWidget);
      expect(find.text('Khu CNC Hòa Lạc, Thạch Thất, Hà Nội'), findsOneWidget);
      expect(find.text('15/50 chỗ'), findsOneWidget);
      expect(find.text('15:30 — Ngày 25/10/2026'), findsOneWidget);
      expect(find.text('15:30'), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget);
      expect(find.text('17:30'), findsOneWidget);

      // Speakers & Agenda
      expect(find.text('TS. Nguyễn Hữu Dũng'), findsOneWidget);
      expect(find.text('Xu hướng quy hoạch & Pháp lý đất nền ven đô'), findsOneWidget);

      // Open Registration
      await tester.tap(find.text('Đăng ký tham dự'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký tham gia sự kiện'), findsOneWidget);
      final regFields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(regFields.at(0), 'Ngô Bá');
      await tester.enterText(regFields.at(1), '0933221100');

      await tester.tap(find.text('Xác nhận đăng ký'));
      await tester.pumpAndSettle();

      // Dialog confirmation with paymentMode disabled notice
      expect(find.text('Đăng ký thành công'), findsOneWidget);
      expect(find.text('Chính sách thanh toán'), findsOneWidget);
      expect(find.textContaining('Cổng thanh toán vé sự kiện hiện chưa kích hoạt'), findsOneWidget);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      // Slots updated to 14
      expect(find.text('14/50 chỗ'), findsOneWidget);
    });

    testWidgets('EventDetailPage disables register button when sold out', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deps = createFakeDependencies();
      await tester.pumpWidget(
        _buildTestApp(
          child: const EventDetailPage(eventId: 'ev-sold-out'),
          deps: deps,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã hết chỗ'), findsWidgets);
      final btn = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('Đã hết chỗ'), matching: find.byType(ElevatedButton)),
      );
      expect(btn.onPressed, isNull);
    });
  });

  group('W2 B4: S08 Booking Flow Sheet', () {
    testWidgets('Guest can fill form, view review step with 350k deposit notice, and gates at submit time', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deps = createFakeDependencies();
      await tester.pumpWidget(
        _buildTestApp(
          child: const BookingSheet(propertyId: '00000000-0000-4000-8000-000000000005'),
          deps: deps,
        ),
      );
      await tester.pumpAndSettle();

      // Form Step
      expect(find.text('Đặt lịch xem thực địa'), findsOneWidget);
      expect(find.text('Khung giờ khảo sát'), findsOneWidget);

      // Enter contact details
      final formFields = find.descendant(of: find.byType(BookingSheet), matching: find.byType(TextField));
      await tester.enterText(formFields.at(0), 'Vũ Tuấn');
      await tester.enterText(formFields.at(1), '0977112233');

      // Select transport mode "Cần xe đưa đón"
      await tester.tap(find.text('Cần xe đưa đón'));
      await tester.pumpAndSettle();

      // Advance to review step
      await tester.ensureVisible(find.text('Xem lại thông tin đặt lịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem lại thông tin đặt lịch'));
      await tester.pumpAndSettle();

      // Review Step verification
      expect(find.text('Xác nhận thông tin đặt lịch'), findsOneWidget);
      expect(find.text('Khoản cọc cam kết xem thực địa'), findsOneWidget);
      expect(find.textContaining('350.000 VNĐ'), findsOneWidget);
      expect(find.text('Vũ Tuấn'), findsOneWidget);
      expect(find.text('0977112233'), findsOneWidget);
      expect(find.text('Cần xe đưa đón của chuyên viên'), findsOneWidget);

      // Test "Quay lại chỉnh sửa" preserves inputs
      await tester.tap(find.text('Quay lại chỉnh sửa'));
      await tester.pumpAndSettle();
      expect(find.text('Vũ Tuấn'), findsOneWidget);
      expect(find.text('0977112233'), findsOneWidget);

      // Go forward to review again
      await tester.ensureVisible(find.text('Xem lại thông tin đặt lịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem lại thông tin đặt lịch'));
      await tester.pumpAndSettle();

      // Guest submits: prompted with LoginPromptSheet
      await tester.tap(find.text('Xác nhận đặt lịch'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập để xác nhận đặt lịch'), findsOneWidget);

      // Dismiss login dialog (simulate back/cancel)
      await tester.tap(find.text('Để sau (Tiếp tục chế độ khách)'));
      await tester.pumpAndSettle();

      // Form is still on Review Step with inputs retained!
      expect(find.text('Xác nhận thông tin đặt lịch'), findsOneWidget);
      expect(find.text('Vũ Tuấn'), findsOneWidget);
    });

    testWidgets('Authenticated user successfully creates booking', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deps = createFakeDependencies();
      final session = Session(
        profile: UserProfile(
          id: 'user-01',
          displayName: 'Nguyễn Văn Đạt',
          contactPhone: '0909998877',
          contactVerified: true,
          updatedAt: DateTime.utc(2026, 10, 16),
        ),
        expiresAt: DateTime.utc(2026, 12, 31),
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const BookingSheet(propertyId: '00000000-0000-4000-8000-000000000005'),
          deps: deps,
          initialAuth: AuthAuthenticated(session),
        ),
      );
      await tester.pumpAndSettle();

      // Pre-filled from profile
      expect(find.text('Nguyễn Văn Đạt'), findsOneWidget);
      expect(find.text('0909998877'), findsOneWidget);

      // Advance to review
      await tester.ensureVisible(find.text('Xem lại thông tin đặt lịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem lại thông tin đặt lịch'));
      await tester.pumpAndSettle();

      // Confirm submit
      await tester.tap(find.text('Xác nhận đặt lịch'));
      await tester.pumpAndSettle();

      // Success Step
      expect(find.text('Đặt lịch thực địa thành công!'), findsOneWidget);
      expect(find.text('Chờ đặt cọc'), findsOneWidget);

      // Verify booking stored in repository
      final history = await deps.bookings.getHistory(const PageQuery());
      expect(history.items.length, equals(1));
      expect(history.items.first.contactName, equals('Nguyễn Văn Đạt'));
    });
  });

  group('W2 B4: Transaction History in MainNavigationShell Tab 2', () {
    testWidgets('Guest sees login notice in transaction tab without hardcoded card', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deps = createFakeDependencies();
      await tester.pumpWidget(
        _buildTestApp(
          child: const MainNavigationShell(initialIndex: 2),
          deps: deps,
          initialAuth: const AuthGuest(),
        ),
      );
      await tester.pumpAndSettle();

      // Giao dịch tab
      expect(find.text('Lịch sử đặt lịch thực địa'), findsOneWidget);
      expect(find.text('Vui lòng đăng nhập để xem danh sách lịch hẹn khảo sát thực địa của bạn.'), findsOneWidget);
      expect(find.text('Đăng nhập ngay'), findsOneWidget);

      // Hardcoded mock card #XL-BK-8821 is gone!
      expect(find.text('#XL-BK-8821'), findsNothing);
    });

    testWidgets('Authenticated user sees real bookings from repository', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deps = createFakeDependencies();
      // Pre-create booking in repository
      await deps.bookings.create(
        BookingInput(
          propertyId: '00000000-0000-4000-8000-000000000005',
          slotId: 'slot-01',
          attendeeCount: 2,
          transportMode: TransportMode.selfArranged,
          requestDocuments: true,
          requestLoanAdvice: false,
          contactName: 'Phạm Minh',
          contactPhone: '0911223344',
        ),
        idempotencyKey: 'bk-init-test',
      );

      final session = Session(
        profile: UserProfile(
          id: 'user-01',
          displayName: 'Phạm Minh',
          contactVerified: true,
          updatedAt: DateTime.utc(2026, 10, 16),
        ),
        expiresAt: DateTime.utc(2026, 12, 31),
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const MainNavigationShell(initialIndex: 2),
          deps: deps,
          initialAuth: AuthAuthenticated(session),
        ),
      );
      await tester.pumpAndSettle();

      // Real booking is displayed
      expect(find.text('Đất nền Hòa Lạc'), findsOneWidget);
      expect(find.text('Chờ thanh toán cọc'), findsWidgets);
      expect(find.text('Chi tiết lịch'), findsOneWidget);
    });
  });
}
