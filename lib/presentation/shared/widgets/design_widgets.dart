import 'package:flutter/material.dart';

import '../../../domain/xland_domain.dart';
import '../../theme/theme.dart';
import '../utils/value_formatters.dart';
import 'illustrative_image.dart';

/// Thin vector coin stacks matching the brand's financial pictograms.
class DesignIcon extends StatelessWidget {
  const DesignIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color = AppColors.goldDecorative,
  });
  final IconData icon;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => icon == Icons.savings_outlined
      ? CustomPaint(size: Size.square(size), painter: _CoinsPainter(color))
      : Icon(icon, size: size, color: color);
}

class _CoinsPainter extends CustomPainter {
  const _CoinsPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stack in [(2.0, 14.0, 3), (10.0, 5.0, 5)]) {
      canvas.drawOval(Rect.fromLTWH(stack.$1, stack.$2, 11, 4), pen);
      for (var i = 1; i <= stack.$3; i++) {
        final y = stack.$2 + i * 2.6;
        canvas.drawPath(
          Path()
            ..moveTo(stack.$1, y - 2.6)
            ..lineTo(stack.$1, y)
            ..cubicTo(
              stack.$1,
              y + 2.6,
              stack.$1 + 11,
              y + 2.6,
              stack.$1 + 11,
              y,
            )
            ..lineTo(stack.$1 + 11, y - 2.6),
          pen,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoinsPainter oldDelegate) => color != oldDelegate.color;
}

/// Shared section treatment from the reference screens.
class DesignSectionTitle extends StatelessWidget {
  const DesignSectionTitle(
    this.title, {
    super.key,
    required this.icon,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      DesignIcon(icon, size: 22, color: AppColors.goldDecorative),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: AppTypography.cardTitle)),
      ?trailing,
    ],
  );
}

class PropertySummaryStrip extends StatelessWidget {
  const PropertySummaryStrip({super.key, required this.property, this.onTap});
  final Property property;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 78,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: XLandMediaImage(
                url: property.media.isEmpty
                    ? null
                    : property.media.first.thumbnailUrl ??
                          (property.media.first.kind == MediaKind.image
                              ? property.media.first.url
                              : null),
                isIllustrative: property.isIllustrative,
                illustrativeAsset: property.region == Region.central
                    ? IllustrativeAssets.coastal
                    : IllustrativeAssets.countryside,
                showLabel: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.title,
                  style: AppTypography.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${property.code} • ${formatMeasurement(property.areaM2, 'm²')}',
                  style: AppTypography.compact,
                ),
                const SizedBox(height: 3),
                Text(
                  property.locationLabel,
                  style: AppTypography.compact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatCompactVnd(property.priceTotal),
                  style: AppTypography.priceCard,
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );
}
