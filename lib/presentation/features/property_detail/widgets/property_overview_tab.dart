import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

import '../../../shared/utils/value_formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/design_widgets.dart';
import '../../../shared/widgets/illustrative_image.dart';
import '../../../theme/theme.dart';
import 'media_gallery_view.dart';

class PropertyOverviewTab extends StatelessWidget {
  const PropertyOverviewTab({
    super.key,
    required this.property,
    required this.consultant,
    required this.activeMediaIndex,
    required this.onMediaIndexChanged,
    required this.onNavigateToLegalTab,
    this.onConsultantTap,
    this.showGallery = true,
    this.embedded = false,
  });
  final Property property;
  final Consultant? consultant;
  final int activeMediaIndex;
  final ValueChanged<int> onMediaIndexChanged;
  final VoidCallback onNavigateToLegalTab;
  final VoidCallback? onConsultantTap;
  final bool showGallery;

  final bool embedded;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    primary: embedded ? false : null,
    physics: embedded ? const NeverScrollableScrollPhysics() : null,
    key: const PageStorageKey('property-overview'),
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showGallery)
          MediaGalleryView(
            media: property.media,
            currentIndex: activeMediaIndex,
            onIndexChanged: onMediaIndexChanged,
            fallbackCode: property.code,
            isIllustrative: property.isIllustrative,
            illustrativeAsset: property.region == Region.central
                ? IllustrativeAssets.coastal
                : IllustrativeAssets.countryside,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(property.title, style: AppTypography.pageHero),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${property.code} • ${property.districtName}, ${property.provinceName}',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    formatCompactVnd(property.priceTotal),
                    style: AppTypography.priceHero,
                  ),
                  Text(
                    '${formatCompactVnd(property.pricePerM2)}/m²',
                    style: AppTypography.bodyStrong,
                  ),
                  StatusBadge(
                    text: switch (property.status) {
                      PropertyStatus.listed => 'Đang chào bán',
                      PropertyStatus.sold => 'Đã bán',
                      PropertyStatus.paused => 'Tạm dừng',
                    },
                    variant: StatusBadgeVariant.source,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _metrics(context),
              const SizedBox(height: 12),
              if (property.highlights.isNotEmpty) ...[
                XLandCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DesignSectionTitle(
                        'Điểm đáng chú ý',
                        icon: Icons.star_rounded,
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < property.highlights.length; i += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _highlight(property.highlights[i], i),
                              ),
                              if (i + 1 < property.highlights.length) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _highlight(
                                    property.highlights[i + 1],
                                    i + 1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              XLandCard(
                padding: EdgeInsets.zero,
                onTap: onNavigateToLegalTab,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 30,
                        color: AppColors.brandPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hồ sơ đã đối chiếu ${property.verifiedLegalCount}/${property.totalLegalCount}',
                              style: AppTypography.bodyStrong,
                            ),
                            Text(
                              property.totalLegalCount >
                                      property.verifiedLegalCount
                                  ? '${property.totalLegalCount - property.verifiedLegalCount} mục cần bổ sung'
                                  : property.totalLegalCount == 0
                                  ? 'Chưa có hồ sơ được chia sẻ'
                                  : 'Đã đối chiếu các mục được chia sẻ',
                              style: AppTypography.compact.copyWith(
                                color: AppColors.goldForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 21),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  _meta(
                    Icons.schedule,
                    'Cập nhật: ${DateFormat('dd/MM/yyyy').format(property.updatedAt.toLocal())}',
                  ),
                  _meta(Icons.bar_chart_outlined, 'Giá chào tham khảo'),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _highlight(Highlight h, int i) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        i.isEven ? Icons.home_outlined : Icons.photo_camera_outlined,
        color: AppColors.brandPrimary,
        size: 23,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.title, style: AppTypography.compactStrong),
            Text(h.description, style: AppTypography.compact),
          ],
        ),
      ),
    ],
  );

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(text, style: AppTypography.compact),
    ],
  );

  Widget _metrics(BuildContext context) {
    final items = [
      (formatMeasurement(property.areaM2, 'm²'), 'Diện tích', Icons.crop_free),
      (
        formatMeasurement(property.frontageM, 'm'),
        'Mặt tiền',
        Icons.straighten,
      ),
      (formatMeasurement(property.depthM, 'm'), 'Chiều sâu', Icons.height),
      (
        formatMeasurement(property.roadWidthM, 'm'),
        'Đường trước đất',
        Icons.add_road,
      ),
      (
        formatPropertyDirection(property.direction),
        'Hướng',
        Icons.explore_outlined,
      ),
      (formatLandType(property.landType), 'Loại đất', Icons.layers_outlined),
    ];
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: col == 0
                              ? null
                              : const Border(
                                  left: BorderSide(color: AppColors.border),
                                ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              items[row * 3 + col].$3,
                              size: 17,
                              color: AppColors.goldDecorative,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              items[row * 3 + col].$1,
                              textAlign: TextAlign.center,
                              style: AppTypography.cardTitle.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              items[row * 3 + col].$2,
                              style: AppTypography.compact,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
