import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  const AnimatedBackground({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value; // 0.0 → 1.0 (ping-pong)
        return CustomPaint(
          painter: _BgPainter(t),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Base dark gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF080D18), Color(0xFF0A1520), Color(0xFF060E14)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Soft orbs that drift gently
    _drawOrb(canvas, size,
      cx: size.width * (0.2 + 0.15 * sin(t * pi)),
      cy: size.height * (0.25 + 0.08 * cos(t * pi)),
      radius: size.width * 0.45,
      color: const Color(0xFF0D3525),
      opacity: 0.5 + 0.15 * t,
    );

    _drawOrb(canvas, size,
      cx: size.width * (0.75 + 0.1 * cos(t * pi)),
      cy: size.height * (0.65 + 0.1 * sin(t * pi)),
      radius: size.width * 0.4,
      color: const Color(0xFF0A1E3A),
      opacity: 0.4 + 0.1 * t,
    );

    _drawOrb(canvas, size,
      cx: size.width * 0.5,
      cy: size.height * (0.45 + 0.05 * sin(t * pi * 2)),
      radius: size.width * 0.35,
      color: const Color(0xFF071820),
      opacity: 0.3,
    );
  }

  void _drawOrb(
    Canvas canvas, Size size, {
    required double cx,
    required double cy,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
      ..color = color.withOpacity(opacity.clamp(0.0, 1.0));
    canvas.drawCircle(Offset(cx, cy), radius, paint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}
