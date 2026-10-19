import 'package:flutter/material.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../../../theme/theme.dart';
import '../../../shared/widgets/illustrative_image.dart';
import 'property_media_viewer.dart';

/// Media Gallery component for S02 Overview.
/// Displays main media carousel/viewer with "X/Y" counter and interactive thumbnail strip.
class MediaGalleryView extends StatelessWidget {
  const MediaGalleryView({
    super.key,
    required this.media,
    required this.currentIndex,
    required this.onIndexChanged,
    this.fallbackCode = 'XL',
    this.isIllustrative = false,
    this.illustrativeAsset = IllustrativeAssets.countryside,
  });

  final List<MediaAsset> media;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final String fallbackCode;
  final bool isIllustrative;
  final String illustrativeAsset;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      if (isIllustrative) {
        return AspectRatio(
          aspectRatio: 2.35,
          child: XLandMediaImage(
            isIllustrative: true,
            illustrativeAsset: illustrativeAsset,
          ),
        );
      }
      return _buildEmptyGallery();
    }

    final safeIndex = currentIndex.clamp(0, media.length - 1);
    final activeItem = media[safeIndex];

    return Column(
      children: [
        // The full viewer supports swipe, zoom, and real video playback.
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PropertyMediaViewer(
                media: media,
                initialIndex: safeIndex,
                illustrativeAsset: illustrativeAsset,
              ),
            ),
          ),
          onHorizontalDragEnd: (details) {
            final next = (safeIndex + (details.primaryVelocity! < 0 ? 1 : -1))
                .clamp(0, media.length - 1);
            onIndexChanged(next);
          },
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 2.35,
                child: Container(
                  color: AppColors.disabledSurface,
                  child: XLandMediaImage(
                    url: activeItem.kind == MediaKind.image
                        ? activeItem.url
                        : activeItem.thumbnailUrl,
                    isIllustrative: activeItem.isIllustrative,
                    illustrativeAsset: illustrativeAsset,
                    showLabel: false,
                  ),
                ),
              ),

              // Video overlay if active item is video
              if (activeItem.kind == MediaKind.video)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),

              // 1/8 Counter Indicator
              Positioned(
                bottom: AppSpacing.s12,
                right: AppSpacing.s12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${safeIndex + 1}/${media.length}',
                    style: AppTypography.compact.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Video / Image label
              Positioned(
                bottom: AppSpacing.s12,
                left: AppSpacing.s12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activeItem.kind == MediaKind.video
                            ? Icons.videocam_rounded
                            : Icons.photo_library_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activeItem.kind == MediaKind.video
                            ? 'Video ${_duration(activeItem.durationSeconds)}'
                            : 'Hình ảnh',
                        style: AppTypography.compact.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Thumbnail Strip
        if (media.length > 1) ...[
          const SizedBox(height: AppSpacing.s8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutter,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s8),
              itemBuilder: (context, idx) {
                final item = media[idx];
                final isSelected = idx == safeIndex;

                return GestureDetector(
                  onTap: () => onIndexChanged(idx),
                  child: Container(
                    width: (MediaQuery.sizeOf(context).width - 48) / 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                      color: AppColors.disabledSurface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        XLandMediaImage(
                          url:
                              item.thumbnailUrl ??
                              (item.kind == MediaKind.image ? item.url : null),
                          isIllustrative: item.isIllustrative,
                          illustrativeAsset: illustrativeAsset,
                          showLabel: false,
                        ),
                        Center(
                          child: Icon(
                            item.kind == MediaKind.video
                                ? Icons.play_circle_outline_rounded
                                : Icons.image_outlined,
                            size: 20,
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.disabledForeground,
                          ),
                        ),
                        if (item.kind == MediaKind.video)
                          Positioned(
                            top: 2,
                            left: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.videocam,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  String _duration(int? seconds) => seconds == null
      ? ''
      : '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _buildEmptyGallery() {
    return AspectRatio(
      aspectRatio: 2.35,
      child: Container(
        color: AppColors.disabledSurface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.landscape_rounded,
                size: 48,
                color: AppColors.disabledForeground,
              ),
              const SizedBox(height: 6),
              Text(
                'Lô đất $fallbackCode',
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.disabledForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Đang cập nhật hình ảnh thực địa',
                style: AppTypography.compact.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
