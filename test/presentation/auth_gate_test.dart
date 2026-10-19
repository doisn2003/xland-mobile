import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_state.dart';
import 'package:xland_mobile/presentation/features/auth/pages/login_page.dart';
import 'package:xland_mobile/presentation/features/auth/widgets/login_prompt_sheet.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'fakes/fake_xland_dependencies.dart';

Widget _buildAuthHarness({
  required XlandDependencies dependencies,
  required AuthCubit authCubit,
  Widget? child,
}) {
  return DependenciesScope(
    dependencies: dependencies,
    child: BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp(
        home: child ?? const LoginPage(),
      ),
    ),
  );
}

void main() {
  group('Auth Gate & Session Lifecycle (P2-B6)', () {
    testWidgets('LoginPage validates username (3..64) and password (8..128)', (tester) async {
      final dependencies = createFakeDependencies();
      final authCubit = AuthCubit(dependencies.account);

      await tester.pumpWidget(_buildAuthHarness(
        dependencies: dependencies,
        authCubit: authCubit,
      ));
      await tester.pumpAndSettle();

      // Enter short username
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'ab');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      // Expect validation error
      expect(find.text('Tên đăng nhập phải có từ 3 đến 64 ký tự.'), findsOneWidget);

      // Fix username, keep short password
      await tester.enterText(textFields.first, 'validuser');
      final loginBtn = find.widgetWithText(PrimaryButton, 'Đăng nhập');
      await tester.ensureVisible(loginBtn);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu phải có từ 8 đến 128 ký tự.'), findsOneWidget);
    });

    testWidgets('LoginPage performs successful sign in and updates AuthCubit state', (tester) async {
      final dependencies = createFakeDependencies();
      final authCubit = AuthCubit(dependencies.account);

      await tester.pumpWidget(_buildAuthHarness(
        dependencies: dependencies,
        authCubit: authCubit,
      ));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'investor_pro');
      await tester.enterText(textFields.last, 'Password@123');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(authCubit.state, isA<AuthAuthenticated>());
      final authState = authCubit.state as AuthAuthenticated;
      expect(authState.session.profile.displayName, isNotEmpty);
    });

    testWidgets('LoginPromptSheet invokes callback exactly once on login success (callbackCount == 1)', (tester) async {
      final dependencies = createFakeDependencies();
      final authCubit = AuthCubit(dependencies.account);
      int callbackCount = 0;

      await tester.pumpWidget(_buildAuthHarness(
        dependencies: dependencies,
        authCubit: authCubit,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  LoginPromptSheet.show(
                    context,
                    title: 'Lưu bất động sản',
                    message: 'Vui lòng đăng nhập để tiếp tục',
                    onAuthenticated: () {
                      callbackCount++;
                    },
                  );
                },
                child: const Text('Open Prompt'),
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open prompt
      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPromptSheet), findsOneWidget);

      // Tap "Đăng nhập ngay" -> pushes LoginPage
      await tester.tap(find.text('Đăng nhập ngay'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);

      // Perform sign in
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'user');
      await tester.enterText(textFields.last, 'password123');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      // Callback should have executed exactly once upon login return
      expect(callbackCount, equals(1));
      expect(authCubit.state, isA<AuthAuthenticated>());
    });

    testWidgets('LoginPromptSheet does not invoke callback when cancelled (callbackCount == 0)', (tester) async {
      final dependencies = createFakeDependencies();
      final authCubit = AuthCubit(dependencies.account);
      int callbackCount = 0;

      await tester.pumpWidget(_buildAuthHarness(
        dependencies: dependencies,
        authCubit: authCubit,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  LoginPromptSheet.show(
                    context,
                    title: 'Lưu bất động sản',
                    message: 'Vui lòng đăng nhập để tiếp tục',
                    onAuthenticated: () {
                      callbackCount++;
                    },
                  );
                },
                child: const Text('Open Prompt'),
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open prompt
      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPromptSheet), findsOneWidget);

      // Tap "Để sau" to cancel
      await tester.tap(find.textContaining('Để sau'));
      await tester.pumpAndSettle();

      // Callback should NOT be executed and user remains unauthenticated
      expect(callbackCount, equals(0));
      expect(authCubit.state, isNot(isA<AuthAuthenticated>()));
    });

    testWidgets('AuthCubit signOut transitions to AuthGuest', (tester) async {
      final dependencies = createFakeDependencies();
      final authCubit = AuthCubit(dependencies.account);

      // Sign in first
      await authCubit.signIn(username: 'user', password: 'password123');
      expect(authCubit.state, isA<AuthAuthenticated>());

      // Sign out
      await authCubit.signOut();
      expect(authCubit.state, isA<AuthGuest>());
    });
  });
}
