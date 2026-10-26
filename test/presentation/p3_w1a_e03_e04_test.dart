import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_state.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_sheet.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_history_page.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';
import 'fakes/fake_xland_dependencies.dart';

class CountBookingsRepository extends FakeBookingRepository {
  int createCalls = 0;
  final List<BookingInput> createdInputs = [];

  @override
  Future<Booking> create(BookingInput input, {required String idempotencyKey}) {
    createCalls++;
    createdInputs.add(input);
    return super.create(input, idempotencyKey: idempotencyKey);
  }
}

class ControllableBookingRepository extends FakeBookingRepository {
  final pending = <Completer<Page<Booking>>>[];

  @override
  Future<Page<Booking>> getHistory(PageQuery page, {BookingStatus? status}) {
    final completer = Completer<Page<Booking>>();
    pending.add(completer);
    return completer.future;
  }
}

Widget _buildTestApp({
  required Widget child,
  required XlandDependencies deps,
  AuthState? initialAuth,
  AuthCubit? authCubit,
}) {
  final auth = authCubit ?? AuthCubit(deps.account);
  if (initialAuth != null) {
    auth.emit(initialAuth);
  }
  return DependenciesScope(
    dependencies: deps,
    child: BlocProvider<AuthCubit>.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 W1a — E03: Guest Booking Flow & Zero POST Review Reconfirm', () {
    testWidgets('Guest filling form -> login -> review produces exactly 0 POST until explicit reconfirm', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final countingRepo = CountBookingsRepository();
      final base = createFakeDependencies();
      final deps = XlandDependencies(
        properties: base.properties,
        feed: base.feed,
        consultants: base.consultants,
        events: base.events,
        bookings: countingRepo,
        payments: base.payments,
        account: base.account,
        clubs: base.clubs,
        finance: base.finance,
        support: base.support,
      );

      final auth = AuthCubit(deps.account);
      addTearDown(auth.close);

      await tester.pumpWidget(
        _buildTestApp(
          child: const BookingSheet(propertyId: '00000000-0000-4000-8000-000000000005'),
          deps: deps,
          authCubit: auth,
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Form Step
      expect(find.text('Đặt lịch xem thực địa'), findsOneWidget);
      expect(find.text('Khung giờ khảo sát'), findsOneWidget);

      final formFields = find.descendant(of: find.byType(BookingSheet), matching: find.byType(TextField));
      await tester.enterText(formFields.at(0), 'Nguyễn Văn W1');
      await tester.enterText(formFields.at(1), '0988776655');

      // Step 2: Advance to Review Step
      await tester.ensureVisible(find.text('Xem lại thông tin đặt lịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem lại thông tin đặt lịch'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận thông tin đặt lịch'), findsOneWidget);
      expect(find.text('Khoản cọc cam kết xem thực địa'), findsOneWidget);
      expect(find.textContaining('350.000 VNĐ'), findsOneWidget);

      // Verify ZERO POSTs before clicking confirm
      expect(countingRepo.createCalls, 0);

      // Step 3: Guest clicks 'Xác nhận đặt lịch' -> Login prompt sheet
      await tester.tap(find.text('Xác nhận đặt lịch'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập để xác nhận đặt lịch'), findsOneWidget);
      expect(countingRepo.createCalls, 0);

      // Proceed to login
      await tester.tap(find.text('Đăng nhập ngay'));
      await tester.pumpAndSettle();

      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.first, 'owner_a');
      await tester.enterText(loginFields.last, 'review_password');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      // CRITICAL E03 ASSERTION: After login completion, user returns to Review Step with ZERO POSTs!
      expect(find.text('Xác nhận thông tin đặt lịch'), findsOneWidget);
      expect(countingRepo.createCalls, 0, reason: 'Login completion must NOT auto-post or replay mutation');

      // Step 4: Explicit Reconfirm action creates the booking (exactly 1 POST)
      await tester.tap(find.text('Xác nhận đặt lịch'));
      await tester.pumpAndSettle();

      expect(countingRepo.createCalls, 1, reason: 'Explicit reconfirm triggers exactly one booking creation');
      expect(find.text('Đặt lịch thực địa thành công!'), findsOneWidget);
      expect(find.text('Chờ đặt cọc'), findsOneWidget);

      // Verify created booking contract status
      final createdBooking = countingRepo.createdInputs.first;
      expect(createdBooking.contactName, 'Nguyễn Văn W1');
      expect(createdBooking.contactPhone, '0988776655');
    });
  });

  group('Phase 3 W1a — E04: Session Transition & Isolation', () {
    testWidgets('History response from previous account is discarded after account switch', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final d = createFakeDependencies();
      await d.account.signIn(const SignInInput(username: 'owner_a', password: 'review_password'));
      final historyRepo = ControllableBookingRepository();
      final sampleBooking = await FakeBookingRepository().getBooking('bk-sample-01');

      final deps = XlandDependencies(
        properties: d.properties,
        feed: d.feed,
        consultants: d.consultants,
        events: d.events,
        bookings: historyRepo,
        payments: d.payments,
        account: d.account,
        clubs: d.clubs,
        finance: d.finance,
        support: d.support,
      );

      final auth = AuthCubit(d.account);
      addTearDown(auth.close);
      await auth.checkSession();

      await tester.pumpWidget(
        _buildTestApp(
          child: const BookingHistoryPage(),
          deps: deps,
          authCubit: auth,
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final initialRequests = List<Completer<Page<Booking>>>.from(historyRepo.pending);
      expect(initialRequests, isNotEmpty);

      // Switch to owner_b
      await d.account.signIn(const SignInInput(username: 'owner_b', password: 'review_password'));
      await auth.checkSession();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final newerRequests = historyRepo.pending.skip(initialRequests.length).toList();
      expect(newerRequests, isNotEmpty);

      // Complete newer request for owner_b first (empty list)
      for (final req in newerRequests) {
        req.complete(const Page<Booking>(items: [], hasMore: false, nextCursor: null));
      }
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Now complete older request from owner_a with bk-sample-01
      for (final req in initialRequests) {
        req.complete(Page<Booking>(items: [sampleBooking], hasMore: false, nextCursor: null));
      }
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Old owner_a response MUST NOT leak into owner_b view
      expect(find.textContaining('bk-sample-01'), findsNothing);
    });

    testWidgets('Logout clears booking history immediately and does not show stale data', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final d = createFakeDependencies();
      await d.account.signIn(const SignInInput(username: 'owner_a', password: 'review_password'));
      final historyRepo = ControllableBookingRepository();
      final sampleBooking = await FakeBookingRepository().getBooking('bk-sample-01');

      final deps = XlandDependencies(
        properties: d.properties,
        feed: d.feed,
        consultants: d.consultants,
        events: d.events,
        bookings: historyRepo,
        payments: d.payments,
        account: d.account,
        clubs: d.clubs,
        finance: d.finance,
        support: d.support,
      );

      final auth = AuthCubit(d.account);
      addTearDown(auth.close);
      await auth.checkSession();

      await tester.pumpWidget(
        _buildTestApp(
          child: const BookingHistoryPage(),
          deps: deps,
          authCubit: auth,
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      historyRepo.pending.last.complete(
        Page<Booking>(items: [sampleBooking], hasMore: false, nextCursor: null),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('bk-sample-01'), findsOneWidget);

      // Sign out
      await d.account.signOut();
      await auth.checkSession();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.textContaining('bk-sample-01'), findsNothing);
      expect(find.text('Tài khoản khách'), findsOneWidget);
    });
  });
}
