import 'package:flutter/material.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme.dart';

/// Hero Banner Carousel for S01 Discovery Header.
/// Highlights Community Events, Workshops, and Investor Clubs.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    this.onEventTap,
    this.onClubTap,
    this.eventTitle = 'Khám phá sự kiện XLand',
    this.eventSubtitle = 'Gặp gỡ và kết nối cộng đồng',
  });

  final VoidCallback? onEventTap;
  final VoidCallback? onClubTap;
  final String eventTitle;
  final String eventSubtitle;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView(
            controller: _controller,
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [_buildEventBanner(), _buildClubBanner()],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            final isActive = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.brandPrimary : AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEventBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: XLandCard(
        padding: const EdgeInsets.all(AppSpacing.s16),
        onTap: widget.onEventTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.verifiedSurface,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.brandPrimary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const StatusBadge(
                    text: 'Sự kiện XLand',
                    variant: StatusBadgeVariant.verified,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.eventTitle,
                    style: AppTypography.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.eventSubtitle,
                    style: AppTypography.compact.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: XLandCard(
        padding: const EdgeInsets.all(AppSpacing.s16),
        onTap: widget.onClubTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.goldSurface,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: AppColors.goldForeground,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const StatusBadge(
                    text: 'Cộng đồng XLand',
                    variant: StatusBadgeVariant.source,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CLB Nhà đầu tư đất nền',
                    style: AppTypography.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chia sẻ kinh nghiệm thẩm định pháp lý',
                    style: AppTypography.compact.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
