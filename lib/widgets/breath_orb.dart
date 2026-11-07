import 'dart:math';
import 'package:flutter/material.dart';

/// The meditation breathing guide: a big glowing orb that swells on the
/// in-breath and softens on the out-breath, with ripples flowing outward
/// and a thin ring that fills as the session goes on.
class BreathOrbPainter extends CustomPainter {
  /// 0 = empty lungs (small orb) … 1 = full breath (orb fills the ring).
  final double breath;

  /// 0–1, how much of the session ring is filled.
  final double progress;

  /// Seconds — drives ripples and the drifting motes.
  final double time;

  final Color accent;

  /// Sparkles around the orb when a session is completed.
  final bool bloom;

  const BreathOrbPainter({
    required this.breath,
    required this.progress,
    required this.time,
    required this.accent,
    this.bloom = false,
  });

  static Color _a(Color c, double o) => c.withValues(alpha: o.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final b = breath.clamp(0.0, 1.0);
    _ring(canvas, c, outer - 3);

    final maxR = outer - 12;
    final r = maxR * (0.40 + 0.60 * b); // big, obvious change in size
    final rect = Rect.fromCircle(center: c, radius: r);
    final light = Color.lerp(accent, Colors.white, 0.55)!;

    // Ripples flowing outward from the orb
    final ripple = Paint()..style = PaintingStyle.stroke;
    for (var k = 0; k < 3; k++) {
      final f = (time / 3.6 + k / 3) % 1.0;
      ripple
        ..strokeWidth = 1.5
        ..color = _a(accent, (1 - f) * (0.10 + 0.14 * b));
      canvas.drawCircle(c, r * (1 + 0.28 * f), ripple);
    }

    // Halo — brightens as the lungs fill
    canvas.drawCircle(
        c,
        r * 1.35,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35)
          ..color = _a(accent, 0.12 + 0.28 * b));

    // Body, in soft layers for depth
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.25),
          colors: [
            _a(accent, 0.55 * (0.6 + 0.4 * b)),
            _a(accent, 0.22),
            _a(accent, 0.06),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
        c,
        r * 0.72,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08)
          ..color = _a(accent, 0.10 + 0.10 * b));
    canvas.drawCircle(
        c,
        r * 0.44,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.10)
          ..color = _a(light, 0.10 + 0.12 * b));

    // Rim
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _a(Colors.white, 0.18 + 0.12 * b));

    // A few motes circling slowly around the rim
    final mote = Paint();
    for (var i = 0; i < 6; i++) {
      final ang = time * 0.35 + i * 2 * pi / 6;
      mote.color = _a(light, 0.4 + 0.3 * sin(time * 2 + i));
      canvas.drawCircle(c + Offset(cos(ang), sin(ang)) * r * 1.07, 1.8, mote);
    }

    if (bloom) _sparkles(canvas, c, r);
  }

  void _ring(Canvas canvas, Offset c, double radius) {
    canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _a(Colors.white, 0.07));
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    final rect = Rect.fromCircle(center: c, radius: radius);
    final sweep = 2 * pi * p;
    canvas.drawArc(
      rect,
      -pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [_a(accent, 0.25), accent],
          stops: [0.0, max(p, 0.001)],
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect),
    );
    final end = c + Offset(cos(-pi / 2 + sweep), sin(-pi / 2 + sweep)) * radius;
    canvas.drawCircle(
        end,
        7,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..color = _a(accent, 0.6));
    canvas.drawCircle(end, 3.2, Paint()..color = Colors.white);
  }

  void _sparkles(Canvas canvas, Offset c, double r) {
    final rnd = Random(11);
    for (var i = 0; i < 12; i++) {
      final ang = rnd.nextDouble() * 2 * pi;
      final dist = r * (1.05 + rnd.nextDouble() * 0.3);
      final ph = rnd.nextDouble() * 2 * pi;
      final speed = 1.5 + rnd.nextDouble() * 2;
      final b = (sin(time * speed + ph) + 1) / 2;
      final p = c + Offset(cos(ang), sin(ang)) * dist;
      final l = 2 + 4 * b;
      final paint = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = _a(Colors.white, 0.75 * b);
      canvas.drawLine(p.translate(-l, 0), p.translate(l, 0), paint);
      canvas.drawLine(p.translate(0, -l), p.translate(0, l), paint);
    }
  }

  @override
  bool shouldRepaint(BreathOrbPainter old) =>
      old.breath != breath ||
      old.progress != progress ||
      old.time != time ||
      old.accent != accent ||
      old.bloom != bloom;
}
