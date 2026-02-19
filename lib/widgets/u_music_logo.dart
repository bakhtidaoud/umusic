import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class UMusicLogo extends StatelessWidget {
  final double size;
  const UMusicLogo({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(painter: LogoPainter()),
    );
  }
}

class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final w = size.width;
    final h = size.height;

    // 1. Draw glowing background accent
    final bgGlow = RadialGradient(
      colors: [
        const Color(0xFF6366F1).withOpacity(0.2),
        const Color(0xFF8B5CF6).withOpacity(0.0),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: w * 0.8));

    canvas.drawCircle(center, w * 0.45, Paint()..shader = bgGlow);

    // 2. Draw the 'U' Shape
    final uPath = Path()
      ..moveTo(w * 0.3, h * 0.3)
      ..lineTo(w * 0.3, h * 0.55)
      ..arcToPoint(
        Offset(w * 0.7, h * 0.55),
        radius: Radius.circular(w * 0.2),
        clockwise: false,
      )
      ..lineTo(w * 0.7, h * 0.3)
      ..lineTo(w * 0.8, h * 0.3)
      ..lineTo(w * 0.8, h * 0.55)
      ..arcToPoint(
        Offset(w * 0.2, h * 0.55),
        radius: Radius.circular(w * 0.3),
        clockwise: false,
      )
      ..lineTo(w * 0.2, h * 0.3)
      ..close();

    final uGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF6366F1),
        const Color(0xFFA855F7),
        const Color(0xFFEC4899),
      ],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final uPaint = Paint()
      ..shader = uGradient
      ..style = PaintingStyle.fill;

    // Drawing U with a slight blur for glow
    canvas.drawPath(
      uPath,
      Paint()
        ..shader = uGradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(uPath, uPaint);

    // 3. Draw the Music Note integrated into the right stem
    final notePath = Path()
      ..moveTo(w * 0.7, h * 0.3)
      ..lineTo(w * 0.7, h * 0.15)
      ..quadraticBezierTo(w * 0.75, h * 0.1, w * 0.85, h * 0.15)
      ..lineTo(w * 0.85, h * 0.2)
      ..lineTo(w * 0.75, h * 0.2)
      ..lineTo(w * 0.75, h * 0.3)
      ..close();

    canvas.drawPath(notePath, uPaint);

    // 4. Glassmorphism Overlay (Subtle reflections)
    final glassPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawRect(
      Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.1, h * 0.05),
      glassPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
