import 'package:flutter/material.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../shared/utils/value_formatters.dart';
import '../../../theme/theme.dart';

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onBookmarkTap,
    this.showBookmark = true,
  });
  final Property property;
  final VoidCallback? onTap, onBookmarkTap;
  final bool showBookmark;
  @override
  Widget build(BuildContext context) {
    final media = property.media.isEmpty ? null : property.media.first;
    final board = property.sourceBadge == SourceBadge.boardSource;
    return XLandCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.8,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: XLandMediaImage(
                    url:
                        media?.thumbnailUrl ??
                        (media?.kind == MediaKind.image ? media?.url : null),
                    isIllustrative: property.isIllustrative,
                    showLabel: false,
                    illustrativeAsset: property.region == Region.central
                        ? IllustrativeAssets.coastal
                        : IllustrativeAssets.countryside,
                  ),
                ),
              ),
              if (showBookmark)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: property.isSaved ? 'Bỏ lưu lô đất' : 'Lưu lô đất',
                    onPressed: onBookmarkTap,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      property.isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 23,
                    ),
                  ),
                ),
              if (media?.kind == MediaKind.video)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '▶ Video${media?.durationSeconds == null ? '' : ' ${media!.durationSeconds}s'}',
                      style: AppTypography.compact.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (property.hasSubplots)
                  const StatusBadge(
                    text: 'Nhiều lô đất con',
                    variant: StatusBadgeVariant.source,
                  ),
                if (property.isCorner) const Text('Lô góc'),
                Text(
                  property.title,
                  style: AppTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatCompactVnd(property.priceTotal),
                  style: AppTypography.priceCard,
                ),
                Text(
                  '${formatMeasurement(property.areaM2, 'm²')} • ${formatCompactVnd(property.pricePerM2)}/m²',
                  style: AppTypography.compact,
                  maxLines: 2,
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: board
                        ? AppColors.goldSurface
                        : AppColors.verifiedSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        board
                            ? Icons.verified_user_outlined
                            : Icons.check_circle,
                        size: 14,
                        color: board
                            ? AppColors.goldForeground
                            : AppColors.brandPrimary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          board ? 'Nguồn HĐQT' : 'Tin đã duyệt',
                          style: AppTypography.compact.copyWith(
                            color: board
                                ? AppColors.goldForeground
                                : AppColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
