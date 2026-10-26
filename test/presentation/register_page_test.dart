import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_state.dart';
import 'package:xland_mobile/presentation/features/auth/pages/register_page.dart';
import 'package:xland_mobile/presentation/features/auth/widgets/extended_auth_panel.dart';
import 'package:xland_mobile/presentation/shared/widgets/icons/google_logo.dart';
import 'package:xland_mobile/presentation/shared/widgets/inputs.dart';

import 'fakes/fake_xland_dependencies.dart';

void main() {
  testWidgets('RegisterPage renders all fields and submits valid form', (tester) async {
    final cubit = AuthCubit(FakeAccountRepository());
    addTearDown(cubit.close);

    var successCalled = false;
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: RegisterPage(
            onSuccess: () => successCalled = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký tài khoản XLand'), findsOneWidget);
    expect(find.text('Tạo tài khoản nhanh chóng, không cần xác minh'), findsOneWidget);
    expect(find.byType(XLandTextField), findsNWidgets(3));
    expect(find.text('Đăng ký tài khoản'), findsOneWidget);
    expect(find.text('Đã có tài khoản? Đăng nhập'), findsOneWidget);

    // Try submit empty
    await tester.tap(find.text('Đăng ký tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập đầy đủ thông tin đăng ký.'), findsOneWidget);

    // Enter mismatching passwords
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'newuser123');
    await tester.enterText(textFields.at(1), 'password123');
    await tester.enterText(textFields.at(2), 'password999');
    await tester.ensureVisible(find.text('Đăng ký tài khoản'));
    await tester.tap(find.text('Đăng ký tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu xác nhận không trùng khớp.'), findsOneWidget);

    // Enter matching passwords and submit
    await tester.enterText(textFields.at(2), 'password123');
    await tester.ensureVisible(find.text('Đăng ký tài khoản'));
    await tester.tap(find.text('Đăng ký tài khoản'));
    await tester.pumpAndSettle();

    expect(cubit.state, isA<AuthAuthenticated>());
    expect(successCalled, isTrue);
  });

  testWidgets('ExtendedAuthPanel shows Google logo and navigates to RegisterPage', (tester) async {
    final cubit = AuthCubit(FakeAccountRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(
            body: ExtendedAuthPanel(
              isLoading: false,
              onSuccess: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check Google logo widget is present
    expect(find.byType(GoogleLogo), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsOneWidget);

    // Check register prompt and button
    expect(find.text('Bạn chưa có tài khoản? Hãy đăng ký ngay'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsOneWidget);

    // Tap "Đăng ký ngay" should open RegisterPage
    await tester.tap(find.text('Đăng ký ngay'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.text('Đăng ký tài khoản XLand'), findsOneWidget);
  });
}

void _noop() {}
