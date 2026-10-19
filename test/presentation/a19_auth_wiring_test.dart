import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/app/xland_app.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';

import 'fakes/fake_xland_dependencies.dart';
import 'auth_extension_test.dart' show FakeExtended;

void main() {
  testWidgets(
    'XLandApp injects the configured extension into the same AuthCubit used by shell',
    (tester) async {
      final base = createFakeDependencies(), extension = FakeExtended();
      final dependencies = XlandDependencies(
        properties: base.properties,
        feed: base.feed,
        consultants: base.consultants,
        events: base.events,
        bookings: base.bookings,
        payments: base.payments,
        account: base.account,
        clubs: base.clubs,
        finance: base.finance,
        support: base.support,
        guestPreferences: base.guestPreferences,
        extendedAuth: extension,
      );
      await tester.pumpWidget(XLandApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(MainNavigationShell));
      expect(context.read<AuthCubit>().extendedAuth, same(extension));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'legacy dependencies without an extension remain compatible with app boot',
    (tester) async {
      await tester.pumpWidget(XLandApp(dependencies: createFakeDependencies()));
      await tester.pumpAndSettle();
      expect(
        tester
            .element(find.byType(MainNavigationShell))
            .read<AuthCubit>()
            .extendedAuth,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
