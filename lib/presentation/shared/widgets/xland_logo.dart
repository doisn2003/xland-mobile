import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

enum XLandLogoVariant { onGreen, onLight }

/// Compact navigation signature, using the original logo's vector outlines.
/// The surrounding surface selects the variant (see XLandAppBar); video uses
/// onGreen over its dark navigation pill. Neither variant paints a background.
class XLandLogo extends StatelessWidget {
  const XLandLogo({
    super.key,
    this.variant = XLandLogoVariant.onLight,
    this.height = 24,
  }) : assert(height > 0);

  final XLandLogoVariant variant;

  /// Visible symbol height, without the launcher icon's safe-area padding.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Xland',
      image: true,
      child: SizedBox(
        height: height,
        width: height * _CompactLogoPainter.aspectRatio,
        child: CustomPaint(painter: _CompactLogoPainter(variant)),
      ),
    );
  }
}

class _CompactLogoPainter extends CustomPainter {
  const _CompactLogoPainter(this.variant);

  final XLandLogoVariant variant;
  static const _gap = .28;
  static const _wordmarkHeight = .78;
  static const _wordmarkWidth = 409.65;
  static const _wordmarkSourceHeight = 115.5;
  static const aspectRatio =
      1 + _gap + _wordmarkHeight * _wordmarkWidth / _wordmarkSourceHeight;

  // Paths transcribed from the supplied symbol.svg and logo-lockup.svg.
  // Subtracting the vein makes it transparent on every surrounding surface.
  static final _leaf = Path.combine(
    PathOperation.difference,
    Path()
      ..moveTo(488, 488)
      ..cubicTo(314, 516, 236, 400, 258, 258)
      ..cubicTo(400, 236, 516, 314, 488, 488)
      ..close(),
    Path()
      ..moveTo(488, 488)
      ..cubicTo(395, 427, 330, 345, 258, 258)
      ..cubicTo(333, 360, 402, 443, 488, 488)
      ..close(),
  );

  // Keep the supplied lettering, including its proportions and kerning.
  static final _wordmark = Path()
    ..moveTo(307.65, 189)
    ..lineTo(342.45, 133.5)
    ..lineTo(307.65, 78)
    ..lineTo(331.95, 78)
    ..lineTo(356.4, 118.5)
    ..lineTo(381, 78)
    ..lineTo(405.15, 78)
    ..lineTo(370.05, 133.5)
    ..lineTo(405.3, 189)
    ..lineTo(381, 189)
    ..lineTo(356.4, 148.5)
    ..lineTo(331.95, 189)
    ..close()
    ..moveTo(420.75, 189)
    ..lineTo(420.9, 75)
    ..lineTo(440.7, 75)
    ..lineTo(440.7, 189)
    ..close()
    ..moveTo(491.85, 108)
    ..quadraticBezierTo(499.5, 108, 504.45, 110.475)
    ..quadraticBezierTo(509.4, 112.95, 512.25, 115.875)
    ..quadraticBezierTo(515.1, 118.8, 516.15, 120.60000000000001)
    ..lineTo(517.05, 120.60000000000001)
    ..lineTo(517.05, 109.5)
    ..lineTo(537, 109.5)
    ..lineTo(537, 189)
    ..lineTo(517.05, 189)
    ..lineTo(517.05, 177.9)
    ..lineTo(516.15, 177.9)
    ..quadraticBezierTo(515.1, 179.7, 512.25, 182.7)
    ..quadraticBezierTo(509.4, 185.7, 504.45, 188.1)
    ..quadraticBezierTo(499.5, 190.5, 491.85, 190.5)
    ..quadraticBezierTo(483, 190.5, 476.4, 186.975)
    ..quadraticBezierTo(469.8, 183.45, 465.375, 177.52499999999998)
    ..quadraticBezierTo(460.95, 171.6, 458.775, 164.25)
    ..quadraticBezierTo(456.6, 156.9, 456.6, 149.25)
    ..quadraticBezierTo(456.6, 141.6, 458.775, 134.25)
    ..quadraticBezierTo(460.95, 126.9, 465.375, 120.975)
    ..quadraticBezierTo(469.8, 115.05, 476.4, 111.525)
    ..quadraticBezierTo(483, 108, 491.85, 108)
    ..close()
    ..moveTo(497.1, 124.35000000000001)
    ..quadraticBezierTo(490.35, 124.35000000000001, 485.775, 128.025)
    ..quadraticBezierTo(481.2, 131.7, 478.95, 137.39999999999998)
    ..quadraticBezierTo(476.7, 143.1, 476.7, 149.25)
    ..quadraticBezierTo(476.7, 155.4, 478.95, 161.10000000000002)
    ..quadraticBezierTo(481.2, 166.8, 485.775, 170.47500000000002)
    ..quadraticBezierTo(490.35, 174.15, 497.1, 174.15)
    ..quadraticBezierTo(503.85, 174.15, 508.35, 170.47500000000002)
    ..quadraticBezierTo(512.85, 166.8, 515.1, 161.10000000000002)
    ..quadraticBezierTo(517.35, 155.4, 517.35, 149.25)
    ..quadraticBezierTo(517.35, 143.1, 515.1, 137.39999999999998)
    ..quadraticBezierTo(512.85, 131.7, 508.35, 128.025)
    ..quadraticBezierTo(503.85, 124.35000000000001, 497.1, 124.35000000000001)
    ..close()
    ..moveTo(552.5999999999999, 189)
    ..lineTo(552.5999999999999, 109.5)
    ..lineTo(572.55, 109.5)
    ..lineTo(572.55, 120.9)
    ..lineTo(573.4499999999999, 120.9)
    ..quadraticBezierTo(574.65, 118.8, 577.2, 115.725)
    ..quadraticBezierTo(579.75, 112.65, 584.25, 110.325)
    ..quadraticBezierTo(588.75, 108, 595.65, 108)
    ..quadraticBezierTo(604.8, 108, 610.7249999999999, 112.125)
    ..quadraticBezierTo(616.65, 116.25, 619.575, 123)
    ..quadraticBezierTo(622.5, 129.75, 622.5, 137.55)
    ..lineTo(622.5, 189)
    ..lineTo(602.55, 189)
    ..lineTo(602.55, 140.25)
    ..quadraticBezierTo(602.55, 133.8, 598.9499999999999, 129.15)
    ..quadraticBezierTo(595.3499999999999, 124.5, 588.15, 124.5)
    ..quadraticBezierTo(582.5999999999999, 124.5, 579.1499999999999, 127.275)
    ..quadraticBezierTo(575.6999999999999, 130.05, 574.125, 134.4)
    ..quadraticBezierTo(572.55, 138.75, 572.55, 143.55)
    ..lineTo(572.55, 189)
    ..close()
    ..moveTo(672.15, 190.5)
    ..quadraticBezierTo(663.3, 190.5, 656.6999999999999, 186.975)
    ..quadraticBezierTo(650.0999999999999, 183.45, 645.675, 177.52499999999998)
    ..quadraticBezierTo(641.25, 171.6, 639.075, 164.25)
    ..quadraticBezierTo(636.9, 156.9, 636.9, 149.25)
    ..quadraticBezierTo(636.9, 141.6, 639.075, 134.25)
    ..quadraticBezierTo(641.25, 126.9, 645.675, 120.975)
    ..quadraticBezierTo(650.0999999999999, 115.05, 656.6999999999999, 111.525)
    ..quadraticBezierTo(663.3, 108, 672.15, 108)
    ..quadraticBezierTo(679.8, 108, 684.75, 110.475)
    ..quadraticBezierTo(689.6999999999999, 112.95, 692.55, 115.875)
    ..quadraticBezierTo(695.4, 118.8, 696.4499999999999, 120.60000000000001)
    ..lineTo(697.3499999999999, 120.60000000000001)
    ..lineTo(697.3499999999999, 75)
    ..lineTo(717.3, 75)
    ..lineTo(717.3, 189)
    ..lineTo(697.3499999999999, 189)
    ..lineTo(697.3499999999999, 177.9)
    ..lineTo(696.4499999999999, 177.9)
    ..quadraticBezierTo(695.4, 179.7, 692.55, 182.7)
    ..quadraticBezierTo(689.6999999999999, 185.7, 684.75, 188.1)
    ..quadraticBezierTo(679.8, 190.5, 672.15, 190.5)
    ..close()
    ..moveTo(677.4, 174.15)
    ..quadraticBezierTo(684.15, 174.15, 688.65, 170.47500000000002)
    ..quadraticBezierTo(693.15, 166.8, 695.4, 161.10000000000002)
    ..quadraticBezierTo(697.65, 155.4, 697.65, 149.25)
    ..quadraticBezierTo(697.65, 143.1, 695.4, 137.39999999999998)
    ..quadraticBezierTo(693.15, 131.7, 688.65, 128.025)
    ..quadraticBezierTo(684.15, 124.35000000000001, 677.4, 124.35000000000001)
    ..quadraticBezierTo(670.65, 124.35000000000001, 666.075, 128.025)
    ..quadraticBezierTo(661.5, 131.7, 659.25, 137.39999999999998)
    ..quadraticBezierTo(657, 143.1, 657, 149.25)
    ..quadraticBezierTo(657, 155.4, 659.25, 161.10000000000002)
    ..quadraticBezierTo(661.5, 166.8, 666.075, 170.47500000000002)
    ..quadraticBezierTo(670.65, 174.15, 677.4, 174.15)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final monochrome = variant == XLandLogoVariant.onGreen;
    final paint = Paint()..isAntiAlias = true;
    final height = size.height;

    canvas.save();
    // Tight symbol viewport: remove the app icon's large external padding.
    canvas.scale(height / 520);
    canvas.translate(-252, -252);
    for (var leaf = 0; leaf < 4; leaf++) {
      paint.color = monochrome
          ? AppColors.onPrimary
          : (leaf.isEven ? AppColors.brandLeaf : AppColors.brandLeafAccent);
      canvas.save();
      canvas.translate(512, 512);
      canvas.rotate(leaf * math.pi / 2);
      canvas.translate(-512, -512);
      canvas.drawPath(_leaf, paint);
      canvas.restore();
    }
    canvas.restore();

    canvas.save();
    canvas.translate(height * (1 + _gap), height * (1 - _wordmarkHeight) / 2);
    final scale = height * _wordmarkHeight / _wordmarkSourceHeight;
    canvas.scale(scale);
    canvas.translate(-307.65, -75);
    paint.color = monochrome ? AppColors.onPrimary : AppColors.brandWordmark;
    canvas.drawPath(_wordmark, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompactLogoPainter oldDelegate) =>
      variant != oldDelegate.variant;
}
