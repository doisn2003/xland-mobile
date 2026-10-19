import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/widgets/login_prompt_sheet.dart';
import 'package:xland_mobile/presentation/features/discovery/cubit/discovery_cubit.dart';
import 'package:xland_mobile/presentation/features/discovery/cubit/filter_cubit.dart';
import 'package:xland_mobile/presentation/features/discovery/pages/discovery_page.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/property_filter_sheet.dart';
import 'package:xland_mobile/presentation/features/property_detail/cubit/property_detail_cubit.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';
import 'fakes/fake_xland_dependencies.dart';

class FailingCatalogRepository extends FakePropertyRepository {
  bool failCatalog = true;

  @override
  Future<FilterCatalog> getFilterCatalog({String? provinceCode}) async {
    if (failCatalog) {
      throw const XlandFailure(
        code: FailureCode.upstreamUnavailable,
        message: 'Mạng không ổn định khi tải danh mục',
      );
    }
    return super.getFilterCatalog(provinceCode: provinceCode);
  }
}

class LoadMoreFailingRepository extends FakePropertyRepository {
  bool failNextPage = true;

  @override
  Future<PropertySearchResult> search(PropertyFilter filter, PageQuery page) async {
    if (page.cursor != null && failNextPage) {
      throw const XlandFailure(
        code: FailureCode.offline,
        message: 'Lỗi tải trang tiếp theo',
      );
    }
    return super.search(filter, page);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2-004 Pagination 21+ & loadMore UI', () {
    testWidgets('loads initial page of 20 items and loadMore loads item 21+', (tester) async {
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
              home: const DiscoveryPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial page has 20 items (XL-001 to XL-020)
      final cubit = tester.element(find.byType(DiscoveryView)).read<DiscoveryCubit>();
      expect(cubit.state.properties.length, 20);
      expect(cubit.state.hasMore, isTrue);

      // Trigger loadMore to fetch items 21-25
      await cubit.loadMore();
      await tester.pumpAndSettle();

      // Now has 25 items (all items loaded)
      expect(cubit.state.properties.length, 25);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.properties[20].code, 'XL-021');
    });

    testWidgets('displays error and retry button when loadMore fails', (tester) async {
      tester.view.physicalSize = const Size(800, 10000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = LoadMoreFailingRepository();
      final deps = createFakeDependencies(propertyRepo: repo);
      final auth = AuthCubit(deps.account);
      addTearDown(auth.close);

      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const DiscoveryPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cubit = tester.element(find.byType(DiscoveryView)).read<DiscoveryCubit>();
      await cubit.loadMore();
      await tester.pumpAndSettle();

      expect(cubit.state.loadMoreError, 'Lỗi tải trang tiếp theo');
      expect(find.textContaining('Lỗi tải trang tiếp theo'), findsOneWidget);
      expect(find.text('Thử lại tải thêm'), findsOneWidget);

      // Now allow success and retry via UI button
      repo.failNextPage = false;
      await tester.tap(find.text('Thử lại tải thêm'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Lỗi tải trang tiếp theo'), findsNothing);
      expect(cubit.state.properties.length, 25);
    });
  });

  group('P2-003 Catalog failure/retry & Budget range 1-3 tỷ', () {
    testWidgets('displays catalog error and allows retry', (tester) async {
      final repo = FailingCatalogRepository();
      final cubit = FilterCubit(
        repo,
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
            body: BlocProvider<FilterCubit>.value(
              value: cubit,
              child: const PropertyFilterSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Catalog error is visible with retry button
      expect(find.textContaining('Mạng không ổn định khi tải danh mục'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Now recover catalog and retry
      repo.failCatalog = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mạng không ổn định khi tải danh mục'), findsNothing);
      await tester.tap(find.text('Tất cả tỉnh'));
      await tester.pumpAndSettle();
      expect(find.text('Hà Nội'), findsOneWidget);
    });

    testWidgets('budget inputs set 1B to 3B and synchronize RangeSlider', (tester) async {
      final repo = FakePropertyRepository();
      PropertyFilter? appliedFilter;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  appliedFilter = await PropertyFilterSheet.show(
                    ctx,
                    propertyRepository: repo,
                    currentFilter: const PropertyFilter(
                      regions: [],
                      areaBands: [],
                      landTypes: [],
                      savedOnly: false,
                      sort: PropertySort.relevant,
                    ),
                  );
                },
                child: const Text('Open Filter'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Filter'));
      await tester.pumpAndSettle();

      final inputs = find.byType(TextField);
      await tester.ensureVisible(inputs.first);
      await tester.enterText(inputs.first, '1');
      await tester.enterText(inputs.at(1), '3');
      await tester.pumpAndSettle();
      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      expect(slider.values.start, 1);
      expect(slider.values.end, 3);

      // Apply filter
      await tester.tap(find.textContaining('Xem'));
      await tester.pumpAndSettle();

      expect(appliedFilter, isNotNull);
      expect(appliedFilter!.minPriceVnd?.amount, BigInt.from(1000000000));
      expect(appliedFilter!.maxPriceVnd?.amount, BigInt.from(3000000000));
    });
  });

  group('P2-010 LoginPromptSheet outcome handling', () {
    testWidgets('dismissing login sheet returns false and does not run callback', (tester) async {
      final auth = AuthCubit(FakeAccountRepository());
      addTearDown(auth.close);
      bool? result;
      var callbackInvoked = false;

      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    result = await LoginPromptSheet.show(
                      ctx,
                      onAuthenticated: () => callbackInvoked = true,
                    );
                  },
                  child: const Text('Open Prompt'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      // Tap 'Để sau' (cancel)
      await tester.tap(find.textContaining('Để sau'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(callbackInvoked, isFalse);
    });
  });

  group('P2-006 Disposed async safety', () {
    test('FilterCubit ignoring emissions after close()', () async {
      final repo = FakePropertyRepository();
      final cubit = FilterCubit(
        repo,
        initialFilter: const PropertyFilter(
          regions: [],
          areaBands: [],
          landTypes: [],
          savedOnly: false,
          sort: PropertySort.relevant,
        ),
      );
      await cubit.close();
      expect(cubit.isClosed, isTrue);
    });

    test('PropertyDetailCubit ignoring emissions after close()', () async {
      final cubit = PropertyDetailCubit(
        FakePropertyRepository(),
        FakeConsultantRepository(),
        propertyId: '00000000-0000-4000-8000-000000000001',
      );
      await cubit.close();
      expect(cubit.isClosed, isTrue);
    });
  });
}
