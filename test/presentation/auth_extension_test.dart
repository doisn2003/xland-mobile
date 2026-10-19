import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_state.dart';
import 'package:xland_mobile/presentation/features/auth/widgets/extended_auth_panel.dart';
import 'package:xland_mobile/presentation/features/auth/pages/login_page.dart';

import 'fakes/fake_xland_dependencies.dart';

Session owner(String id) => Session(
  profile: UserProfile(
    id: id,
    displayName: id,
    contactVerified: false,
    updatedAt: DateTime.now(),
  ),
  expiresAt: DateTime.now().add(const Duration(days: 1)),
);

class FakeExtended implements ExtendedAuthRepository {
  Completer<Session?>? google;
  final requests = <String>[];
  bool timeoutOnce = false;
  bool expired = false;
  int cancels = 0;
  @override
  Future<AuthCapabilities> capabilities() async =>
      const AuthCapabilities(google: true, phoneOtp: true);
  @override
  Future<Session?> signInWithGoogle() async => google?.future;
  @override
  Future<PhoneOtpChallenge> requestPhoneOtp(
    String phone,
    String requestKey,
  ) async {
    requests.add(requestKey);
    if (timeoutOnce) {
      timeoutOnce = false;
      throw const XlandFailure(
        code: FailureCode.timeout,
        message: 'Kết nối quá thời gian',
      );
    }
    return PhoneOtpChallenge(
      id: 'challenge',
      maskedPhone: '+84 ••• ••• 567',
      expiresAt: expired
          ? DateTime.now().subtract(const Duration(seconds: 1))
          : DateTime.now().add(const Duration(minutes: 5)),
      resendAt: DateTime.now().add(const Duration(seconds: 60)),
      deliveryStatus: OtpDeliveryStatus.accepted,
    );
  }

  @override
  Future<Session> signInWithPhoneOtp(String challengeId, String code) async =>
      owner('phone-owner');
  @override
  void cancelPendingSignIn() {
    cancels++;
  }
}

void main() {
  testWidgets(
    'leaving login cancels pending Google and ignores its late success',
    (tester) async {
      final repository = FakeExtended()..google = Completer<Session?>();
      final cubit = AuthCubit(
        FakeAccountRepository(),
        extendedAuth: repository,
      );
      addTearDown(cubit.close);
      var successes = 0;
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LoginPage(onSuccess: () => successes++),
                  ),
                ),
                child: const Text('Open login'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open login'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiếp tục với Google'));
      await tester.tap(find.text('Tiếp tục với Google'));
      await tester.pump();
      expect(cubit.state, isA<AuthLoading>());
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      repository.google!.complete(owner('late'));
      await tester.pumpAndSettle();
      expect(successes, 0);
      expect(cubit.state, isA<AuthGuest>());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'phone form fits 360px at text scale 1.3 and shows expired code state',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = AuthCubit(
        FakeAccountRepository(),
        extendedAuth: FakeExtended()..expired = true,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExtendedAuthPanel(isLoading: false, onSuccess: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Đăng ký / đăng nhập bằng số điện thoại'),
      );
      await tester.tap(find.text('Đăng ký / đăng nhập bằng số điện thoại'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '0981234567');
      await tester.ensureVisible(find.text('Nhận mã OTP'));
      await tester.tap(find.text('Nhận mã OTP'));
      await tester.pumpAndSettle();
      expect(find.text('Mã đã hết hạn. Hãy yêu cầu mã mới.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'dismissed Google chooser returns to guest without auth error',
    () async {
      final repository = FakeExtended();
      final cubit = AuthCubit(
        FakeAccountRepository(),
        extendedAuth: repository,
      );
      addTearDown(cubit.close);
      expect(await cubit.signInWithGoogle(), false);
      expect(cubit.state, isA<AuthGuest>());
    },
  );
  test(
    'logout/cancel suppress a late Google result and preserve new auth owner',
    () async {
      final repository = FakeExtended()..google = Completer<Session?>();
      final cubit = AuthCubit(
        FakeAccountRepository(),
        extendedAuth: repository,
      );
      addTearDown(cubit.close);
      final pending = cubit.signInWithGoogle();
      await cubit.signOut();
      repository.google!.complete(owner('old-google'));
      expect(await pending, false);
      expect(cubit.state, isA<AuthGuest>());
      expect(repository.cancels, greaterThan(0));
    },
  );
  testWidgets(
    'unconfigured methods show unavailable and cannot invoke a provider',
    (tester) async {
      final cubit = AuthCubit(FakeAccountRepository());
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(
              body: ExtendedAuthPanel(
                isLoading: false,
                onSuccess: () => fail('Disabled provider invoked'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Đăng nhập Google chưa sẵn sàng trên thiết bị này.'),
        findsOneWidget,
      );
      expect(
        find.text('Đăng nhập số điện thoại chưa sẵn sàng.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tiếp tục với Google'));
      await tester.pump();
      expect(cubit.state, isA<AuthInitial>());
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'OTP timeout retry reuses key; cooldown blocks resend and six-digit validation is visible',
    (tester) async {
      final repository = FakeExtended()..timeoutOnce = true;
      final cubit = AuthCubit(
        FakeAccountRepository(),
        extendedAuth: repository,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExtendedAuthPanel(isLoading: false, onSuccess: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng ký / đăng nhập bằng số điện thoại'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '0981234567');
      await tester.ensureVisible(find.text('Nhận mã OTP'));
      await tester.tap(find.text('Nhận mã OTP'));
      await tester.pumpAndSettle();
      expect(find.text('Kết nối quá thời gian'), findsOneWidget);
      await tester.ensureVisible(find.text('Thử lại yêu cầu OTP'));
      await tester.tap(find.text('Thử lại yêu cầu OTP'));
      await tester.pumpAndSettle();
      expect(repository.requests.length, 2);
      expect(repository.requests[0], repository.requests[1]);
      expect(find.textContaining('Gửi lại sau'), findsOneWidget);
      await tester.ensureVisible(find.text('Xác minh và tiếp tục'));
      await tester.tap(find.text('Xác minh và tiếp tục'));
      await tester.pump();
      expect(find.text('Nhập mã OTP gồm 6 chữ số.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
