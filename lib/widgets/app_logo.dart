import 'package:flutter/material.dart';

/// Presensi Magang brand mark. Shared by the UI and native asset generator.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Logo magang presensi bps Batu',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: AppLogoPainter()),
    ),
  );
}

class AppLogoPainter extends CustomPainter {
  const AppLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 128);
    final pin = Path()
      ..moveTo(64, 14)
      ..cubicTo(40, 14, 24, 31, 24, 53)
      ..cubicTo(24, 78, 49, 102, 60, 112)
      ..quadraticBezierTo(64, 116, 68, 112)
      ..cubicTo(79, 102, 104, 78, 104, 53)
      ..cubicTo(104, 31, 88, 14, 64, 14)
      ..close();
    canvas.drawPath(
      pin,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3984F5), Color(0xFF2455CB)],
        ).createShader(const Rect.fromLTWH(24, 14, 80, 102)),
    );
    final check = Path()
      ..moveTo(45, 55)
      ..lineTo(59, 69)
      ..lineTo(84, 43);
    canvas.drawPath(
      check,
      Paint()
        ..color = const Color(0xFFAEF5D2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AppLogoPainter oldDelegate) => false;
}
