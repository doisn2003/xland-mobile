import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/widgets/login_prompt_sheet.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_sheet.dart';
import 'package:xland_mobile/presentation/features/consultant/pages/consultant_profile_page.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/property_filter_sheet.dart';
import 'package:xland_mobile/presentation/features/events/pages/event_detail_page.dart';
import 'package:xland_mobile/presentation/features/feed/widgets/comments_sheet.dart';
import 'package:xland_mobile/presentation/features/property_detail/widgets/finance_plan_tab.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'fakes/fake_xland_dependencies.dart';

const _phone = Size(390, 850);
const _button = ValueKey('safe-control');
const _cases = [
  (
    name: 'no navigation inset',
    size: _phone,
    padding: EdgeInsets.only(top: 28),
    keyboard: 0.0,
  ),
  (
    name: 'gesture navigation',
    size: _phone,
    padding: EdgeInsets.only(top: 28, bottom: 24),
    keyboard: 0.0,
  ),
  (
    name: 'three-button navigation',
    size: _phone,
    padding: EdgeInsets.only(top: 28, bottom: 48),
    keyboard: 0.0,
  ),
  (
    name: 'landscape side navigation',
    size: Size(850, 390),
    padding: EdgeInsets.only(left: 24, right: 48),
    keyboard: 0.0,
  ),
  (
    name: 'keyboard and three-button navigation',
    size: _phone,
    padding: EdgeInsets.only(top: 28, bottom: 48),
    keyboard: 320.0,
  ),
];

void main() {
  setUpAll(() async {
    final font = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await font.load();
  });

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home, Size size, EdgeInsets padding, double keyboard) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: keyboard > 0 ? padding.copyWith(bottom: 0) : padding,
            viewPadding: padding,
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: home,
      );

  void expectProtected(
    WidgetTester tester,
    Finder finder,
    Size size,
    EdgeInsets padding,
    double keyboard,
  ) {
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(padding.left));
    expect(rect.right, lessThanOrEqualTo(size.width - padding.right));
    expect(rect.top, greaterThanOrEqualTo(padding.top));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        size.height - (keyboard > 0 ? keyboard : padding.bottom),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  for (final scenario in _cases) {
    testWidgets('sheet consumes system padding once: ${scenario.name}', (
      tester,
    ) async {
      viewport(tester, scenario.size);
      String? result;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showXLandBottomSheet<String>(
                    context: context,
                    builder: (context) {
                      expect(MediaQuery.paddingOf(context), EdgeInsets.zero);
                      expect(MediaQuery.viewInsetsOf(context), EdgeInsets.zero);
                      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
                      return Container(
                        height: 300 + keyboard,
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboard),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ElevatedButton(
                            key: _button,
                            onPressed: () => Navigator.pop(context, 'done'),
                            child: const Text('Continue'),
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
          scenario.size,
          scenario.padding,
          scenario.keyboard,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expectProtected(
        tester,
        find.byKey(_button),
        scenario.size,
        scenario.padding,
        scenario.keyboard,
      );
      expect(
        tester.getBottomLeft(find.byKey(_button)).dy,
        closeTo(
          scenario.size.height -
              (scenario.keyboard > 0
                  ? scenario.keyboard
                  : scenario.padding.bottom) -
              16,
          .01,
        ),
      );
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(result, 'done');
    });

    for (final footer in [false, true]) {
      testWidgets(
        'scaffold protects ${footer ? 'custom footer' : 'navigation bar'}: ${scenario.name}',
        (tester) async {
          viewport(tester, scenario.size);
          const control = SizedBox(
            key: _button,
            height: 56,
            width: double.infinity,
            child: ColoredBox(color: Colors.green),
          );
          await tester.pumpWidget(
            app(
              XLandScaffold(
                stickyFooter: footer ? control : null,
                bottomNavigationBar: footer ? null : control,
                body: const SizedBox.expand(),
              ),
              scenario.size,
              scenario.padding,
              scenario.keyboard,
            ),
          );
          await tester.pumpAndSettle();
          // Scaffold keeps the navigation bar below the keyboard; its footer
          // follows the resized body above the keyboard.
          final keyboard = footer ? scenario.keyboard : 0.0;
          expectProtected(
            tester,
            find.byKey(_button),
            scenario.size,
            scenario.padding,
            keyboard,
          );
          expect(
            tester.getBottomLeft(find.byKey(_button)).dy,
            closeTo(
              scenario.size.height -
                  (keyboard > 0 ? keyboard : scenario.padding.bottom),
              .01,
            ),
          );
        },
      );
    }
  }

  for (final keyboard in [0.0, 320.0]) {
    for (final screen in [
      'booking',
      'filter',
      'login',
      'comments',
      'event',
      'consultant',
      'finance',
    ]) {
      testWidgets(
        '$screen sheet clears Android navigation${keyboard > 0 ? ' and keyboard' : ''}',
        (tester) async {
          viewport(tester, _phone);
          final deps = createFakeDependencies();
          await deps.account.signIn(
            const SignInInput(username: 'owner_a', password: 'review_password'),
          );
          final auth = AuthCubit(deps.account);
          await auth.checkSession();
          addTearDown(auth.close);
          final launcher = Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  switch (screen) {
                    case 'booking':
                      BookingSheet.show(
                        context,
                        propertyId: FakePropertyRepository.sampleProperty.id,
                        property: FakePropertyRepository.sampleProperty,
                      );
                    case 'filter':
                      PropertyFilterSheet.show(
                        context,
                        propertyRepository: deps.properties,
                        currentFilter: const PropertyFilter(
                          regions: [],
                          areaBands: [],
                          landTypes: [],
                          savedOnly: false,
                          sort: PropertySort.relevant,
                        ),
                      );
                    case 'login':
                      LoginPromptSheet.show(context);
                    case 'comments':
                      CommentsSheet.show(context, videoId: 'feed-001');
                  }
                },
                child: const Text('Open'),
              ),
            ),
          );
          final home = switch (screen) {
            'event' => const EventDetailPage(eventId: 'ev-001'),
            'consultant' => const ConsultantProfilePage(
              consultantId: '00000000-0000-4000-8000-000000000030',
            ),
            'finance' => XLandScaffold(
              body: FinancePlanTab(
                property: FakePropertyRepository.sampleProperty,
              ),
            ),
            _ => launcher,
          };
          await tester.pumpWidget(
            DependenciesScope(
              dependencies: deps,
              child: BlocProvider.value(
                value: auth,
                child: app(
                  home,
                  _phone,
                  const EdgeInsets.only(top: 28, bottom: 48),
                  keyboard,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final trigger = find.text(switch (screen) {
            'event' => 'Đăng ký tham dự',
            'consultant' => 'Hẹn tư vấn với Minh Anh',
            'finance' => 'Đăng ký tư vấn gói vay ngân hàng',
            _ => 'Open',
          });
          await tester.ensureVisible(trigger);
          await tester.pumpAndSettle();
          await tester.tap(trigger);
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          expect(sheet, findsOneWidget);
          final control = screen == 'comments'
              ? find.descendant(of: sheet, matching: find.byType(TextField))
              : find
                    .descendant(
                      of: sheet,
                      matching: screen == 'login'
                          ? find.byType(OutlineButton)
                          : find.byType(PrimaryButton),
                    )
                    .last;
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          expectProtected(
            tester,
            control,
            _phone,
            const EdgeInsets.only(top: 28, bottom: 48),
            keyboard,
          );
        },
      );
    }
  }
}
