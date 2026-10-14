import 'xland_repositories.dart';

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
}
