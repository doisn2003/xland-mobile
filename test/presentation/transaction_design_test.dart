import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:xland_mobile/presentation/app/xland_app.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/pages/login_page.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/features/transactions/widgets/transaction_nft_hero.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

class _BrokenAnimationBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == 'assets/animations/xland-nft.json') {
      return Future.error(FlutterError('Animation unavailable'));
    }
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Decode the actual supplied vector asset, rather than a substitute image.
    final composition = await AssetLottie('assets/animations/xland-nft.json')
        .load();
    expect(composition.duration, const Duration(seconds: 8));
    expect(composition.images, isEmpty);
    final fonts = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      File(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await icons.load();
  });

  Future<GlobalKey> mountShell(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    int tab = 2,
    bool reducedMotion = true,
    double topInset = 0,
  }) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: topInset);
    tester.view.viewPadding = FakeViewPadding(top: topInset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reducedMotion);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final deps = createFakeDependencies();
    final auth = AuthCubit(deps.account);
    addTearDown(auth.close);
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: deps,
        child: BlocProvider.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            navigatorObservers: [XLandApp.routeObserver],
            builder: (context, child) =>
                RepaintBoundary(key: captureKey, child: child!),
            home: MainNavigationShell(initialIndex: tab),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return captureKey;
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final directory = Platform.environment['TRANSACTION_DESIGN_EVIDENCE'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Finder transactionsScroll() =>
      find.byKey(const PageStorageKey('transactions-scroll'));
  Finder animation({bool skipOffstage = true}) =>
      find.byType(LottieBuilder, skipOffstage: skipOffstage);

  testWidgets('artwork fills the status area and history keeps safe controls', (
    tester,
  ) async {
    final key = await mountShell(tester, topInset: 44);
    await tester.pumpAndSettle();
    final hero = find.byType(TransactionNftHero);
    expect(tester.getTopLeft(hero).dy, 0);
    expect(tester.getTopLeft(animation()).dy, 0);
    SystemUiOverlayStyle overlay() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        )
        .value;
    expect(overlay().statusBarColor, Colors.transparent);
    expect(overlay().statusBarIconBrightness, Brightness.light);
    expect(overlay().systemStatusBarContrastEnforced, isFalse);
    await capture(tester, key, 'transactions-edge-to-edge');

    await tester.tap(
      find.descendant(
        of: find.byType(XLandBottomNavBar),
        matching: find.text('Tôi'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Tài khoản của tôi')).dy,
      greaterThanOrEqualTo(44),
    );
    final entry = find.widgetWithText(ListTile, 'Lịch sử đặt lịch thực địa');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Lịch sử đặt lịch thực địa')).dy,
      greaterThanOrEqualTo(44),
    );
    expect(find.text('Đăng nhập ngay').hitTestable(), findsOneWidget);
    expect(overlay().statusBarIconBrightness, Brightness.dark);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'transactions-history-status-inset');
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'transaction design $width x $scale and history below artwork',
        (tester) async {
          final key = await mountShell(tester, width: width, scale: scale);
          await tester.pumpAndSettle();
          final hero = find.byType(TransactionNftHero);
          final heading = find.text('Lịch sử đặt lịch thực địa');
          expect(
            tester.getTopLeft(heading).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(hero).dy),
          );
          expect(find.text('Tính năng sắp ra mắt'), findsOneWidget);
          expect(
            find.descendant(of: hero, matching: find.byType(ButtonStyleButton)),
            findsNothing,
          );
          expect(tester.widget<LottieBuilder>(animation()).animate, isFalse);
          expect(tester.takeException(), isNull);
          await capture(tester, key, 'transactions-${width.toInt()}-$scale');

          await tester.drag(transactionsScroll(), const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(find.text('Đăng nhập ngay').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            key,
            'transactions-history-${width.toInt()}-$scale',
          );
        },
      );
    }
  }

  testWidgets(
    'account utilities open the existing history and retain guest login gate',
    (tester) async {
      final key = await mountShell(tester, tab: 3);
      await tester.pumpAndSettle();
      final entry = find.widgetWithText(ListTile, 'Lịch sử đặt lịch thực địa');
      expect(entry, findsOneWidget);
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await capture(tester, key, 'account-utilities');
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
        find.text('Lịch sử đặt lịch thực địa').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Đăng nhập ngay').hitTestable(), findsOneWidget);
      expect(find.text('Tài khoản khách'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Lịch sử đặt lịch thực địa')).dy,
        lessThan(40),
      );
      expect(tester.widget<LottieBuilder>(animation()).animate, isFalse);
      expect(find.text('Đã cọc 350.000 đ'), findsNothing);
      await capture(tester, key, 'account-open-history');
      await tester.tap(find.text('Đăng nhập ngay'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  testWidgets(
    'asset error keeps the poster and upcoming notice without actions',
    (tester) async {
      Lottie.cache.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _BrokenAnimationBundle(),
            child: const Scaffold(body: TransactionNftHero(active: false)),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/animations/xland-nft-poster.png'),
          tester.element(find.byType(TransactionNftHero)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Tính năng sắp ra mắt'), findsOneWidget);
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'animation follows tab, app lifecycle, covered routes and reduced motion',
    (tester) async {
      await mountShell(tester, reducedMotion: false);
      expect(tester.widget<LottieBuilder>(animation()).animate, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.widget<LottieBuilder>(animation()).animate, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.widget<LottieBuilder>(animation()).animate, isTrue);

      final navigator = Navigator.of(
        tester.element(find.byType(MainNavigationShell)),
      );
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<LottieBuilder>(animation(skipOffstage: false)).animate,
        isFalse,
      );
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<LottieBuilder>(animation()).animate, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byType(XLandBottomNavBar),
          matching: find.text('Tôi'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<LottieBuilder>(animation(skipOffstage: false)).animate,
        isFalse,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(XLandBottomNavBar),
          matching: find.text('Giao dịch'),
        ),
      );
      await tester.pump();
      expect(tester.widget<LottieBuilder>(animation()).animate, isTrue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      expect(tester.widget<LottieBuilder>(animation()).animate, isFalse);
    },
  );
}
