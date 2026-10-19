import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Primary Filled Button according to XLand design spec.
/// Height >= 48dp, corner radius 12dp, submitting spinner, full accessibility.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isSubmitting = false,
    this.fullWidth = true,
    this.height = AppSpacing.ctaMinHeight,
    this.maxLines = 2,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isSubmitting;
  final bool fullWidth;
  final double height;
  final int maxLines;

  bool get _isEnabled => onPressed != null && !isSubmitting;

  @override
  Widget build(BuildContext context) {
    final buttonContent = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isSubmitting) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            'Đang xử lý...',
            style: AppTypography.button,
          ),
        ] else ...[
          if (icon != null) ...[
            icon!,
            const SizedBox(width: AppSpacing.s8),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTypography.button,
              textAlign: TextAlign.center,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: height,
          minWidth: fullWidth ? double.infinity : AppSpacing.minTouchTarget,
        ),
        child: ElevatedButton(
          onPressed: _isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.disabledSurface,
            disabledForegroundColor: AppColors.disabledForeground,
            elevation: 0,
            minimumSize: Size(fullWidth ? double.infinity : AppSpacing.minTouchTarget, height),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.buttonRadius,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
          ),
          child: buttonContent,
        ),
      ),
    );
  }
}

/// Outlined Button according to XLand design spec.
/// Height >= 48dp, corner radius 12dp, brand border.
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isSubmitting = false,
    this.fullWidth = true,
    this.height = AppSpacing.ctaMinHeight,
    this.maxLines = 2,
    this.inverse = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isSubmitting;
  final bool fullWidth;
  final double height;
  final int maxLines;
  final bool inverse;

  bool get _isEnabled => onPressed != null && !isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: label,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: height,
          minWidth: fullWidth ? double.infinity : AppSpacing.minTouchTarget,
        ),
        child: OutlinedButton(
          onPressed: _isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: inverse ? AppColors.onPrimary : AppColors.brandPrimary,
            backgroundColor: inverse ? Colors.black26 : null,
            disabledForegroundColor: AppColors.disabledForeground,
            elevation: 0,
            minimumSize: Size(fullWidth ? double.infinity : AppSpacing.minTouchTarget, height),
            side: BorderSide(
              color: _isEnabled ? (inverse ? AppColors.onPrimary : AppColors.brandPrimary) : AppColors.border,
              width: AppSpacing.borderWidthRegular,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.buttonRadius,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSubmitting) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  'Đang xử lý...',
                  style: AppTypography.button.copyWith(color: AppColors.brandPrimary),
                ),
              ] else ...[
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: AppSpacing.s8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.button.copyWith(
                      color: _isEnabled ? (inverse ? AppColors.onPrimary : AppColors.brandPrimary) : AppColors.disabledForeground,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon Action Button with mandatory min 48x48 touch target.
/// Used for bookmarks, share, call, chat, close, notifications.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.foregroundColor,
    this.badgeCount,
    this.backgroundColor,
    this.size = AppSpacing.minTouchTarget,
    this.iconSize = AppSpacing.iconRegular,
    this.isCircle = true,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? foregroundColor;
  final int? badgeCount;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final Color effectiveIconColor = isActive
        ? (activeColor ?? AppColors.brandPrimary)
        : (onPressed != null ? (foregroundColor ?? AppColors.textPrimary) : AppColors.disabledForeground);

    Widget content = Icon(
      icon,
      size: iconSize,
      color: effectiveIconColor,
    );

    if (badgeCount != null && badgeCount! > 0) {
      content = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          content,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badgeCount! > 99 ? '99+' : badgeCount.toString(),
                style: AppTypography.compact.copyWith(
                  color: AppColors.onPrimary,
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        shape: isCircle
            ? const CircleBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.thumbnail),
              ),
        child: InkWell(
          onTap: onPressed,
          customBorder: isCircle
              ? const CircleBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: size,
              minHeight: size,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
