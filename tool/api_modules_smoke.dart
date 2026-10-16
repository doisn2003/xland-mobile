import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class _TestSession implements SessionStore {
  String? _token;
  @override
  Future<String?> readAccessToken() async => _token;
  @override
  Future<void> saveAccessToken({required String accessToken}) async {
    _token = accessToken;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

void check(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

Future<void> gated(Future<Object?> action, FailureCode code) async {
  try {
    await action;
  } on XlandFailure catch (failure) {
    check(failure.code == code, 'Unexpected failure code');
    return;
  }
  throw StateError('Expected explicit gate');
}

Future<void> main() async {
  final config = jsonDecode(
    File('../xland-server/.local/dart-http-context.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final base = Uri.parse(config['baseUrl'] as String);
  check(
    config['environment'] == 'isolated-local-test' && base.host == '127.0.0.1',
    'Refuse nonisolated test context',
  );
  final client = http.Client();
  final sessions = _TestSession();
  final g = RemoteGateway(
    HttpApiTransport(
      baseUrl: base,
      client: client,
      sessions: sessions,
      allowLocalHttp: true,
    ),
  );
  final account = RemoteAccountRepository(g, sessions);
  final properties = RemotePropertyRepository(g);
  final feed = RemoteFeedRepository(g);
  final consultants = RemoteConsultantRepository(g);
  final events = RemoteEventRepository(g);
  final bookings = RemoteBookingRepository(g);
  final payments = RemotePaymentRepository(g);
  final clubs = RemoteClubRepository(g);
  final support = RemoteSupportRepository(g);
  final finance = RemoteFinanceRepository(g);
  try {
    final credentials = config['account'] as Map<String, dynamic>;
    await account.signIn(
      SignInInput(
        username: credentials['username'] as String,
        password: credentials['password'] as String,
      ),
    );
    check(await account.getSession() != null, 'Session mapper');
    final updated = await account.updateProfile(
      const ProfileUpdate(
        displayName: 'Người kiểm thử Dart',
        contactPhone: '0912345678',
      ),
    );
    check(
      updated.contactPhone == '+84912345678' && !updated.contactVerified,
      'Profile/contact mapper',
    );
    final cleared = await account.updateProfile(
      const ProfileUpdate(clearContactPhone: true),
    );
    check(cleared.contactPhone == null, 'C-4 explicit profile clear');
    await account.updateSettings(
      const SettingsUpdate(
        notificationConsent: true,
        feedAutoplay: true,
        feedMutedByDefault: false,
      ),
    );
    check(
      (await account.getSettings()).notificationConsent,
      'Persisted settings',
    );
    final list = await properties.search(
      const PropertyFilter(
        regions: [],
        areaBands: [],
        landTypes: [],
        savedOnly: false,
        sort: PropertySort.relevant,
      ),
      const PageQuery(),
    );
    final property = list.page.items.firstWhere((p) => p.code == 'XL-028');
    final videos = await feed.getFeed(const PageQuery(limit: 2));
    final video = videos.items.firstWhere(
      (v) => v.propertyId == property.id,
      orElse: () => videos.items.first,
    );
    check(
      video.media.url == null && video.publishedAt.isUtc,
      'Nullable media/time mapper',
    );
    await feed.setLiked(video.id, true);
    check((await feed.getVideo(video.id)).isLiked, 'Persisted like');
    await feed.setSaved(video.id, true);
    check(
      (await feed.getSavedVideos(const PageQuery())).items.length == 1,
      'Saved video',
    );
    await feed.setFollowing(video.author.id, true);
    check(
      (await feed.getFollowing(const PageQuery())).items.length == 1,
      'Following',
    );
    check(
      (await feed.getFeed(
        const PageQuery(),
        feedScope: FeedScope.following,
      )).items.isNotEmpty,
      'Following feed',
    );
    final comment = await feed.addComment(
      video.id,
      'Bình luận kiểm thử',
      idempotencyKey: 'dart-comment-key-00001',
    );
    check(
      (await feed.getComments(
        video.id,
        const PageQuery(),
      )).items.single.canDelete,
      'Comment owner',
    );
    await feed.deleteComment(video.id, comment.id);
    await feed.setLiked(video.id, false);
    await feed.setSaved(video.id, false);
    await feed.setFollowing(video.author.id, false);
    final consultant = await consultants.getConsultant(property.consultantId);
    check(consultant.videoCount == 24, 'Consultant count');
    await consultants.getVideos(consultant.id, const PageQuery());
    await consultants.getListings(consultant.id, const PageQuery());
    check(
      (await consultants.getReviews(
        consultant.id,
        const PageQuery(),
      )).items.isNotEmpty,
      'Review decimal mapper',
    );
    final start = DateTime.now().toUtc();
    final end = start.add(const Duration(days: 30));
    String date(DateTime value) => value.toIso8601String().substring(0, 10);
    await consultants.getAvailability(consultant.id, date(start), date(end));
    final slots = await bookings.getAvailability(
      property.id,
      date(start),
      date(end),
    );
    check(slots.isNotEmpty, 'Future availability');
    final input = BookingInput(
      propertyId: property.id,
      slotId: slots.first.id,
      attendeeCount: 1,
      transportMode: TransportMode.selfArranged,
      requestDocuments: true,
      requestLoanAdvice: false,
      contactName: 'Khách kiểm thử',
      contactPhone: '0900000678',
    );
    final booking = await bookings.create(
      input,
      idempotencyKey: 'dart-booking-key-00001',
    );
    check(
      booking.status == BookingStatus.awaitingDeposit &&
          booking.paymentStatus == PaymentStatus.unpaid &&
          booking.history.isNotEmpty,
      'Booking/payment/history mapper',
    );
    check(
      (await bookings.create(
            input,
            idempotencyKey: 'dart-booking-key-00001',
          )).id ==
          booking.id,
      'Booking retry',
    );
    await bookings.getBooking(booking.id);
    check(
      (await bookings.getHistory(const PageQuery())).items.single.id ==
          booking.id,
      'Booking history read',
    );
    check(
      !(await bookings.getDepositPolicy()).livePaymentEnabled,
      'Live payment must remain off',
    );
    final payment = (await payments.getBookingPayments(
      booking.id,
      const PageQuery(),
    )).items.single;
    await payments.getPayment(payment.id);
    check(
      (await payments.refresh(payment.id)).mode == PaymentMode.disabled,
      'Payment refresh',
    );
    await gated(
      payments.createIntent(
        booking.id,
        idempotencyKey: 'dart-payment-key-00001',
      ),
      FailureCode.policyNotConfigured,
    );
    await gated(
      bookings.requestCancellation(
        booking.id,
        const BookingChangeInput(reason: 'Thử policy'),
        idempotencyKey: 'dart-cancel-key-000001',
      ),
      FailureCode.policyNotConfigured,
    );
    final event = (await events.getEvents(
      const PageQuery(),
      status: EventStatus.open,
    )).items.first;
    await events.getEvent(event.id);
    await events.setSaved(event.id, true);
    check(
      (await events.getSavedEvents(const PageQuery())).items.length == 1,
      'Saved event',
    );
    final registration = await events.register(
      EventRegistrationInput(
        eventId: event.id,
        contactName: 'Khách kiểm thử',
        contactPhone: '0900000678',
        attendeeCount: 1,
      ),
      idempotencyKey: 'dart-event-key-000001',
    );
    check(
      registration.status == RegistrationStatus.pending &&
          registration.paymentMode == PaymentMode.disabled,
      'Registration pending mapper',
    );
    await events.getRegistrations(const PageQuery());
    await events.setSaved(event.id, false);
    final club = (await clubs.getClubs(const PageQuery())).items.first;
    await clubs.getClub(club.id);
    final ticket = await support.submit(
      SupportRequestInput(
        kind: SupportKind.legalReview,
        propertyId: property.id,
        consultantId: consultant.id,
        message: 'Yêu cầu kiểm thử',
        contactName: 'Khách kiểm thử',
        contactPhone: '0900000678',
        consentToShareContact: true,
      ),
      idempotencyKey: 'dart-support-key-00001',
    );
    check(
      ticket.status == SupportStatus.received &&
          (await support.getRequests(const PageQuery())).items.single.id ==
              ticket.id,
      'Support received mapper',
    );
    check(
      (await finance.getPlans(const PageQuery())).items.isEmpty,
      'Finance history',
    );
    final zero = await finance.calculate(
      FinanceInput(
        propertyId: property.id,
        equityVnd: property.priceTotal,
        loanVnd: Vnd('0'),
        termMonths: 60,
        annualRatePercent: DecimalValue('0'),
        method: RepaymentMethod.equalInstallment,
      ),
    );
    check(zero.totalRepaymentVnd.wireValue == '0', 'A-06 zero-loan mapper');
    final financeInput = FinanceInput(
      propertyId: property.id,
      equityVnd: Vnd('1200000000'),
      loanVnd: Vnd('1200000000'),
      termMonths: 240,
      annualRatePercent: DecimalValue('9'),
      method: RepaymentMethod.equalInstallment,
    );
    final estimate = await finance.calculate(financeInput);
    check(
      estimate.monthlyPaymentVnd.wireValue == '10796711' &&
          estimate.totalRepaymentVnd.wireValue == '2591210961',
      'A-06 exact result',
    );
    final plan = await finance.savePlan(
      'Dart C-4 finance snapshot',
      financeInput,
      idempotencyKey: 'dart-finance-key-00001',
    );
    check(
      plan.result?.formulaVersion == 'xland-loan-v1',
      'Persisted formula version',
    );
    check(
      (await finance.savePlan(
            'Dart C-4 finance snapshot',
            financeInput,
            idempotencyKey: 'dart-finance-key-00001',
          )).id ==
          plan.id,
      'Finance original retry',
    );
    check(
      (await finance.getPlans(const PageQuery()))
              .items
              .single
              .result
              ?.totalInterestVnd
              .wireValue ==
          '1391210961',
      'Finance snapshot mapper',
    );
    await finance.deletePlan(plan.id);
    await account.signOut();
    check(await sessions.readAccessToken() == null, 'Logout token clear');
    stdout.writeln(
      'PASS Dart typed repositories → HTTP → isolated PostgreSQL: all10 repositories; C-4 finance estimate/save/read/retry/delete and profile clear; history/social/settings/events/support; payment gates unchanged; credentials/tokens redacted. UI/P3 E2E not claimed.',
    );
  } finally {
    client.close();
  }
}
