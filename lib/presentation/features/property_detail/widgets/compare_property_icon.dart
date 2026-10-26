import 'package:flutter/material.dart';

/// A small magnifying glass with a legible "vs" inside its lens.
class ComparePropertyIcon extends StatelessWidget {
  const ComparePropertyIcon({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 26,
    child: CustomPaint(
      painter: _ComparePainter(IconTheme.of(context).color ?? Colors.black),
    ),
  );
}

class _ComparePainter extends CustomPainter {
  const _ComparePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 26, size.height / 26);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(10.5, 10.5), 8.5, paint);
    canvas.drawLine(const Offset(16.8, 16.8), const Offset(24, 24), paint);
    final text = TextPainter(
      text: TextSpan(
        text: 'vs',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(10.5 - text.width / 2, 10.5 - text.height / 2));
    text.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ComparePainter oldDelegate) => oldDelegate.color != color;
}
