import 'xland_repositories.dart';
import '../auth/extended_auth.dart';
import '../entities/guest_preferences.dart';

/// Proposed constructor input for B's XLandApp; A/B confirm in P1 review.
final class XlandDependencies {
  const XlandDependencies({
    required this.properties,
    required this.feed,
    required this.consultants,
    required this.events,
    required this.bookings,
    required this.payments,
    required this.account,
    required this.clubs,
    required this.finance,
    required this.support,
    this.guestPreferences,
    this.extendedAuth,
    this.contentChanges,
    this.refreshContent,
  });
  final PropertyRepository properties;
  final FeedRepository feed;
  final ConsultantRepository consultants;
  final EventRepository events;
  final BookingRepository bookings;
  final PaymentRepository payments;
  final AccountRepository account;
  final ClubRepository clubs;
  final FinanceRepository finance;
  final SupportRepository support;
  final GuestPreferencesRepository? guestPreferences;
  final ExtendedAuthRepository? extendedAuth;
  final Stream<Set<String>>? contentChanges;
  final Future<void> Function(String path)? refreshContent;
}
