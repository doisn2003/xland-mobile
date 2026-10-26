import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/pages/login_page.dart';
import 'package:xland_mobile/presentation/features/discovery/pages/discovery_page.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/property_filter_sheet.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_detail_page.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/area_info_tab.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/finance_plan_tab.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/legal_summary_tab.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/property_overview_tab.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_detail_page.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_sheet.dart';
import 'package:xland_mobile/presentation/features/clubs/pages/club_detail_page.dart';
import 'package:xland_mobile/presentation/features/clubs/pages/club_list_page.dart';
import 'package:xland_mobile/presentation/features/consultant/pages/consultant_profile_page.dart';
import 'package:xland_mobile/presentation/features/events/pages/event_detail_page.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/features/account/pages/edit_profile_page.dart';
import 'package:xland_mobile/presentation/features/account/pages/settings_page.dart';
import 'package:xland_mobile/presentation/features/account/pages/saved_properties_page.dart';
import 'package:xland_mobile/presentation/features/feed/pages/saved_videos_page.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'fakes/fake_xland_dependencies.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

void main() {
  // Keep infinite decorative animation static in non-animation regression tests.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  TestWidgetsFlutterBinding.ensureInitialized();

  final captureScreenshots = Platform.environment['CAPTURE_SCREENSHOTS'] == 'true';
  final sdkPath = Platform.environment['FLUTTER_SDK_PATH'] ??
      'C:/Users/Admin/AppData/Local/XLandTools/flutter';
  final screenshotDir = Platform.environment['SCREENSHOT_DIR'] ??
      'C:/OwnProject/XLAND-PROJECT/brain/logs/agent-b/evidence/run_20261017';

  setUpAll(() async {
    if (!captureScreenshots) return;

    final textFonts = FontLoader('Roboto');
    for (final file in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      final fontPath = '$sdkPath/engine/src/flutter/txt/third_party/fonts/$file';
      if (File(fontPath).existsSync()) {
        textFonts.addFont(
          File(fontPath).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
    }
    await textFonts.load();

    final icons = FontLoader('MaterialIcons');
    final iconPath = '$sdkPath/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(iconPath).existsSync()) {
      icons.addFont(
        File(iconPath).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await icons.load();
  });

  for (final (width, scale) in [
    (360.0, 1.0),
    (360.0, 1.3),
    (390.0, 1.0),
    (390.0, 1.3),
    (430.0, 1.0),
    (430.0, 1.3),
  ]) {
    testWidgets(
      'Capture Phase 2 Screens width=$width scale=$scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final deps = createFakeDependencies();
        final authCubit = AuthCubit(deps.account);

        Future<void> saveRepaint(GlobalKey key, String name) async {
          await tester.runAsync(() async {
            for (final asset in ['countryside-landscape.png', 'countryside-portrait.png', 'coastal-landscape.png', 'community-coffee.png', 'consultant-fictional.png']) {
              await precacheImage(AssetImage('assets/images/report/$asset'), key.currentContext!);
            }
          });
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1);
            final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory(screenshotDir);
            await directory.create(recursive: true);
            await File('${directory.path}/${width.toInt()}-$scale-$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }

        // 1. Discovery S01 & S09 Filter Sheet (Capture overlay via MaterialApp.builder)
        final discRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => RepaintBoundary(
                key: discRootKey,
                child: child!,
              ),
              home: const DiscoveryPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await saveRepaint(discRootKey, 'discovery-s01');

        // 2. S09 Filter Sheet (tap filter icon)
        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(PropertyFilterSheet), findsOneWidget);
        await saveRepaint(discRootKey, 'filter-s09');

        // Close filter sheet
        await tester.tap(find.textContaining('Xem'));
        await tester.pumpAndSettle();

        // 3. Property Detail (S02 Overview, S03 Legal, S04 Area, S05 Finance)
        final detailRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: detailRootKey,
                  child: child!,
                ),
                home: const PropertyDetailPage(propertyId: 'XL-028'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PropertyOverviewTab), findsOneWidget);
        await saveRepaint(detailRootKey, 'detail-s02-overview');
        await tester.tap(find.text('Đặt lịch thực địa'));
        await tester.pumpAndSettle();
        await saveRepaint(detailRootKey, 'booking-s08-form');
        Navigator.of(tester.element(find.byType(BookingSheet))).pop();
        await tester.pumpAndSettle();

        // Tab S03: Legal
        final legalTabFinder = find.text('Hồ sơ');
        await tester.ensureVisible(legalTabFinder);
        await tester.tap(legalTabFinder);
        await tester.pumpAndSettle();
        expect(find.byType(LegalSummaryTab), findsOneWidget);
        await saveRepaint(detailRootKey, 'detail-s03-legal');

        // Tab S04: Area
        final areaTabFinder = find.text('Khu vực');
        await tester.ensureVisible(areaTabFinder);
        await tester.tap(areaTabFinder);
        await tester.pumpAndSettle();
        expect(find.byType(AreaInfoTab), findsOneWidget);
        await saveRepaint(detailRootKey, 'detail-s04-area');

        // Tab S05: Finance (scroll into view, assert FinancePlanTab rendered to avoid missed tap)
        final financeTabFinder = find.text('Tài chính');
        await tester.ensureVisible(financeTabFinder);
        await tester.tap(financeTabFinder);
        await tester.pumpAndSettle();
        expect(find.byType(FinancePlanTab), findsOneWidget);
        await saveRepaint(detailRootKey, 'detail-s05-finance');

        // 4. Login Page
        final loginRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: loginRootKey,
                  child: child!,
                ),
                home: const LoginPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        await saveRepaint(loginRootKey, 'auth-login');

        // 5. S06 Consultant Profile Page
        final consultantRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: consultantRootKey,
                  child: child!,
                ),
                home: const ConsultantProfilePage(consultantId: '00000000-0000-4000-8000-000000000030'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ConsultantProfilePage), findsOneWidget);
        await saveRepaint(consultantRootKey, 'consultant-s06');

        // 6. S07 Event Detail Page
        final eventRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: eventRootKey,
                  child: child!,
                ),
                home: const EventDetailPage(eventId: 'ev-001'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EventDetailPage), findsOneWidget);
        await saveRepaint(eventRootKey, 'event-s07');

        // 7. K01 Club List Page
        final clubListRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: clubListRootKey,
                  child: child!,
                ),
                home: const ClubListPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ClubListPage), findsOneWidget);
        await saveRepaint(clubListRootKey, 'club-k01-list');

        // 8. K02 Club Detail Page
        final clubDetailRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: clubDetailRootKey,
                  child: child!,
                ),
                home: const ClubDetailPage(clubId: 'club-01'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ClubDetailPage), findsOneWidget);
        await saveRepaint(clubDetailRootKey, 'club-k02-detail');

        // 9. Booking Detail Page
        final bookingDetailRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: bookingDetailRootKey,
                  child: child!,
                ),
                home: const BookingDetailPage(bookingId: 'bk-sample-01'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BookingDetailPage), findsOneWidget);
        expect(find.text('Mã lịch hẹn: #bk-sample-01'), findsOneWidget);
        expect(find.text('Chờ đặt cọc'), findsOneWidget);
        await saveRepaint(bookingDetailRootKey, 'booking-detail');

        // 10. S00 Feed in MainNavigationShell
        final feedRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: feedRootKey,
                  child: child!,
                ),
                home: const MainNavigationShell(key: ValueKey('shell-feed'), initialIndex: 0),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MainNavigationShell), findsOneWidget);
        await saveRepaint(feedRootKey, 'feed-s00');

        // 11. Tab 2 History in MainNavigationShell
        final historyRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: historyRootKey,
                  child: child!,
                ),
                home: const MainNavigationShell(key: ValueKey('shell-history'), initialIndex: 2),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sự kiện'), findsAtLeast(1));
        await saveRepaint(historyRootKey, 'history-tab2');

        // 12. Tab 3 Profile in MainNavigationShell
        final profileRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: profileRootKey,
                  child: child!,
                ),
                home: const MainNavigationShell(key: ValueKey('shell-profile'), initialIndex: 3),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cài đặt & Tiện ích'), findsOneWidget);
        await saveRepaint(profileRootKey, 'profile-tab3');

        // 13. EditProfilePage
        final editProfileRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: editProfileRootKey,
                  child: child!,
                ),
                home: const EditProfilePage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EditProfilePage), findsOneWidget);
        await saveRepaint(editProfileRootKey, 'account-edit-profile');

        // 14. SettingsPage
        final settingsRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: settingsRootKey,
                  child: child!,
                ),
                home: const SettingsPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.text('Tự động phát video'), findsOneWidget);
        await saveRepaint(settingsRootKey, 'account-settings');

        // 15. SavedPropertiesPage
        final savedPropRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: savedPropRootKey,
                  child: child!,
                ),
                home: const SavedPropertiesPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SavedPropertiesPage), findsOneWidget);
        await saveRepaint(savedPropRootKey, 'saved-properties');

        // 16. SavedVideosPage
        final savedVidRootKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: savedVidRootKey,
                  child: child!,
                ),
                home: const SavedVideosPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SavedVideosPage), findsOneWidget);
        await saveRepaint(savedVidRootKey, 'saved-videos');

        // 17. BookingDetailPage with long UUID & localized selfArranged
        final longUuidKey = GlobalKey();
        await tester.pumpWidget(
          DependenciesScope(
            dependencies: deps,
            child: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: MaterialApp(
              theme: AppTheme.lightTheme,
                builder: (context, child) => RepaintBoundary(
                  key: longUuidKey,
                  child: child!,
                ),
                home: const BookingDetailPage(bookingId: 'bk-00000000-0000-4000-8000-000000000099'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BookingDetailPage), findsOneWidget);
        expect(find.text('Mã lịch hẹn: #bk-00000000-0000-4000-8000-000000000099'), findsOneWidget);
        expect(find.text('Tự túc phương tiện'), findsOneWidget);
        await saveRepaint(longUuidKey, 'booking-detail-long-uuid');
      },
      skip: !captureScreenshots,
    );
  }
}
