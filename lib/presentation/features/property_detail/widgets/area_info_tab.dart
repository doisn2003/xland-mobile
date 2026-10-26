import 'package:flutter/material.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/design_widgets.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../theme/theme.dart';
import '../../area_map/area_map_panel.dart';

/// S04 Area & POI Tab Component.
/// Displays approximate map preview with radius indicator, 3 amenity category segments,
/// list of surrounding POIs with distances, area photos, and provider attribution.
class AreaInfoTab extends StatelessWidget {
  const AreaInfoTab({
    super.key,
    required this.areaInfo,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.embedded = false,
    this.mapVisible = true,
  });

  final AreaInfo areaInfo;
  final AmenityCategory? selectedCategory;
  final ValueChanged<AmenityCategory?> onCategorySelected;

  IconData _getAmenityIcon(String iconType) {
    switch (iconType) {
      case 'school':
        return Icons.school_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'market':
        return Icons.storefront_rounded;
      case 'road':
        return Icons.add_road_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  final bool embedded;
  final bool mapVisible;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: embedded ? false : null,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.s16,
        AppSpacing.pageGutter,
        AppSpacing.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 POI Segments
          const DesignSectionTitle(
            'Tiện ích trong khu vực',
            icon: Icons.location_city_outlined,
          ),
          const SizedBox(height: AppSpacing.s8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SegmentChip(
                  label: 'Tất cả',
                  isSelected: selectedCategory == null,
                  onTap: () => onCategorySelected(null),
                ),
                const SizedBox(width: AppSpacing.s8),
                _SegmentChip(
                  label: 'Tiện ích',
                  isSelected: selectedCategory == AmenityCategory.utility,
                  onTap: () => onCategorySelected(AmenityCategory.utility),
                ),
                const SizedBox(width: AppSpacing.s8),
                _SegmentChip(
                  label: 'Giao thông',
                  isSelected: selectedCategory == AmenityCategory.traffic,
                  onTap: () => onCategorySelected(AmenityCategory.traffic),
                ),
                const SizedBox(width: AppSpacing.s8),
                _SegmentChip(
                  label: 'Đời sống',
                  isSelected: selectedCategory == AmenityCategory.living,
                  onTap: () => onCategorySelected(AmenityCategory.living),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Amenities List
          if (areaInfo.amenities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Center(
                child: Text(
                  'Không có tiện ích trong danh mục này',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amenity in areaInfo.amenities)
                    SizedBox(
                      width: (constraints.maxWidth - 8) / 2,
                      child: XLandCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _getAmenityIcon(amenity.iconType),
                              color: AppColors.brandPrimary,
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    amenity.name,
                                    style: AppTypography.bodyStrong,
                                  ),
                                  Text(
                                    amenity.distanceText,
                                    style: AppTypography.compact,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.s24),

          // Surrounding Photos
          if (areaInfo.photos.isNotEmpty) ...[
            Text(
              'Hình ảnh khu vực xung quanh',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.s8),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: areaInfo.photos.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.s12),
                itemBuilder: (context, idx) {
                  final photo = areaInfo.photos[idx];
                  return Container(
                    width: 150,
                    decoration: BoxDecoration(
                      color: AppColors.disabledSurface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: XLandMediaImage(
                            url: photo.thumbnailUrl ?? photo.url,
                            isIllustrative: photo.isIllustrative,
                            showLabel: false,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            photo.altText,
                            style: AppTypography.compactStrong,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
          ],

          // Provider Attribution
          Center(
            child: Text(
              'Thông tin tiện ích do XLand tổng hợp',
              style: AppTypography.compact.copyWith(
                color: AppColors.disabledForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (mapVisible) ...[
            const SizedBox(height: AppSpacing.s24),
            AreaMapPanel(propertyId: areaInfo.propertyId),
          ],
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
      child: Material(
        color: isSelected ? AppColors.brandPrimary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(
            color: isSelected ? AppColors.brandPrimary : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: AppTypography.compactStrong.copyWith(
                color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
