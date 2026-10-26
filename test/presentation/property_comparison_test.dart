import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/property_detail/cubit/property_detail_cubit.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_comparison_page.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_detail_page.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/property_comparison_picker.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/property_media_viewer.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/media_gallery_view.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/finance_plan_tab.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/shared/sharing/share_sheet.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

class SearchRepository extends FakePropertyRepository {
  final queries = <String?>[];
  final cursors = <String?>[];
  Completer<PropertySearchResult>? pending;
  bool fail = false;
  @override
  Future<PropertySearchResult> search(PropertyFilter filter, PageQuery page) {
    queries.add(filter.query);
    cursors.add(page.cursor);
    if (fail) {
      return Future.error(
        const XlandFailure(code: FailureCode.offline, message: 'Offline'),
      );
    }
    return pending?.future ?? super.search(filter, page);
  }
}

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  FakePropertyRepository? repo,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final deps = createFakeDependencies(propertyRepo: repo);
  final auth = AuthCubit(deps.account);
  addTearDown(auth.close);
  await tester.pumpWidget(
    DependenciesScope(
      dependencies: deps,
      child: BlocProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder pane(int index) => find.byKey(ValueKey('comparison-pane-$index'));
Finder within(int index, Finder child) =>
    find.descendant(of: pane(index), matching: child);
PropertyDetailCubit detail(WidgetTester tester, int index) => tester
    .element(within(index, find.byType(PropertyDetailView)))
    .read<PropertyDetailCubit>();

Future<void> openComparison(
  WidgetTester tester, {
  Size size = const Size(844, 390),
  double scale = 1,
}) async {
  final repo = FakePropertyRepository();
  final first = await repo.getProperty('XL-028');
  final second = await repo.getProperty('XL-029');
  await mount(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    PropertyComparisonPage(first: first, second: second),
              ),
            ),
            child: const Text('Compare fixture'),
          ),
        ),
      ),
    ),
    repo: repo,
    size: size,
    scale: scale,
  );
  await tester.tap(find.text('Compare fixture'));
  await tester.pumpAndSettle();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final orientations = <List<dynamic>>[];
  setUpAll(() async {
    final fonts = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await fonts.load();
  });
  setUp(() {
    orientations.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(List<dynamic>.from(call.arguments as List));
        }
        return null;
      },
    );
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  testWidgets(
    'compare action sits between bookmark/share and picker excludes current property',
    (tester) async {
      await mount(tester, const PropertyDetailPage(propertyId: 'XL-028'));
      final compare = find.byTooltip('So sánh lô đất');
      expect(
        tester.getCenter(compare).dx,
        greaterThan(tester.getCenter(find.bySemanticsLabel('Lưu')).dx),
      );
      expect(
        tester.getCenter(compare).dx,
        lessThan(tester.getCenter(find.bySemanticsLabel('Chia sẻ')).dx),
      );
      await tester.tap(compare);
      await tester.pumpAndSettle();
      expect(find.byType(PropertyComparisonPicker), findsOneWidget);
      expect(
        find.byKey(
          ValueKey(
            'compare-choice-${FakePropertyRepository.sampleProperty.id}',
          ),
        ),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), 'XL-029');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Không tìm thấy lô đất phù hợp.\nThử tên, mã lô hoặc khu vực khác.',
        ),
        findsNothing,
      );
      final second = await FakePropertyRepository().getProperty('XL-029');
      await tester.tap(find.byKey(ValueKey('compare-choice-${second.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(PropertyComparisonPage), findsOneWidget);
      expect(
        detail(tester, 0).propertyId,
        FakePropertyRepository.sampleProperty.id,
      );
      expect(detail(tester, 1).propertyId, second.id);
      expect(find.byTooltip('So sánh lô đất'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker ignores stale searches, retries failures and clears empty search',
    (tester) async {
      final repo = SearchRepository();
      await mount(
        tester,
        Scaffold(
          body: PropertyComparisonPicker(
            currentProperty: FakePropertyRepository.sampleProperty,
          ),
        ),
        repo: repo,
      );
      final pending = Completer<PropertySearchResult>();
      repo.pending = pending;
      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump(const Duration(milliseconds: 350));
      repo.pending = null;
      await tester.enterText(find.byType(TextField), 'XL-029');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      pending.complete(
        const PropertySearchResult(
          page: Page(items: [], hasMore: false),
          total: 0,
          selectedCriteriaCount: 1,
        ),
      );
      await tester.pumpAndSettle();
      final second = await repo.getProperty('XL-029');
      expect(
        find.byKey(ValueKey('compare-choice-${second.id}')),
        findsOneWidget,
      );
      repo.fail = true;
      await tester.enterText(find.byType(TextField), 'nothing matches');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không tìm thấy lô đất phù hợp.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.queries.last, isNull);
      await tester.scrollUntilVisible(
        find.text('Xem thêm lô đất'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Xem thêm lô đất'), findsOneWidget);
    },
  );

  testWidgets('picker pagination retries keep cursor and existing rows', (
    tester,
  ) async {
    final repo = SearchRepository();
    await mount(
      tester,
      Scaffold(
        body: PropertyComparisonPicker(
          currentProperty: FakePropertyRepository.sampleProperty,
        ),
      ),
      repo: repo,
    );
    await tester.scrollUntilVisible(
      find.text('Xem thêm lô đất'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    repo.fail = true;
    await tester.tap(find.text('Xem thêm lô đất'));
    await tester.pumpAndSettle();
    expect(repo.cursors.last, '20');
    repo.fail = false;
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(repo.cursors, [null, '20', '20']);
    expect(find.text('Xem thêm lô đất'), findsNothing);
  });

  testWidgets(
    'landscape panes scroll and switch tabs independently; orientation restores on close',
    (tester) async {
      await openComparison(tester);
      expect(orientations.first, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
      final leftScroll = tester
          .widget<CustomScrollView>(within(0, find.byType(CustomScrollView)))
          .controller!;
      final rightScroll = tester
          .widget<CustomScrollView>(within(1, find.byType(CustomScrollView)))
          .controller!;
      await tester.drag(
        within(0, find.byType(CustomScrollView)),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      expect(leftScroll.offset, greaterThan(0));
      expect(rightScroll.offset, 0);
      await tester.tap(within(0, find.text('Hồ sơ')));
      await tester.pumpAndSettle();
      expect(detail(tester, 0).state.activeTab, 1);
      expect(detail(tester, 1).state.activeTab, 0);
      await tester.tap(find.byTooltip('Đóng so sánh'));
      await tester.pumpAndSettle();
      expect(find.byType(PropertyComparisonPage), findsNothing);
      expect(orientations.last, isEmpty);
    },
  );

  testWidgets('gallery navigation and system back stay in the active pane', (
    tester,
  ) async {
    await openComparison(tester);
    await tester.tap(within(0, find.byType(MediaGalleryView)));
    await tester.pumpAndSettle();
    expect(within(0, find.byType(PropertyMediaViewer)), findsOneWidget);
    expect(within(1, find.byType(PropertyDetailView)), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PropertyMediaViewer), findsNothing);
    expect(find.byType(PropertyComparisonPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PropertyComparisonPage), findsNothing);
    expect(orientations.last, isEmpty);
  });

  testWidgets(
    'share sheet is confined to one pane while the other stays interactive',
    (tester) async {
      await openComparison(tester);
      await tester.tap(within(0, find.byIcon(Icons.share_outlined)));
      await tester.pumpAndSettle();
      expect(within(0, find.byType(ShareSheet)), findsOneWidget);
      expect(within(1, find.byType(ShareSheet)), findsNothing);
      await tester.tap(within(1, find.text('Hồ sơ')));
      await tester.pumpAndSettle();
      expect(detail(tester, 1).state.activeTab, 1);
      expect(within(0, find.byType(ShareSheet)), findsOneWidget);
    },
  );

  for (final size in [const Size(667, 375), const Size(844, 390)]) {
    testWidgets('landscape layout at $size supports enlarged text', (
      tester,
    ) async {
      await openComparison(tester, size: size, scale: 1.3);
      await tester.drag(
        within(0, find.byType(CustomScrollView)),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(within(0, find.text('Tài chính')));
      await tester.tap(within(0, find.text('Tài chính')));
      await tester.pumpAndSettle();
      expect(detail(tester, 0).state.activeTab, 3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'landscape keyboard preserves both finance states without overflowing',
    (tester) async {
      await openComparison(tester, size: const Size(667, 375));
      await tester.drag(
        within(0, find.byType(CustomScrollView)),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(within(0, find.text('Tài chính')));
      await tester.pumpAndSettle();
      await tester.tap(within(0, find.text('Tài chính')));
      await tester.pumpAndSettle();
      final finance = tester.state(within(0, find.byType(FinancePlanTab)));
      final other = detail(tester, 1);
      tester.view.viewInsets = const FakeViewPadding(bottom: 190);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.state(within(0, find.byType(FinancePlanTab))),
        same(finance),
      );
      expect(detail(tester, 1), same(other));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(
        tester.state(within(0, find.byType(FinancePlanTab))),
        same(finance),
      );
    },
  );

  test('closing a loading detail does not emit into a disposed pane', () async {
    final pending = Completer<Property>();
    final repo = _DelayedDetail(pending);
    final cubit = PropertyDetailCubit(
      repo,
      FakeConsultantRepository(),
      propertyId: 'XL-028',
    );
    final load = cubit.loadPropertyDetail();
    await cubit.close();
    pending.complete(FakePropertyRepository.sampleProperty);
    await expectLater(load, completes);
  });
}

class _DelayedDetail extends FakePropertyRepository {
  _DelayedDetail(this.pending);
  final Completer<Property> pending;
  @override
  Future<Property> getProperty(String propertyId) => pending.future;
}
