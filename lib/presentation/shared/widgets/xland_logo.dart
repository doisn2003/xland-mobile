import 'package:flutter/material.dart';

import '../../theme/theme.dart';

enum XLandLogoVariant { onGreen, onLight }

/// Vector artwork stays crisp at every device scale, including the feed badge.
class XLandLogo extends StatelessWidget {
  const XLandLogo({
    super.key,
    this.variant = XLandLogoVariant.onLight,
    this.height = 28,
    this.showSlogan = false,
  });
  final XLandLogoVariant variant;
  final double height;
  final bool showSlogan;

  @override
  Widget build(BuildContext context) {
    final color = variant == XLandLogoVariant.onGreen
        ? AppColors.onPrimary
        : AppColors.brandPrimary;
    return Semantics(
      label: 'XLand',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size(height * .92, height),
              painter: _XMark(color),
            ),
            SizedBox(width: height * .12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'XLand',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: color,
                    fontSize: height * .78,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -.7,
                  ),
                ),
                if (showSlogan)
                  Text(
                    'BẤT ĐỘNG SẢN THỰC ĐỊA',
                    style: TextStyle(
                      color: color,
                      fontSize: 7,
                      letterSpacing: .6,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _XMark extends CustomPainter {
  const _XMark(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 36);
    final gold = Paint()..color = AppColors.goldDecorative;
    final ink = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(1, 0)
        ..lineTo(6, 0)
        ..lineTo(29, 36)
        ..lineTo(24, 36)
        ..close(),
      gold,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8, 0)
        ..lineTo(11, 0)
        ..lineTo(32, 33)
        ..lineTo(32, 36)
        ..lineTo(31, 36)
        ..close(),
      gold,
    );
    canvas.drawPath(
      Path()
        ..moveTo(25, 0)
        ..lineTo(31, 0)
        ..lineTo(8, 36)
        ..lineTo(2, 36)
        ..close(),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(20, 0)
        ..lineTo(23, 0)
        ..lineTo(1, 35)
        ..lineTo(0, 35)
        ..lineTo(0, 31)
        ..close(),
      ink,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_XMark oldDelegate) => color != oldDelegate.color;
}
