import 'package:flutter/material.dart';

/// Design tokens for colors based on brain/03_DESIGN_SPEC.md v1.2 and master plan.
/// All hex values follow the MP (Master Plan) and QU (Quy ước) specifications.
abstract final class AppColors {
  // Official Xland identity palette.
  static const Color brandLogoBackground = Color(0xFFF0F3E9);
  static const Color brandLeaf = Color(0xFF087455);
  static const Color brandLeafAccent = Color(0xFF349E72);
  static const Color brandWordmark = Color(0xFF063E33);

  // Master Plan (MP) tokens
  static const Color brandPrimary = Color(0xFF0F4C3A);
  static const Color background = Color(0xFFF7F6F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8E6DF);
  static const Color goldSurface = Color(0xFFF5EBD6);
  static const Color goldForeground = Color(0xFF9C6B20);
  static const Color verifiedSurface = Color(0xFFE6F2ED);
  static const Color verifiedForeground = Color(0xFF0F4C3A);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF999999);

  // Quy ước (QU) & Measured tokens
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color danger = Color(0xFFB8323B);
  static const Color dangerSurface = Color(0xFFFBEAEC);
  static const Color disabledSurface = Color(0xFFF0F0EC);
  static const Color disabledForeground = Color(0xFF999999);
  static const Color feedGold = Color(0xFFE4C37C);
  static const Color goldDecorative = Color(0xFFB49453);
  static const Color focusRing = Color(0xFF0F4C3A);

  // Overlay & Shadows
  static const Color overlayBase = Color(0xFF000000);
  static const Color mediaPillOverlay = Color(0x8F000000); // 56% opacity
  static const Color sheetScrim = Color(0x3D000000); // 24% opacity
  static const Color shadowBase = Color(0x0F000000); // 6% opacity

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000), // 0%
      Color(0x8F000000), // 56%
    ],
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F4C3A), Color(0xFF1B6B54)],
  );
}
