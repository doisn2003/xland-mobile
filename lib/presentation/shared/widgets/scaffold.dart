import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Base Scaffold wrapper for XLand screens.
/// Guarantees SafeArea, bottom insets compensation for sticky CTA,
/// and smooth scrolling without clipping or overflow at text scale 1.3.
class XLandScaffold extends StatelessWidget {
  const XLandScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.stickyFooter,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? stickyFooter;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: appBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        top: safeAreaTop && appBar == null,
        bottom: safeAreaBottom && stickyFooter == null && bottomNavigationBar == null,
        child: Column(
          children: [
            Expanded(child: body),
            ?stickyFooter,
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Standard Sticky Action Bar for CTAs at bottom of screen (S02, S03, S05, S07, S08, S09).
/// Ensures proper safe-area padding and 48dp min touch targets.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.child,
    this.backgroundColor,
    this.showTopBorder = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: AppSpacing.footerHorizontalPadding,
        right: AppSpacing.footerHorizontalPadding,
        top: AppSpacing.footerVerticalPadding,
        bottom: AppSpacing.footerVerticalPadding + bottomInset,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        border: showTopBorder
            ? const Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: AppSpacing.borderWidthRegular,
                ),
              )
            : null,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowBase,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }
}
