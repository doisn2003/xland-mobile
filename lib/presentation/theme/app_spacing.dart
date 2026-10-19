/// Spacing, geometry, and layout scale based on brain/03_DESIGN_SPEC.md v1.2.
abstract final class AppSpacing {
  // Spacing scale
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;

  // Semantic layout padding
  static const double pageGutter = 12.0;
  static const double pageGutterText = 16.0;
  static const double cardPadding = 12.0;
  static const double cardPaddingLarge = 16.0;

  // Semantic gaps
  static const double gapGrid = 8.0;
  static const double gapSection = 16.0;
  static const double gapSectionLarge = 24.0;
  static const double gapControl = 8.0;
  static const double gapHelper = 4.0;

  // Component Heights & Hit targets
  static const double minTouchTarget = 48.0;
  static const double ctaMinHeight = 48.0;
  static const double inputMinHeight = 48.0;
  static const double chipVisualHeight = 32.0;
  static const double iconButtonHitArea = 48.0;
  static const double tabBarMinHeight = 44.0;
  static const double appBarMinHeight = 48.0;
  static const double bottomNavMinHeight = 64.0;

  // Sticky footer padding
  static const double footerHorizontalPadding = 12.0;
  static const double footerVerticalPadding = 8.0;

  // Avatar sizes
  static const double avatarSmall = 40.0;
  static const double avatarMedium = 56.0;
  static const double avatarProfile = 104.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconRegular = 24.0;
  static const double iconLarge = 28.0;

  // Borders
  static const double borderWidthRegular = 1.0;
  static const double borderWidthSelected = 2.0;
  static const double borderWidthFocus = 2.0;
}
