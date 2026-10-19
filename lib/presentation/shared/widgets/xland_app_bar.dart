import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';
import 'xland_logo.dart';

enum XLandAppBarVariant { green, light }

/// Custom AppBar complying with XLand design spec.
/// Ensures min 48x48 touch targets for action buttons.
class XLandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const XLandAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.variant = XLandAppBarVariant.light,
    this.showBack = false,
    this.showLogo = false,
    this.onBack,
    this.actions,
    this.bottom,
  });

  final String? title;
  final String? subtitle;
  final XLandAppBarVariant variant;
  final bool showBack;
  final bool showLogo;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final double bottomHeight = bottom?.preferredSize.height ?? 0;
    final double baseHeight = subtitle != null
        ? 60.0
        : AppSpacing.appBarMinHeight;
    return Size.fromHeight(baseHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final isGreen = variant == XLandAppBarVariant.green;
    final backgroundColor = isGreen
        ? AppColors.brandPrimary
        : AppColors.surface;
    final foregroundColor = isGreen
        ? AppColors.onPrimary
        : AppColors.brandPrimary;

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      centerTitle: showLogo && showBack,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isGreen ? Brightness.light : Brightness.dark,
      ),
      leading: showBack
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: AppSpacing.iconRegular,
                color: foregroundColor,
              ),
              tooltip: 'Quay lại',
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : (showLogo
                ? Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.pageGutter),
                    child: Center(
                      child: XLandLogo(
                        variant: isGreen
                            ? XLandLogoVariant.onGreen
                            : XLandLogoVariant.onLight,
                      ),
                    ),
                  )
                : null),
      leadingWidth: showBack
          ? AppSpacing.minTouchTarget + 8
          : (showLogo ? 160 : null),
      title: title != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: AppTypography.appBarTitle.copyWith(
                    color: foregroundColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.compact.copyWith(
                      color: isGreen
                          ? AppColors.onPrimary.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            )
          : (showLogo && showBack
                ? XLandLogo(
                    variant: isGreen
                        ? XLandLogoVariant.onGreen
                        : XLandLogoVariant.onLight,
                  )
                : null),
      actions: actions != null
          ? [
              ...actions!.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s4),
                  child: action,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
            ]
          : null,
      bottom: bottom,
    );
  }
}
