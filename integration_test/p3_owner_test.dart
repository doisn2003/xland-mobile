// Prepared during W0; NEVER run before A/T0. Native private input only, no defines with credentials.
// These are C repository/transport integration assertions, not B UI acceptance.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:xland_mobile/data/datasources/local/secure_session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import 'support/trace_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('XLAND_P3_AFTER_T0');
  final client = TraceClient(http.Client());
  var ownsSession = false;
  const sessions = SecureSessionStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'xland-p3-w1-canary'),
    ),
  );
  late Map<String, Object?> input;
  late RemoteGateway g;
  late RemoteAccountRepository account;
  String value(String key) => input[key]! as String;
  Future<Session> login(String owner) async {
    final session = await account.signIn(
      SignInInput(
        username: value('username$owner'),
        password: value('password$owner'),
      ),
    );
    ownsSession = true;
    return session;
  }

  Matcher code(FailureCode c) =>
      isA<XlandFailure>().having((e) => e.code, 'code', c);
  setUpAll(() async {
    if (!enabled) return;
    input = jsonDecode(
      await File(
        '/data/user/0/vn.xland.xland_mobile.cproof/files/p3-w1-input.json',
      ).readAsString(),
    ) as Map<String, Object?>;
    if (input['t0Authorized'] != true ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(value('t0ReviewSha256'))) {
      throw StateError('A/T0 authorization and exact review hash required');
    }
    if (!value('runLabel').startsWith('c-p3-')) {
      throw StateError('Own fixture label required');
    }
    g = RemoteGateway(
      HttpApiTransport(
        baseUrl: Uri.parse(value('apiBaseUrl')),
        client: client,
        sessions: sessions,
        allowLocalHttp: true,
      ),
    );
    account = RemoteAccountRepository(g, sessions);
    if (await sessions.readAccessToken() != null) {
      throw StateError('Canary namespace already occupied; inspect owner');
    }
  });
  tearDownAll(() async {
    if (enabled && ownsSession && await sessions.readAccessToken() != null) {
      await account.signOut();
    }
    IntegrationTestWidgetsFlutterBinding.instance.reportData = {
      'http': client.records,
    };
    client.close();
  });
  testWidgets(
    'E03/C: one booking, same-key replay, pending/unpaid and owner readback',
    (_) async {
      await login('A');
      final bookings = RemoteBookingRepository(g);
      final request = BookingInput(
        propertyId: value('propertyId'),
        slotId: value('slotId'),
        attendeeCount: 1,
        transportMode: TransportMode.selfArranged,
        requestDocuments: false,
        requestLoanAdvice: false,
        contactName: 'DEMO C P3',
        contactPhone: value('contactPhone'),
        note: value('runLabel'),
      );
      final first = await bookings.create(
        request,
        idempotencyKey: '${value('runLabel')}-booking',
      );
      expect(
        (await bookings.create(
          request,
          idempotencyKey: '${value('runLabel')}-booking',
        )).id,
        first.id,
      );
      expect(first.status, BookingStatus.awaitingDeposit);
      expect(first.paymentStatus, PaymentStatus.unpaid);
      expect((await bookings.getBooking(first.id)).slotId, value('slotId'));
      expect(
        (await bookings.getHistory(const PageQuery(limit: 50))).items
            .any((b) => b.id == first.id),
        isTrue,
      );
      await account.signOut();
    },
    skip: !enabled,
  );
  testWidgets(
    'E04/C: owner switch denies other booking and guest private read',
    (_) async {
      await login('A');
      final bookings = RemoteBookingRepository(g);
      final mine = (await bookings.getHistory(const PageQuery(limit: 50)))
          .items;
      expect(mine, isNotEmpty);
      await account.signOut();
      await login('B');
      await expectLater(
        bookings.getBooking(mine.first.id),
        throwsA(code(FailureCode.notFound)),
      );
      expect(
        (await bookings.getHistory(const PageQuery(limit: 50))).items
            .any((b) => mine.any((a) => a.id == b.id)),
        isFalse,
      );
      await account.signOut();
      await expectLater(
        bookings.getHistory(const PageQuery()),
        throwsA(code(FailureCode.unauthenticated)),
      );
    },
    skip: !enabled,
  );
  testWidgets('E05/C: independent saved property/video and comment retry', (
    _,
  ) async {
    await login('A');
    final feed = RemoteFeedRepository(g),
        properties = RemotePropertyRepository(g);
    await properties.setSaved(value('propertyId'), true);
    await feed.setSaved(value('videoId'), true);
    expect(
      (await feed.getSavedVideos(const PageQuery(limit: 50))).items
          .any((v) => v.id == value('videoId')),
      isTrue,
    );
    await feed.setSaved(value('videoId'), false);
    expect((await properties.getProperty(value('propertyId'))).isSaved, isTrue);
    final a = await feed.addComment(
      value('videoId'),
      'DEMO ${value('runLabel')}',
      idempotencyKey: '${value('runLabel')}-comment',
    );
    final b = await feed.addComment(
      value('videoId'),
      'DEMO ${value('runLabel')}',
      idempotencyKey: '${value('runLabel')}-comment',
    );
    expect(b.id, a.id);
    await account.signOut();
  }, skip: !enabled);
  testWidgets(
    'E06/C: profile set/keep/clear and settings survive session reopen',
    (_) async {
      await login('A');
      await account.updateProfile(
        ProfileUpdate(
          displayName: 'DEMO ${value('runLabel')}',
          contactPhone: value('contactPhone'),
        ),
      );
      await account.updateProfile(
        const ProfileUpdate(displayName: 'DEMO C P3'),
      );
      expect((await account.getProfile()).contactPhone, value('contactPhone'));
      await account.updateProfile(const ProfileUpdate(clearContactPhone: true));
      await account.updateSettings(
        const SettingsUpdate(feedAutoplay: false, feedMutedByDefault: true),
      );
      await account.signOut();
      await login('A');
      expect((await account.getProfile()).contactPhone, isNull);
      expect((await account.getProfile()).contactVerified, isFalse);
      expect((await account.getSettings()).feedAutoplay, isFalse);
      await account.signOut();
    },
    skip: !enabled,
  );
  testWidgets('E08/C: own event replay/history and support consent gate', (
    _,
  ) async {
    await login('A');
    final events = RemoteEventRepository(g);
    final event = await events.getEvent(value('eventId'));
    expect(event.startsAt.isAfter(DateTime.now().toUtc()), isTrue);
    expect(event.remainingSlots, greaterThan(0));
    await events.setSaved(event.id, true);
    expect(
      (await events.getSavedEvents(const PageQuery(limit: 50))).items
          .any((e) => e.id == event.id),
      isTrue,
    );
    final request = EventRegistrationInput(
      eventId: event.id,
      contactName: 'DEMO C P3',
      contactPhone: value('contactPhone'),
      attendeeCount: 1,
    );
    final key = '${value('runLabel')}-event';
    final a = await events.register(request, idempotencyKey: key);
    expect((await events.register(request, idempotencyKey: key)).id, a.id);
    expect(a.ticketPriceVnd.wireValue, event.ticketPriceVnd.wireValue);
    expect(a.paymentMode, PaymentMode.disabled);
    expect(
      (await events.getRegistrations(const PageQuery(limit: 50))).items
          .any((r) => r.id == a.id),
      isTrue,
    );
    await expectLater(
      RemoteSupportRepository(g).submit(
        SupportRequestInput(
          kind: SupportKind.legalReview,
          propertyId: value('propertyId'),
          message: 'DEMO ${value('runLabel')}',
          contactName: 'DEMO C P3',
          contactPhone: value('contactPhone'),
          consentToShareContact: false,
        ),
        idempotencyKey: '${value('runLabel')}-no-consent',
      ),
      throwsA(code(FailureCode.invalidInput)),
    );
    await account.signOut();
  }, skip: !enabled);
  testWidgets('E07/C: exact VND two methods, save replay and history delete', (
    _,
  ) async {
    await login('A');
    final finance = RemoteFinanceRepository(g);
    for (final method in RepaymentMethod.values) {
      final request = FinanceInput(
        propertyId: value('financePropertyId'),
        equityVnd: Vnd('1200000000'),
        loanVnd: Vnd('1200000000'),
        termMonths: 240,
        annualRatePercent: DecimalValue('9'),
        method: method,
      );
      final result = await finance.calculate(request);
      expect(
        result.monthlyPaymentVnd.wireValue,
        method == RepaymentMethod.equalInstallment ? '10796711' : '14000000',
      );
      final key = '${value('runLabel')}-finance-${method.name}';
      final a = await finance.savePlan(
        'DEMO ${value('runLabel')}',
        request,
        idempotencyKey: key,
      );
      expect(
        (await finance.savePlan(
          'DEMO ${value('runLabel')}',
          request,
          idempotencyKey: key,
        )).id,
        a.id,
      );
      expect(
        (await finance.getPlans(const PageQuery(limit: 50))).items
            .any((p) => p.id == a.id),
        isTrue,
      );
      await finance.deletePlan(a.id);
      expect(
        (await finance.getPlans(const PageQuery(limit: 50))).items
            .any((p) => p.id == a.id),
        isFalse,
      );
    }
    await account.signOut();
  }, skip: !enabled);
}
