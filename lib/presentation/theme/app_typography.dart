import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Design tokens for typography based on brain/03_DESIGN_SPEC.md v1.2.
/// Base font family is Roboto with full Vietnamese accent support.
abstract final class AppTypography {
  static const String fontFamily = 'Roboto';

  /// S03 4/6; S05 khoản vay chính (40 / 46, bold 700)
  static const TextStyle displayMetric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    height: 46 / 40,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Giá lớn S02 (36 / 42, bold 700)
  static const TextStyle priceHero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    height: 42 / 36,
    fontWeight: FontWeight.w700,
    color: AppColors.brandPrimary,
  );

  /// Khám phá; tên lô S02; tiêu đề sự kiện; tên tư vấn viên (28 / 34, bold 700)
  static const TextStyle pageHero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// S09 Tìm đất theo nhu cầu (26 / 32, bold 700)
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Giá grid S01, summary property, tổng trả tháng (24 / 30, bold 700)
  static const TextStyle priceCard = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    color: AppColors.brandPrimary,
  );

  /// Header S03–S08 (18 / 24, semi-bold 600)
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Tiến độ, chọn ngày, nội dung chương trình (18 / 24, semi-bold 600)
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Tên lô/diễn giả/tiện ích, giá trị thông số (16 / 22, semi-bold 600)
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Form, mô tả, địa chỉ (14 / 20, regular 400)
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Label quan trọng và tab (14 / 20, semi-bold 600)
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// CTA chính/phụ (16 / 22, semi-bold 600)
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    color: AppColors.onPrimary,
  );

  /// Metadata, caption, chip, badge, bottom nav (12 / 16, regular 400)
  static const TextStyle compact = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Chip selected, badge bold (12 / 16, medium 500 / semi-bold 600)
  static const TextStyle compactStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
