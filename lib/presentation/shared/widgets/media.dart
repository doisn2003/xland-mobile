import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Standard Media Image Placeholder for property photos, avatars, and banners.
/// Operates purely in Flutter widgets without crashing when binary asset files are missing.
class MediaImagePlaceholder extends StatelessWidget {
  const MediaImagePlaceholder({
    super.key,
    this.aspectRatio = 16 / 9,
    this.label,
    this.icon = Icons.landscape_rounded,
    this.borderRadius = AppRadius.cardRadius,
    this.overlay,
    this.height,
    this.width,
  });

  final double aspectRatio;
  final String? label;
  final IconData icon;
  final BorderRadius borderRadius;
  final Widget? overlay;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E0D5),
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: AppColors.textMuted,
              ),
              if (label != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  label!,
                  style: AppTypography.compact.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          ?overlay,
        ],
      ),
    );

    if (height == null && width == null) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: content,
      );
    }

    return content;
  }
}

/// Overlay Pill for video duration, photo count ('1/8'), or video views.
/// Uses overlayBase with 56% opacity per spec.
class MediaOverlayPill extends StatelessWidget {
  const MediaOverlayPill({
    super.key,
    required this.text,
    this.icon,
  });

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.mediaPillOverlay,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.onPrimary),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTypography.compact.copyWith(
              color: AppColors.onPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gallery Preview Placeholder demonstrating photo strip and photo index.
class MediaGalleryPlaceholder extends StatelessWidget {
  const MediaGalleryPlaceholder({
    super.key,
    this.propertyCode = 'XL-028',
    this.photoCount = 8,
    this.currentIndex = 1,
  });

  final String propertyCode;
  final int photoCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MediaImagePlaceholder(
          aspectRatio: 2.3,
          label: 'Ảnh thực địa $propertyCode ($currentIndex/$photoCount)',
          borderRadius: BorderRadius.zero,
          overlay: Positioned(
            bottom: AppSpacing.s8,
            right: AppSpacing.pageGutter,
            child: MediaOverlayPill(
              text: '$currentIndex/$photoCount',
              icon: Icons.photo_library_outlined,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
          child: Row(
            children: List.generate(3, (index) {
              final isSelected = index == (currentIndex - 1);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? AppSpacing.s8 : 0),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBE6DC),
                      borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                      border: Border.all(
                        color: isSelected ? AppColors.brandPrimary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        index == 0 ? Icons.play_circle_outline_rounded : Icons.image_outlined,
                        size: 20,
                        color: isSelected ? AppColors.brandPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
