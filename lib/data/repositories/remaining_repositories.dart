import '../../domain/xland_domain.dart';
import '../mappers/domain_mappers.dart';
import 'remote_repositories.dart';

final class RemoteFeedRepository implements FeedRepository {
  const RemoteFeedRepository(this.g);
  final RemoteGateway g;
  @override
  Future<Page<FeedVideo>> getFeed(
    PageQuery page, {
    FeedScope feedScope = FeedScope.recommended,
    Region? region,
    PropertyCategory? category,
  }) => g.page(
    'F01',
    '/feed',
    page,
    mapFeedVideo,
    query: {
      'feedScope': writeFeedScope(feedScope),
      if (region != null) 'region': writeRegion(region),
      if (category != null) 'category': writePropertyCategory(category),
    },
  );
  @override
  Future<FeedVideo> getVideo(String videoId) =>
      g.request('F02', 'GET', '/videos/$videoId', mapFeedVideo);
  @override
  Future<Page<FeedVideo>> getSavedVideos(PageQuery page) =>
      g.page('F10', '/me/saved-videos', page, mapFeedVideo);
  @override
  Future<MutationResult> setLiked(String videoId, bool liked) => g.request(
    liked ? 'F03' : 'F04',
    liked ? 'PUT' : 'DELETE',
    '/videos/$videoId/like',
    mapMutationResult,
  );
  @override
  Future<MutationResult> setSaved(String videoId, bool saved) => g.request(
    saved ? 'F08' : 'F09',
    saved ? 'PUT' : 'DELETE',
    '/videos/$videoId/saved',
    mapMutationResult,
  );
  @override
  Future<Page<VideoComment>> getComments(String videoId, PageQuery page) =>
      g.page('F05', '/videos/$videoId/comments', page, mapVideoComment);
  @override
  Future<VideoComment> addComment(
    String videoId,
    String text, {
    required String idempotencyKey,
  }) => g.request(
    'F06',
    'POST',
    '/videos/$videoId/comments',
    mapVideoComment,
    body: {'text': text},
    idempotencyKey: idempotencyKey,
  );
  @override
  Future<void> deleteComment(String videoId, String commentId) async {
    await g.request(
      'F07',
      'DELETE',
      '/videos/$videoId/comments/$commentId',
      (_) => null,
    );
  }

  @override
  Future<MutationResult> setFollowing(String authorId, bool following) =>
      g.request(
        following ? 'F11' : 'F12',
        following ? 'PUT' : 'DELETE',
        '/authors/$authorId/follow',
        mapMutationResult,
      );
  @override
  Future<Page<PublicAuthor>> getFollowing(PageQuery page) =>
      g.page('F13', '/me/following', page, mapPublicAuthor);
  @override
  Future<ShareLink> getShareLink(String videoId) =>
      g.request('F14', 'GET', '/videos/$videoId/share', mapShareLink);
}

final class RemoteConsultantRepository implements ConsultantRepository {
  const RemoteConsultantRepository(this.g);
  final RemoteGateway g;
  @override
  Future<Consultant> getConsultant(String consultantId) =>
      g.request('C01', 'GET', '/consultants/$consultantId', mapConsultant);
  @override
  Future<Page<FeedVideo>> getVideos(String consultantId, PageQuery page) =>
      g.page('C02', '/consultants/$consultantId/videos', page, mapFeedVideo);
  @override
  Future<Page<Property>> getListings(String consultantId, PageQuery page) =>
      g.page('C03', '/consultants/$consultantId/properties', page, mapProperty);
  @override
  Future<Page<ConsultantReview>> getReviews(
    String consultantId,
    PageQuery page,
  ) => g.page(
    'C04',
    '/consultants/$consultantId/reviews',
    page,
    mapConsultantReview,
  );
  @override
  Future<List<AvailabilitySlot>> getAvailability(
    String consultantId,
    String fromDate,
    String toDate,
  ) => g.request(
    'C05',
    'GET',
    '/consultants/$consultantId/availability',
    (value) => wireList(value, mapAvailabilitySlot),
    query: {'fromDate': fromDate, 'toDate': toDate},
  );
}

final class RemoteEventRepository implements EventRepository {
  const RemoteEventRepository(this.g);
  final RemoteGateway g;
  @override
  Future<Page<XlandEvent>> getEvents(PageQuery page, {EventStatus? status}) =>
      g.page(
        'E01',
        '/events',
        page,
        mapXlandEvent,
        query: {if (status != null) 'status': writeEventStatus(status)},
      );
  @override
  Future<XlandEvent> getEvent(String eventId) =>
      g.request('E02', 'GET', '/events/$eventId', mapXlandEvent);
  @override
  Future<MutationResult> setSaved(String eventId, bool saved) => g.request(
    saved ? 'E03' : 'E04',
    saved ? 'PUT' : 'DELETE',
    '/events/$eventId/saved',
    mapMutationResult,
  );
  @override
  Future<Page<XlandEvent>> getSavedEvents(PageQuery page) =>
      g.page('E07', '/me/saved-events', page, mapXlandEvent);
  @override
  Future<EventRegistration> register(
    EventRegistrationInput input, {
    required String idempotencyKey,
  }) => g.request(
    'E05',
    'POST',
    '/events/${input.eventId}/registrations',
    mapEventRegistration,
    body: {
      'contactName': input.contactName,
      'contactPhone': input.contactPhone,
      'attendeeCount': input.attendeeCount,
    },
    idempotencyKey: idempotencyKey,
  );
  @override
  Future<Page<EventRegistration>> getRegistrations(PageQuery page) =>
      g.page('E06', '/me/event-registrations', page, mapEventRegistration);
  @override
  Future<ShareLink> getShareLink(String eventId) =>
      g.request('E08', 'GET', '/events/$eventId/share', mapShareLink);
}

final class RemoteBookingRepository implements BookingRepository {
  const RemoteBookingRepository(this.g);
  final RemoteGateway g;
  @override
  Future<List<AvailabilitySlot>> getAvailability(
    String propertyId,
    String fromDate,
    String toDate,
  ) => g.request(
    'B01',
    'GET',
    '/properties/$propertyId/availability',
    (value) => wireList(value, mapAvailabilitySlot),
    query: {'fromDate': fromDate, 'toDate': toDate},
  );
  @override
  Future<DepositPolicy> getDepositPolicy() =>
      g.request('B02', 'GET', '/booking-deposit-policy', mapDepositPolicy);
  @override
  Future<Booking> create(
    BookingInput input, {
    required String idempotencyKey,
  }) => g.request(
    'B03',
    'POST',
    '/bookings',
    mapBooking,
    body: {
      'propertyId': input.propertyId,
      'slotId': input.slotId,
      'sourceVideoId': input.sourceVideoId,
      'attendeeCount': input.attendeeCount,
      'transportMode': writeTransportMode(input.transportMode),
      'requestDocuments': input.requestDocuments,
      'requestLoanAdvice': input.requestLoanAdvice,
      'contactName': input.contactName,
      'contactPhone': input.contactPhone,
      'note': input.note,
    },
    idempotencyKey: idempotencyKey,
  );
  @override
  Future<Page<Booking>> getHistory(PageQuery page, {BookingStatus? status}) =>
      g.page(
        'B04',
        '/me/bookings',
        page,
        mapBooking,
        query: {if (status != null) 'status': writeBookingStatus(status)},
      );
  @override
  Future<Booking> getBooking(String bookingId) =>
      g.request('B05', 'GET', '/bookings/$bookingId', mapBooking);
  @override
  Future<Booking> requestCancellation(
    String bookingId,
    BookingChangeInput input, {
    required String idempotencyKey,
  }) => g.request(
    'B06',
    'POST',
    '/bookings/$bookingId/cancellation-requests',
    mapBooking,
    body: {'reason': input.reason},
    idempotencyKey: idempotencyKey,
  );
  @override
  Future<Booking> requestReschedule(
    String bookingId,
    BookingChangeInput input, {
    required String idempotencyKey,
  }) => g.request(
    'B07',
    'POST',
    '/bookings/$bookingId/reschedule-requests',
    mapBooking,
    body: {'reason': input.reason, 'requestedSlotId': input.requestedSlotId},
    idempotencyKey: idempotencyKey,
  );
}

final class RemotePaymentRepository implements PaymentRepository {
  const RemotePaymentRepository(this.g);
  final RemoteGateway g;
  @override
  Future<Page<PaymentRecord>> getBookingPayments(
    String bookingId,
    PageQuery page,
  ) => g.page('P01', '/bookings/$bookingId/payments', page, mapPaymentRecord);
  @override
  Future<PaymentRecord> getPayment(String paymentId) =>
      g.request('P02', 'GET', '/payments/$paymentId', mapPaymentRecord);
  @override
  Future<PaymentRecord> createIntent(
    String bookingId, {
    required String idempotencyKey,
  }) => g.request(
    'P03',
    'POST',
    '/bookings/$bookingId/payment-intents',
    mapPaymentRecord,
    idempotencyKey: idempotencyKey,
  );
  @override
  Future<PaymentRecord> refresh(String paymentId) => g.request(
    'P04',
    'POST',
    '/payments/$paymentId/refresh',
    mapPaymentRecord,
  );
}

final class RemoteClubRepository implements ClubRepository {
  const RemoteClubRepository(this.g);
  final RemoteGateway g;
  @override
  Future<Page<Club>> getClubs(PageQuery page) =>
      g.page('K01', '/clubs', page, mapClub);
  @override
  Future<Club> getClub(String clubId) =>
      g.request('K02', 'GET', '/clubs/$clubId', mapClub);
}

Map<String, Object?> financeInput(FinanceInput input) => {
  'propertyId': input.propertyId,
  'equityVnd': input.equityVnd.wireValue,
  'loanVnd': input.loanVnd.wireValue,
  'termMonths': input.termMonths,
  'annualRatePercent': input.annualRatePercent.wireValue,
  'method': writeRepaymentMethod(input.method),
};

final class RemoteFinanceRepository implements FinanceRepository {
  const RemoteFinanceRepository(this.g);
  final RemoteGateway g;
  @override
  Future<FinanceResult> calculate(FinanceInput input) => g.request(
    'N01',
    'POST',
    '/finance/estimates',
    mapFinanceResult,
    body: financeInput(input),
  );
  @override
  Future<SavedFinancePlan> savePlan(
    String label,
    FinanceInput input, {
    required String idempotencyKey,
  }) => g.request(
    'N02',
    'POST',
    '/me/finance-plans',
    mapSavedFinancePlan,
    body: {'label': label, 'input': financeInput(input)},
    idempotencyKey: idempotencyKey,
  );
  @override
  Future<Page<SavedFinancePlan>> getPlans(PageQuery page) =>
      g.page('N03', '/me/finance-plans', page, mapSavedFinancePlan);
  @override
  Future<void> deletePlan(String planId) async {
    await g.request('N04', 'DELETE', '/me/finance-plans/$planId', (_) => null);
  }
}

final class RemoteSupportRepository implements SupportRepository {
  const RemoteSupportRepository(this.g);
  final RemoteGateway g;
  @override
  Future<SupportRequest> submit(
    SupportRequestInput input, {
    required String idempotencyKey,
  }) => g.request(
    'S01',
    'POST',
    '/support-requests',
    mapSupportRequest,
    body: {
      'kind': writeSupportKind(input.kind),
      'propertyId': input.propertyId,
      'consultantId': input.consultantId,
      'message': input.message,
      'contactName': input.contactName,
      'contactPhone': input.contactPhone,
      'consentToShareContact': input.consentToShareContact,
    },
    idempotencyKey: idempotencyKey,
  );
  @override
  Future<Page<SupportRequest>> getRequests(PageQuery page) =>
      g.page('S02', '/me/support-requests', page, mapSupportRequest);
}
