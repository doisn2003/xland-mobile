import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/widgets/login_prompt_sheet.dart';
import 'package:xland_mobile/presentation/features/discovery/cubit/filter_cubit.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/property_filter_sheet.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_detail_page.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/media_gallery_view.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/property_media_viewer.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/shared/widgets/navbar.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

class _RecordingFeed extends FakeFeedRepository {
  final scopes = <FeedScope>[];
  @override
  Future<Page<FeedVideo>> getFeed(
    PageQuery page, {
    FeedScope feedScope = FeedScope.recommended,
    Region? region,
    PropertyCategory? category,
  }) {
    scopes.add(feedScope);
    return super.getFeed(
      page,
      feedScope: feedScope,
      region: region,
      category: category,
    );
  }
}

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'budget preserves fractional VND and reset recovers from invalid input',
    (tester) async {
      viewport(tester);
      final cubit = FilterCubit(
        FakePropertyRepository(),
        initialFilter: const PropertyFilter(
          regions: [],
          areaBands: [],
          landTypes: [],
          savedOnly: false,
          sort: PropertySort.relevant,
        ),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const PropertyFilterSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inputs = find.byType(TextField);
      await tester.ensureVisible(inputs.first);
      await tester.enterText(inputs.first, '1,250000001');
      await tester.enterText(inputs.last, '2,75');
      await tester.pumpAndSettle();
      expect(cubit.state.draftFilter.minPriceVnd!.wireValue, '1250000001');
      expect(cubit.state.draftFilter.maxPriceVnd!.wireValue, '2750000000');
      await tester.enterText(inputs.first, 'NaN');
      await tester.pumpAndSettle();
      expect(cubit.state.isPriceValid, isFalse);
      await tester.tap(find.text('Đặt lại'));
      await tester.pumpAndSettle();
      expect(cubit.state.isPriceValid, isTrue);
      expect(cubit.state.selectedCriteriaCount, 0);
      expect(tester.widget<TextField>(inputs.first).controller!.text, isEmpty);
    },
  );

  testWidgets(
    'immersive feed keeps metadata, changes API scope and exposes navigation',
    (tester) async {
      viewport(tester);
      final d = createFakeDependencies();
      final feed = _RecordingFeed();
      final deps = XlandDependencies(
        properties: d.properties,
        feed: feed,
        consultants: d.consultants,
        events: d.events,
        bookings: d.bookings,
        payments: d.payments,
        account: d.account,
        clubs: d.clubs,
        finance: d.finance,
        support: d.support,
        guestPreferences: d.guestPreferences,
      );
      await d.account.signIn(
        const SignInInput(username: 'owner_a', password: 'review_password'),
      );
      final auth = AuthCubit(d.account);
      await auth.checkSession();
      addTearDown(auth.close);
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: BlocProvider.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MainNavigationShell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(XLandBottomNavBar), findsNothing);
      expect(find.text('2,4 tỷ'), findsOneWidget);
      expect(find.textContaining('Mặt tiền 6 m'), findsOneWidget);
      expect(find.text('Hướng Đông Nam'), findsOneWidget);
      await tester.tap(find.text('Đang theo dõi'));
      await tester.pumpAndSettle();
      expect(feed.scopes.last, FeedScope.following);
      await tester.tap(find.byTooltip('Mở điều hướng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khám phá'));
      await tester.pumpAndSettle();
      expect(find.byType(XLandBottomNavBar), findsOneWidget);
    },
  );

  testWidgets('finance sticky save reaches the existing authentication gate', (
    tester,
  ) async {
    viewport(tester);
    final deps = createFakeDependencies();
    final auth = AuthCubit(deps.account);
    addTearDown(auth.close);
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: deps,
        child: BlocProvider.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PropertyDetailPage(propertyId: 'XL-028', initialTab: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu phương án'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPromptSheet), findsOneWidget);
  });

  testWidgets('property gallery opens a swipeable full screen image viewer', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MediaGalleryView(
            media: const [
              MediaAsset(
                id: 'a',
                kind: MediaKind.image,
                altText: 'A',
                isIllustrative: true,
              ),
              MediaAsset(
                id: 'b',
                kind: MediaKind.image,
                altText: 'B',
                isIllustrative: true,
              ),
            ],
            currentIndex: 0,
            onIndexChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1/2'));
    await tester.pumpAndSettle();
    expect(find.byType(PropertyMediaViewer), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });
}
