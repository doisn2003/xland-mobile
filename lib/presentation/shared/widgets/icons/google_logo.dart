import 'package:flutter/material.dart';

/// Crisp vector Google "G" logo rendered via CustomPainter.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24.0;
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Blue (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(22.56 * s, 12.25 * s)
      ..cubicTo(22.56 * s, 11.47 * s, 22.49 * s, 10.72 * s, 22.36 * s, 10.0 * s)
      ..lineTo(12.0 * s, 10.0 * s)
      ..lineTo(12.0 * s, 14.26 * s)
      ..lineTo(17.92 * s, 14.26 * s)
      ..cubicTo(17.66 * s, 15.63 * s, 16.88 * s, 16.79 * s, 15.71 * s, 17.57 * s)
      ..lineTo(15.71 * s, 20.34 * s)
      ..lineTo(19.28 * s, 20.34 * s)
      ..cubicTo(21.36 * s, 18.42 * s, 22.56 * s, 15.6 * s, 22.56 * s, 12.25 * s)
      ..close();
    canvas.drawPath(bluePath, paint);

    // 2. Green (#34A853)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12.0 * s, 23.0 * s)
      ..cubicTo(14.97 * s, 23.0 * s, 17.46 * s, 22.02 * s, 19.28 * s, 20.34 * s)
      ..lineTo(15.71 * s, 17.57 * s)
      ..cubicTo(14.73 * s, 18.23 * s, 13.48 * s, 18.63 * s, 12.0 * s, 18.63 * s)
      ..cubicTo(9.14 * s, 18.63 * s, 6.71 * s, 16.7 * s, 5.84 * s, 14.1 * s)
      ..lineTo(2.18 * s, 14.1 * s)
      ..lineTo(2.18 * s, 16.94 * s)
      ..cubicTo(3.99 * s, 20.53 * s, 7.7 * s, 23.0 * s, 12.0 * s, 23.0 * s)
      ..close();
    canvas.drawPath(greenPath, paint);

    // 3. Yellow (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.84 * s, 14.09 * s)
      ..cubicTo(5.62 * s, 13.43 * s, 5.49 * s, 12.73 * s, 5.49 * s, 12.0 * s)
      ..cubicTo(5.49 * s, 11.27 * s, 5.62 * s, 10.57 * s, 5.84 * s, 9.91 * s)
      ..lineTo(5.84 * s, 7.06 * s)
      ..lineTo(2.18 * s, 7.06 * s)
      ..cubicTo(1.43 * s, 8.55 * s, 1.0 * s, 10.22 * s, 1.0 * s, 12.0 * s)
      ..cubicTo(1.0 * s, 13.78 * s, 1.43 * s, 15.45 * s, 2.18 * s, 16.94 * s)
      ..lineTo(5.03 * s, 14.72 * s)
      ..lineTo(5.84 * s, 14.09 * s)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 4. Red (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12.0 * s, 5.38 * s)
      ..cubicTo(13.62 * s, 5.38 * s, 15.06 * s, 5.94 * s, 16.21 * s, 7.02 * s)
      ..lineTo(19.36 * s, 3.87 * s)
      ..cubicTo(17.45 * s, 2.09 * s, 14.97 * s, 1.0 * s, 12.0 * s, 1.0 * s)
      ..cubicTo(7.7 * s, 1.0 * s, 3.99 * s, 3.47 * s, 2.18 * s, 7.06 * s)
      ..lineTo(5.84 * s, 9.9 * s)
      ..cubicTo(6.71 * s, 7.31 * s, 9.14 * s, 5.38 * s, 12.0 * s, 5.38 * s)
      ..close();
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
