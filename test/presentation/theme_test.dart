import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/presentation/theme/theme.dart';

void main() {
  group('Theme Tokens & Specifications', () {
    test('AppColors MP values are exactly pinned', () {
      expect(AppColors.brandPrimary, const Color(0xFF0F4C3A));
      expect(AppColors.background, const Color(0xFFF7F6F2));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.border, const Color(0xFFE8E6DF));
      expect(AppColors.goldSurface, const Color(0xFFF5EBD6));
      expect(AppColors.goldForeground, const Color(0xFF9C6B20));
      expect(AppColors.verifiedSurface, const Color(0xFFE6F2ED));
      expect(AppColors.textPrimary, const Color(0xFF1A1A1A));
      expect(AppColors.textSecondary, const Color(0xFF666666));
      expect(AppColors.textMuted, const Color(0xFF999999));
    });

    test('AppSpacing scale conforms to 4, 8, 12, 16, 20, 24, 32 and min touch target 48', () {
      expect(AppSpacing.s4, 4.0);
      expect(AppSpacing.s8, 8.0);
      expect(AppSpacing.s12, 12.0);
      expect(AppSpacing.s16, 16.0);
      expect(AppSpacing.s20, 20.0);
      expect(AppSpacing.s24, 24.0);
      expect(AppSpacing.s32, 32.0);
      expect(AppSpacing.minTouchTarget, 48.0);
      expect(AppSpacing.ctaMinHeight, 48.0);
    });

    test('AppRadius tokens conform to 12, 16, 8, 24, 999', () {
      expect(AppRadius.card, 12.0);
      expect(AppRadius.cardLarge, 16.0);
      expect(AppRadius.thumbnail, 8.0);
      expect(AppRadius.sheetTop, 24.0);
      expect(AppRadius.pill, 999.0);
    });

    test('AppTypography has Roboto font family and required font sizes', () {
      expect(AppTypography.fontFamily, 'Roboto');
      expect(AppTypography.displayMetric.fontSize, 40.0);
      expect(AppTypography.priceHero.fontSize, 36.0);
      expect(AppTypography.pageHero.fontSize, 28.0);
      expect(AppTypography.cardTitle.fontSize, 16.0);
      expect(AppTypography.body.fontSize, 14.0);
      expect(AppTypography.compact.fontSize, 12.0);
    });

    test('AppTheme.lightTheme initializes with brandPrimary and background', () {
      final theme = AppTheme.lightTheme;
      expect(theme.primaryColor, AppColors.brandPrimary);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.useMaterial3, true);
    });
  });
}
