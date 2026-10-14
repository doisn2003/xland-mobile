import '../entities/account.dart';
import '../entities/booking.dart';
import '../entities/common.dart';
import '../entities/consultant.dart';
import '../entities/event.dart';
import '../entities/finance.dart';
import '../entities/property.dart';
import '../entities/social.dart';

/// All failures throw XlandFailure. Caller never supplies an owner user ID.
/// Pagination cursor is opaque; idempotency keys survive retry/reopen.
abstract interface class PropertyRepository {
  Future<PropertySearchResult> search(PropertyFilter filter, PageQuery page);
  Future<int> count(PropertyFilter filter);
  Future<FilterCatalog> getFilterCatalog({String? provinceCode});
  Future<Property> getProperty(String propertyId);
  Future<LegalSummary> getLegal(String propertyId);
  Future<DownloadGrant> requestDownload(String propertyId, String documentId);
  Future<AreaInfo> getArea(String propertyId, {AmenityCategory? category});
  Future<MutationResult> setSaved(String propertyId, bool saved);
  Future<ShareLink> getShareLink(String propertyId);
}

abstract interface class FeedRepository {
  Future<Page<FeedVideo>> getFeed(
    PageQuery page, {
    Region? region,
    PropertyCategory? category,
  });
  Future<FeedVideo> getVideo(String videoId);
  Future<Page<FeedVideo>> getSavedVideos(PageQuery page);
  Future<MutationResult> setLiked(String videoId, bool liked);
  Future<MutationResult> setSaved(String videoId, bool saved);
  Future<Page<VideoComment>> getComments(String videoId, PageQuery page);
  Future<VideoComment> addComment(
    String videoId,
    String text, {
    required String idempotencyKey,
  });
  Future<void> deleteComment(String videoId, String commentId);
  Future<MutationResult> setFollowing(String authorId, bool following);
  Future<Page<PublicAuthor>> getFollowing(PageQuery page);
  Future<ShareLink> getShareLink(String videoId);
}

abstract interface class ConsultantRepository {
  Future<Consultant> getConsultant(String consultantId);
  Future<Page<FeedVideo>> getVideos(String consultantId, PageQuery page);
  Future<Page<Property>> getListings(String consultantId, PageQuery page);
  Future<Page<ConsultantReview>> getReviews(
    String consultantId,
    PageQuery page,
  );
  Future<List<AvailabilitySlot>> getAvailability(
    String consultantId,
    String fromDate,
    String toDate,
  );
}

abstract interface class EventRepository {
  Future<Page<XlandEvent>> getEvents(PageQuery page, {EventStatus? status});
  Future<XlandEvent> getEvent(String eventId);
  Future<MutationResult> setSaved(String eventId, bool saved);
  Future<Page<XlandEvent>> getSavedEvents(PageQuery page);
  Future<EventRegistration> register(
    EventRegistrationInput input, {
    required String idempotencyKey,
  });
  Future<Page<EventRegistration>> getRegistrations(PageQuery page);
  Future<ShareLink> getShareLink(String eventId);
}

abstract interface class BookingRepository {
  Future<List<AvailabilitySlot>> getAvailability(
    String propertyId,
    String fromDate,
    String toDate,
  );
  Future<DepositPolicy> getDepositPolicy();
  Future<Booking> create(BookingInput input, {required String idempotencyKey});
  Future<Page<Booking>> getHistory(PageQuery page, {BookingStatus? status});
  Future<Booking> getBooking(String bookingId);
  Future<Booking> requestCancellation(
    String bookingId,
    BookingChangeInput input, {
    required String idempotencyKey,
  });
  Future<Booking> requestReschedule(
    String bookingId,
    BookingChangeInput input, {
    required String idempotencyKey,
  });
}

abstract interface class PaymentRepository {
  Future<Page<PaymentRecord>> getBookingPayments(
    String bookingId,
    PageQuery page,
  );
  Future<PaymentRecord> getPayment(String paymentId);
  Future<PaymentRecord> createIntent(
    String bookingId, {
    required String idempotencyKey,
  });
  Future<PaymentRecord> refresh(String paymentId);
}

abstract interface class AccountRepository {
  Future<Session?> getSession();
  Future<Session> signIn(SignInInput input);
  Future<void> signOut();
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile(ProfileUpdate input);
  Future<UserSettings> getSettings();
  Future<UserSettings> updateSettings(SettingsUpdate input);
}

abstract interface class ClubRepository {
  Future<Page<Club>> getClubs(PageQuery page);
  Future<Club> getClub(String clubId);
}

abstract interface class FinanceRepository {
  // Formula and rounding gated by SPEC-001; no calculator implementation in P1.
  Future<FinanceResult> calculate(FinanceInput input);
  Future<SavedFinancePlan> savePlan(
    String label,
    FinanceInput input, {
    required String idempotencyKey,
  });
  Future<Page<SavedFinancePlan>> getPlans(PageQuery page);
  Future<void> deletePlan(String planId);
}

abstract interface class SupportRepository {
  Future<SupportRequest> submit(
    SupportRequestInput input, {
    required String idempotencyKey,
  });
  Future<Page<SupportRequest>> getRequests(PageQuery page);
}
