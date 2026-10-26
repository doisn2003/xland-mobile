import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/account/pages/settings_page.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/feed/widgets/video_player_item.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_history_page.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';
import 'fakes/fake_xland_dependencies.dart';

class ControllableBookingRepository extends FakeBookingRepository {
  final pending = <Completer<Page<Booking>>>[];

  @override
  Future<Page<Booking>> getHistory(PageQuery page, {BookingStatus? status}) {
    final completer = Completer<Page<Booking>>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  // Keep infinite decorative animation static in non-animation regression tests.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P3-B0a History & Transaction Transition Risk Regressions', () {
    testWidgets('out-of-order error response does not overwrite newer state', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final d = createFakeDependencies();
      await d.account.signIn(const SignInInput(username: 'owner_a', password: 'review_password'));
      final historyRepo = ControllableBookingRepository();
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
        DependenciesScope(
          dependencies: deps,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const BookingHistoryPage(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(historyRepo.pending, isNotEmpty);
      final initialRequest = historyRepo.pending.first;

      // Switch account to owner_b
      await d.account.signIn(const SignInInput(username: 'owner_b', password: 'review_password'));
      await auth.checkSession();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Complete newer request for owner_b
      final newerRequests = historyRepo.pending.skip(1).toList();
      for (final req in newerRequests) {
        req.complete(const Page<Booking>(items: [], hasMore: false, nextCursor: null));
      }
      await tester.pumpAndSettle();

      // Complete older initial request from owner_a with an error
      initialRequest.completeError(
        const XlandFailure(code: FailureCode.offline, message: 'STALE_OWNER_A_ERROR'),
      );
      await tester.pumpAndSettle();

      // The stale error from owner_a must NOT leak into owner_b's UI
      expect(find.textContaining('STALE_OWNER_A_ERROR'), findsNothing);
    });

    testWidgets('logout immediately clears booking history and ignores pending response', (tester) async {
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
        DependenciesScope(
          dependencies: deps,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const BookingHistoryPage(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Complete initial load with hasMore = true
      expect(historyRepo.pending, isNotEmpty);
      historyRepo.pending.last.complete(
        Page<Booking>(items: [sampleBooking], hasMore: true, nextCursor: 'c-02'),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('bk-sample-01'), findsOneWidget);

      // Now switch account to guest (logout)
      await d.account.signOut();
      await auth.checkSession();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // History must be cleared immediately upon logout
      expect(find.textContaining('bk-sample-01'), findsNothing);
      expect(find.text('Tài khoản khách'), findsOneWidget);
    });

    testWidgets('refresh while loadMore pending discards loadMore response', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final d = createFakeDependencies();
      await d.account.signIn(const SignInInput(username: 'owner_a', password: 'review_password'));
      final historyRepo = ControllableBookingRepository();
      final sampleBooking1 = await FakeBookingRepository().getBooking('bk-sample-01');
      final sampleBooking2 = await FakeBookingRepository().getBooking('bk-sample-02');
      final sampleBooking3 = await FakeBookingRepository().getBooking('bk-sample-03');

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
        DependenciesScope(
          dependencies: deps,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const BookingHistoryPage(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Complete initial load (Page 1) with hasMore = true
      historyRepo.pending.last.complete(
        Page<Booking>(items: [sampleBooking1], hasMore: true, nextCursor: 'c-02'),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('bk-sample-01'), findsOneWidget);

      // Trigger loadMore
      final loadMoreBtn = find.widgetWithText(OutlineButton, 'Tải thêm lịch hẹn');
      expect(loadMoreBtn, findsOneWidget);
      final countBeforeLoadMore = historyRepo.pending.length;
      await tester.ensureVisible(loadMoreBtn);
      await tester.tap(loadMoreBtn);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(historyRepo.pending.length, countBeforeLoadMore + 1);
      final pendingLoadMore = historyRepo.pending.last;

      // While loadMore is pending, trigger refresh via pull-to-refresh
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(historyRepo.pending.length, countBeforeLoadMore + 2);
      final pendingRefresh = historyRepo.pending.last;

      // Complete refresh first with sampleBooking3
      pendingRefresh.complete(
        Page<Booking>(items: [sampleBooking3], hasMore: false, nextCursor: null),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('bk-sample-03'), findsOneWidget);

      // Now complete older pending loadMore with sampleBooking2
      pendingLoadMore.complete(
        Page<Booking>(items: [sampleBooking2], hasMore: false, nextCursor: null),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Verify: bk-sample-02 was discarded because loadMore belonged to older epoch
      expect(find.textContaining('bk-sample-02'), findsNothing);
      expect(find.textContaining('bk-sample-03'), findsOneWidget);
    });
  });

  group('P3-B0b Settings & UX Independent Tests', () {
    testWidgets('Settings page allows guest to change local preferences without calling private API', (tester) async {
      final deps = createFakeDependencies();
      final auth = AuthCubit(deps.account);
      addTearDown(auth.close);

      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const SettingsPage(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Cài đặt ứng dụng'), findsOneWidget);
      expect(find.text('Thông báo & Tương tác'), findsOneWidget);
      expect(find.text('Tự động phát video'), findsOneWidget);

      final autoplaySwitch = find.widgetWithText(SwitchListTile, 'Tự động phát video');
      await tester.tap(autoplaySwitch);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Đã lưu tùy chọn trên thiết bị.'), findsOneWidget);
    });

    testWidgets('Video player item handles build and does not show raw PlatformException', (tester) async {
      final deps = createFakeDependencies();
      final feedPage = await deps.feed.getFeed(const PageQuery(limit: 1));
      final video = feedPage.items.first;

      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: VideoPlayerItem(
                video: video,
                isCurrent: true,
                isAppActive: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('stackTrace'), findsNothing);
    });
  });
}
