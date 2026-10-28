import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/account/pages/edit_profile_page.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_state.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/theme/app_theme.dart';

import 'fakes/fake_xland_dependencies.dart';

class Account extends FakeAccountRepository {
  ProfileUpdate? submitted;
  bool fail = false;
  @override
  Future<UserProfile> updateProfile(ProfileUpdate input) async {
    submitted = input;
    if (fail) {
      throw const XlandFailure(
        code: FailureCode.upstreamUnavailable,
        message: 'Không thể tải ảnh lên',
      );
    }
    return super.updateProfile(input);
  }
}

class Picker extends ImagePicker {
  XFile? file;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => file;
}

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jS1cAAAAASUVORK5CYII=',
  );

  Future<AuthCubit> open(
    WidgetTester tester,
    Account account,
    Picker picker,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final deps = createFakeDependencies(accountRepo: account);
    final cubit = AuthCubit(account);
    await cubit.checkSession();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: deps,
        child: BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditProfilePage(imagePicker: picker),
                    ),
                  ),
                  child: const Text('Mở hồ sơ'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở hồ sơ'));
    await tester.pumpAndSettle();
    return cubit;
  }

  Future<Account> account() async {
    final result = Account();
    await result.signIn(
      const SignInInput(username: 'user', password: 'password123'),
    );
    return result;
  }

  testWidgets(
    'allows clearing every field and refreshes the authenticated profile',
    (tester) async {
      final repo = await account();
      await repo.updateProfile(
        ProfileUpdate(
          address: 'Địa chỉ cũ',
          avatarUrl: Uri.parse('https://example.test/old.png'),
        ),
      );
      final cubit = await open(tester, repo, Picker());
      expect(find.text('Địa chỉ cũ'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.tap(find.text('Xóa ảnh'));
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      final saved = await repo.getProfile();
      expect(saved.displayName, '');
      expect(saved.contactPhone, isNull);
      expect(saved.address, isNull);
      expect(saved.avatarUrl, isNull);
      expect((cubit.state as AuthAuthenticated).session.profile, same(saved));
      expect(find.text('Mở hồ sơ'), findsOneWidget);
    },
  );

  testWidgets('saves an unchanged profile and preserves contact verification', (
    tester,
  ) async {
    final repo = await account();
    await open(tester, repo, Picker());
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect((await repo.getProfile()).contactVerified, isTrue);
    expect(repo.submitted!.contactPhone, isNull);
    expect(repo.submitted!.clearContactPhone, isFalse);
  });

  testWidgets(
    'selects an image and retains edits and preview after a failed save',
    (tester) async {
      final repo = await account();
      final picker = Picker()..file = XFile.fromData(png, name: 'avatar.png');
      await open(tester, repo, picker);
      await tester.tap(find.text('Chọn ảnh đại diện'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), 'Địa chỉ mới');
      repo.fail = true;
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải ảnh lên'), findsOneWidget);
      expect(find.text('Địa chỉ mới'), findsOneWidget);
      expect(repo.submitted!.avatar!.bytes, png);
      expect(repo.submitted!.avatar!.mimeType, 'image/png');
      repo.fail = false;
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect((await repo.getProfile()).address, 'Địa chỉ mới');
      expect((await repo.getProfile()).avatarUrl, isNotNull);
    },
  );

  testWidgets(
    'canceling the picker keeps the profile; oversize and non-images are rejected',
    (tester) async {
      final repo = await account(), picker = Picker();
      await open(tester, repo, picker);
      await tester.tap(find.text('Chọn ảnh đại diện'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa ảnh'), findsNothing);
      picker.file = XFile.fromData(
        Uint8List(5 * 1024 * 1024 + 1),
        name: 'big.png',
      );
      await tester.tap(find.text('Chọn ảnh đại diện'));
      await tester.pumpAndSettle();
      expect(find.text('Ảnh đại diện tối đa 5 MB.'), findsOneWidget);
      picker.file = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'fake.png',
      );
      await tester.tap(find.text('Chọn ảnh đại diện'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng chọn ảnh JPG, PNG hoặc WebP.'),
        findsOneWidget,
      );
      expect(find.text('Xóa ảnh'), findsNothing);
    },
  );
}
