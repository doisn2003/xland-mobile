import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Base Card container with standardized border, background, and corner radius.
class XLandCard extends StatelessWidget {
  const XLandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.margin,
    this.isLarge = false,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool isLarge;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = isLarge ? AppRadius.cardLargeRadius : AppRadius.cardRadius;
    final effectiveBorder = BorderSide(
      color: borderColor ?? AppColors.border,
      width: borderWidth ?? AppSpacing.borderWidthRegular,
    );

    Widget content = Material(
      color: backgroundColor ?? AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: effectiveBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding,
                child: child,
              ),
            )
          : Padding(
              padding: padding,
              child: child,
            ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

enum StatusBadgeVariant {
  verified,
  source,
  pending,
  sale,
  danger,
}

/// Status Badge for verification, data source, and sale state.
/// Ensures information is conveyed through both icon and text (not color alone).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    this.variant = StatusBadgeVariant.verified,
    this.icon,
  });

  final String text;
  final StatusBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Color surfaceColor;
    Color foregroundColor;
    IconData defaultIcon;

    switch (variant) {
      case StatusBadgeVariant.verified:
        surfaceColor = AppColors.verifiedSurface;
        foregroundColor = AppColors.verifiedForeground;
        defaultIcon = Icons.verified_rounded;
      case StatusBadgeVariant.source:
      case StatusBadgeVariant.pending:
      case StatusBadgeVariant.sale:
        surfaceColor = AppColors.goldSurface;
        foregroundColor = AppColors.goldForeground;
        defaultIcon = variant == StatusBadgeVariant.pending
            ? Icons.schedule_rounded
            : Icons.star_rounded;
      case StatusBadgeVariant.danger:
        surfaceColor = AppColors.dangerSurface;
        foregroundColor = AppColors.danger;
        defaultIcon = Icons.warning_amber_rounded;
    }

    return Semantics(
      label: 'Trạng thái: $text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 3),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon ?? defaultIcon,
              size: 14,
              color: foregroundColor,
            ),
            const SizedBox(width: 4),
            Flexible(child: Text(
              text,
              style: AppTypography.compact.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.2,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

enum NoticeVariant {
  info,
  warning,
  danger,
  gold,
}

/// Information & Warning Banner for legal disclosures and booking notices.
class InfoNotice extends StatelessWidget {
  const InfoNotice({
    super.key,
    required this.message,
    this.title,
    this.variant = NoticeVariant.info,
    this.icon,
  });

  final String message;
  final String? title;
  final NoticeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    IconData defaultIcon;

    switch (variant) {
      case NoticeVariant.info:
        bg = AppColors.verifiedSurface;
        fg = AppColors.brandPrimary;
        border = AppColors.brandPrimary.withValues(alpha: 0.2);
        defaultIcon = Icons.info_outline_rounded;
      case NoticeVariant.warning:
      case NoticeVariant.gold:
        bg = AppColors.goldSurface;
        fg = AppColors.goldForeground;
        border = AppColors.goldForeground.withValues(alpha: 0.3);
        defaultIcon = Icons.report_problem_outlined;
      case NoticeVariant.danger:
        bg = AppColors.dangerSurface;
        fg = AppColors.danger;
        border = AppColors.danger.withValues(alpha: 0.3);
        defaultIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: AppSpacing.iconRegular, color: fg),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTypography.cardTitle.copyWith(
                      color: fg,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: AppTypography.compact.copyWith(
                    color: fg,
                    height: 1.35,
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

/// Notice banner specifically for demo fixture data disclosures.
class DemoDataNotice extends StatelessWidget {
  const DemoDataNotice({
    super.key,
    this.message = 'Dữ liệu minh họa • Chưa thay thế thẩm định pháp lý hoặc tài chính chính thức',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: AppColors.goldSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.thumbnail),
        border: Border.all(
          color: AppColors.goldForeground.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.goldForeground,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.compact.copyWith(
                fontSize: 11,
                color: AppColors.goldForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Price Display formatted cleanly in Vietnamese Dong.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.priceVnd,
    this.style,
    this.unitText,
  });

  final String priceVnd;
  final TextStyle? style;
  final String? unitText;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? AppTypography.priceCard;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: priceVnd,
            style: effectiveStyle,
          ),
          if (unitText != null) ...[
            const TextSpan(text: ' '),
            TextSpan(
              text: unitText,
              style: effectiveStyle.copyWith(
                fontSize: (effectiveStyle.fontSize ?? 16) * 0.65,
                fontWeight: FontWeight.normal,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
