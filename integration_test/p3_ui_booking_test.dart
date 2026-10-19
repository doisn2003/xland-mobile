import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:xland_mobile/data/datasources/local/secure_session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_sheet.dart';
import 'package:xland_mobile/presentation/shared/di/dependencies_scope.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

import 'support/trace_client.dart';
import 'support/private_input.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('XLAND_P3_AFTER_T0');
  testWidgets('E03/UI real login returns to review0POST then reconfirm1POST', (
    tester,
  ) async {
    final input = await readW1Input();
    if (input['t0Authorized'] != true) throw StateError('A/T0 required');
    String v(String key) => input[key]! as String;
    final client = TraceClient(http.Client());
    final sessions = SecureSessionStore(
      FlutterSecureStorage(
        aOptions: AndroidOptions(storageNamespace: 'xland-p3-ui-canary'),
      ),
    );
    if (await sessions.readAccessToken() != null) {
      throw StateError('Preserve unexpected UI canary session');
    }
    final g = RemoteGateway(
      HttpApiTransport(
        baseUrl: Uri.parse(v('apiBaseUrl')),
        client: client,
        sessions: sessions,
        allowLocalHttp: true,
      ),
    );
    final account = RemoteAccountRepository(g, sessions);
    final deps = XlandDependencies(
      properties: RemotePropertyRepository(g),
      account: account,
      feed: RemoteFeedRepository(g),
      consultants: RemoteConsultantRepository(g),
      events: RemoteEventRepository(g),
      bookings: RemoteBookingRepository(g),
      payments: RemotePaymentRepository(g),
      clubs: RemoteClubRepository(g),
      finance: RemoteFinanceRepository(g),
      support: RemoteSupportRepository(g),
    );
    final auth = AuthCubit(account);
    final checkpoints = <Map<String, Object?>>[];
    int posts() => client.records
        .where((r) => r['method'] == 'POST' && r['path'] == '/api/v1/bookings')
        .length;
    Future<void> settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 40),
    );
    Future<void> tap(String text) async {
      final f = find.text(text);
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle();
    }

    try {
      tester.view.physicalSize = const Size(800, 1500);
      tester.view.devicePixelRatio = 1;
      await auth.checkSession();
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(body: BookingSheet(propertyId: v('propertyId'))),
            ),
          ),
        ),
      );
      await settle();
      final slot = find.textContaining(v('slotLabel'));
      expect(slot, findsOneWidget);
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await settle();
      final fields = find.descendant(
        of: find.byType(BookingSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'DEMO C W1 UI');
      await tester.enterText(fields.at(1), v('contactPhone'));
      await tap('Xem lại thông tin đặt lịch');
      expect(posts(), 0);
      checkpoints.add({'stage': 'guest_review', 'bookingPosts': posts()});
      await tap('Xác nhận đặt lịch');
      expect(posts(), 0);
      await tap('Đăng nhập ngay');
      final loginFields = find.byType(TextField);
      await tester.enterText(loginFields.first, v('usernameA'));
      await tester.enterText(loginFields.last, v('passwordA'));
      final submit = find.widgetWithText(PrimaryButton, 'Đăng nhập');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await settle();
      expect(find.text('Xác nhận thông tin đặt lịch'), findsOneWidget);
      expect(posts(), 0);
      checkpoints.add({
        'stage': 'after_real_login_review',
        'bookingPosts': posts(),
      });
      await tap('Xác nhận đặt lịch');
      expect(posts(), 1);
      expect(find.text('Đặt lịch thực địa thành công!'), findsOneWidget);
      checkpoints.add({
        'stage': 'after_explicit_reconfirm',
        'bookingPosts': posts(),
      });
      final history = await deps.bookings.getHistory(
        const PageQuery(limit: 50),
      );
      final booking = history.items.singleWhere(
        (b) => b.contactName == 'DEMO C W1 UI' && b.slotId == v('slotId'),
      );
      expect(booking.status, BookingStatus.awaitingDeposit);
      expect(booking.paymentStatus, PaymentStatus.unpaid);
      expect((await deps.bookings.getBooking(booking.id)).id, booking.id);
      checkpoints.add({
        'bookingId': booking.id,
        'status': booking.status.name,
        'payment': booking.paymentStatus.name,
      });
    } finally {
      if (await sessions.readAccessToken() != null) await account.signOut();
      await writeW1Report({
        'stage': input['stage'],
        'checkpoints': checkpoints,
        'http': client.records,
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await auth.close();
      client.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  }, skip: !enabled);
}
