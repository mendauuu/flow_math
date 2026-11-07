import 'dart:math';
import 'package:flutter/material.dart';

Color _a(Color c, double o) => c.withValues(alpha: o.clamp(0.0, 1.0));

// ─────────────────────────────────────────────────────────────────────────────
//  Focus timer styles
//  Each one shows the progress of a focus round (0 → 1) in its own way.
// ─────────────────────────────────────────────────────────────────────────────

class FocusVisual {
  final String id;
  final String name;
  final String emoji;

  /// width / height of the drawing.
  final double aspect;
  const FocusVisual(this.id, this.name, this.emoji, this.aspect);
}

const List<FocusVisual> kFocusVisuals = [
  FocusVisual('candle', 'Candle', '🕯️', 0.72),
  FocusVisual('hourglass', 'Hourglass', '⏳', 0.62),
  FocusVisual('campfire', 'Campfire', '🔥', 1.0),
  FocusVisual('moon', 'Moon rise', '🌙', 1.0),
  FocusVisual('minimal', 'Minimal', '◯', 1.0),
];

FocusVisual focusVisualById(String id) =>
    kFocusVisuals.firstWhere((v) => v.id == id, orElse: () => kFocusVisuals.first);

/// The painter for a timer style. [lit] is false while paused.
CustomPainter focusVisualPainter(
  String id, {
  required double progress,
  required double time,
  required Color color,
  bool lit = true,
}) =>
    switch (id) {
      'hourglass' =>
        HourglassPainter(progress: progress, time: time, color: color, lit: lit),
      'campfire' =>
        CampfirePainter(progress: progress, time: time, color: color, lit: lit),
      'moon' =>
        MoonPhasePainter(progress: progress, time: time, color: color, lit: lit),
      'minimal' =>
        RingPainter(progress: progress, time: time, color: color, lit: lit),
      _ => CandlePainter(burn: progress, time: time, glow: color, lit: lit),
    };

/// Sand runs from the top bulb into the bottom one.
class HourglassPainter extends CustomPainter {
  final double progress;
  final double time;
  final Color color;
  final bool lit;

  const HourglassPainter({
    required this.progress,
    required this.time,
    required this.color,
    this.lit = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final p = progress.clamp(0.0, 1.0);
    final top = h * 0.11;
    final bottom = h * 0.89;
    final mid = h * 0.5;
    final maxW = w * 0.33;
    final neck = w * 0.035;
    final sand = Color.lerp(color, const Color(0xFFEBD3A8), 0.45)!;

    // Warm glow
    final glowRect = Rect.fromCircle(center: Offset(cx, mid), radius: w * 0.75);
    canvas.drawCircle(
      glowRect.center,
      w * 0.75,
      Paint()
        ..shader = RadialGradient(colors: [
          _a(color, lit ? 0.16 : 0.07),
          Colors.transparent,
        ]).createShader(glowRect),
    );

    final glass = Path()
      ..moveTo(cx - maxW, top)
      ..lineTo(cx + maxW, top)
      ..cubicTo(cx + maxW, top + h * 0.22, cx + neck, mid - h * 0.08, cx + neck, mid)
      ..cubicTo(cx + neck, mid + h * 0.08, cx + maxW, bottom - h * 0.22, cx + maxW, bottom)
      ..lineTo(cx - maxW, bottom)
      ..cubicTo(cx - maxW, bottom - h * 0.22, cx - neck, mid + h * 0.08, cx - neck, mid)
      ..cubicTo(cx - neck, mid - h * 0.08, cx - maxW, top + h * 0.22, cx - maxW, top)
      ..close();

    canvas.drawPath(glass, Paint()..color = _a(Colors.white, 0.05));

    // Sand, clipped to the glass
    canvas.save();
    canvas.clipPath(glass);
    final sandPaint = Paint()..color = sand;
    // Top: what's left settles at the bottom of the upper bulb.
    final left = 1 - p;
    if (left > 0.005) {
      final y = mid - (mid - top) * 0.82 * left;
      final dip = min(h * 0.025, (mid - y) * 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..lineTo(cx - w * 0.06, y)
          ..lineTo(cx, y + dip)
          ..lineTo(cx + w * 0.06, y)
          ..lineTo(w, y)
          ..lineTo(w, mid)
          ..lineTo(0, mid)
          ..close(),
        sandPaint,
      );
    }
    // Bottom: a growing mound.
    final peakY = bottom - (bottom - mid) * 0.78 * p;
    final mound = h * 0.07 * p;
    canvas.drawPath(
      Path()
        ..moveTo(0, bottom)
        ..lineTo(0, peakY + mound)
        ..quadraticBezierTo(cx, peakY - mound * 0.6, w, peakY + mound)
        ..lineTo(w, bottom)
        ..close(),
      sandPaint,
    );
    // The falling stream
    if (lit && left > 0.005) {
      canvas.drawLine(Offset(cx, mid), Offset(cx, peakY),
          Paint()
            ..strokeWidth = 1.6
            ..color = _a(sand, 0.9));
      final grain = Paint()..color = sand;
      for (var i = 0; i < 4; i++) {
        final f = (time * 1.6 + i / 4) % 1.0;
        canvas.drawCircle(Offset(cx, mid + f * (peakY - mid)), 1.4, grain);
      }
    }
    canvas.restore();

    // Glass outline and highlight
    canvas.drawPath(
        glass,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _a(Colors.white, 0.35));
    canvas.drawLine(
        Offset(cx - maxW * 0.7, top + h * 0.04),
        Offset(cx - maxW * 0.55, top + h * 0.16),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = _a(Colors.white, 0.25));

    // Wooden frame
    final wood = Paint()..color = const Color(0xFF6B4A30);
    final woodLight = Paint()..color = const Color(0xFF8C6644);
    for (final y in [h * 0.04, h * 0.89]) {
      final cap = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.44, y, w * 0.88, h * 0.07),
          Radius.circular(h * 0.02));
      canvas.drawRRect(cap, wood);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - w * 0.44, y, w * 0.88, h * 0.018),
              Radius.circular(h * 0.01)),
          woodLight);
    }
    for (final x in [cx - w * 0.41, cx + w * 0.41]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(x, mid), width: w * 0.035, height: h * 0.8),
              Radius.circular(w * 0.02)),
          wood);
    }
  }

  @override
  bool shouldRepaint(HourglassPainter old) =>
      old.progress != progress ||
      old.time != time ||
      old.color != color ||
      old.lit != lit;
}

/// A campfire that slowly burns down to glowing embers.
class CampfirePainter extends CustomPainter {
  final double progress;
  final double time;
  final Color color;
  final bool lit;

  const CampfirePainter({
    required this.progress,
    required this.time,
    required this.color,
    this.lit = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final base = h * 0.80;
    final p = progress.clamp(0.0, 1.0);
    // Fire strength: big at the start, embers at the end, low while paused.
    final k = lit ? 1 - 0.72 * p : 0.22;

    // Light on the ground
    final groundRect = Rect.fromCenter(
        center: Offset(cx, base + h * 0.05), width: w * 1.1, height: h * 0.3);
    canvas.drawOval(
      groundRect,
      Paint()
        ..shader = RadialGradient(colors: [
          _a(const Color(0xFFFF9A4A), 0.28 * k + 0.05),
          Colors.transparent,
        ]).createShader(groundRect),
    );
    // Warm air
    final airRect =
        Rect.fromCircle(center: Offset(cx, base - h * 0.25), radius: w * 0.6);
    canvas.drawCircle(
      airRect.center,
      w * 0.6,
      Paint()
        ..shader = RadialGradient(colors: [
          _a(color, 0.18 * k),
          Colors.transparent,
        ]).createShader(airRect),
    );

    // Back stones
    _stones(canvas, w, h, cx, base, back: true);

    // Logs, crossed
    for (final angle in const [-0.32, 0.32]) {
      canvas.save();
      canvas.translate(cx, base);
      canvas.rotate(angle);
      final log = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w * 0.64, height: w * 0.1),
          Radius.circular(w * 0.05));
      canvas.drawRRect(log, Paint()..color = const Color(0xFF5A3A24));
      canvas.drawRRect(
          log,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _a(const Color(0xFFFF8A3D), 0.45 * k + 0.1),
                Colors.transparent,
              ],
            ).createShader(log.outerRect));
      for (final end in [-1.0, 1.0]) {
        final c = Offset(end * w * 0.3, 0);
        canvas.drawCircle(c, w * 0.045, Paint()..color = const Color(0xFF8A6A48));
        canvas.drawCircle(c, w * 0.022, Paint()..color = const Color(0xFF6B4A30));
      }
      canvas.restore();
    }

    // Embers on the logs
    final ember = Paint();
    final er = Random(4);
    for (var i = 0; i < 9; i++) {
      final x = cx + (er.nextDouble() - 0.5) * w * 0.4;
      final y = base - h * 0.01 + (er.nextDouble() - 0.5) * h * 0.05;
      final b = 0.5 + 0.5 * sin(time * (2 + i % 3) + i);
      ember.color = _a(const Color(0xFFFF7A2E), (0.35 + 0.5 * b) * (0.4 + k));
      canvas.drawCircle(Offset(x, y), w * 0.012, ember);
    }

    // Flames: two at the sides, one in the middle
    const flames = [(-0.12, 0.7, 0.20), (0.12, 0.75, 0.20), (0.0, 1.0, 0.27)];
    for (var i = 0; i < flames.length; i++) {
      final f = flames[i];
      final fh = h * 0.46 * k * f.$2 * (1 + 0.1 * sin(time * 6.3 + i * 2));
      final fw = w * f.$3 * (0.6 + 0.4 * k);
      final sway = sin(time * 2.3 + i) * w * 0.02;
      final bottomC = Offset(cx + w * f.$1, base - h * 0.03);
      _flame(canvas, bottomC, fw, fh, sway, outer: true);
      _flame(canvas, bottomC.translate(0, -fh * 0.02), fw * 0.55, fh * 0.6,
          sway * 0.7,
          outer: false);
    }

    // Sparks drifting up
    if (lit) {
      final spark = Paint();
      for (var i = 0; i < 8; i++) {
        final f = (time * 0.45 + i / 8) % 1.0;
        final y = base - h * 0.15 - f * h * 0.55 * (0.4 + k);
        final x = cx + sin(time * 1.7 + i * 1.3) * w * 0.14 * f + (i - 4) * w * 0.015;
        spark.color = _a(const Color(0xFFFFC27A), (1 - f) * 0.85 * k + 0.05);
        canvas.drawCircle(Offset(x, y), 1.4, spark);
      }
    }

    // Front stones
    _stones(canvas, w, h, cx, base, back: false);
  }

  void _flame(Canvas canvas, Offset bottom, double fw, double fh, double sway,
      {required bool outer}) {
    if (fh < 2) return;
    final tip = Offset(bottom.dx + sway, bottom.dy - fh);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(bottom.dx + fw * 0.9, bottom.dy - fh * 0.45, bottom.dx + fw * 0.6,
          bottom.dy, bottom.dx, bottom.dy)
      ..cubicTo(bottom.dx - fw * 0.6, bottom.dy, bottom.dx - fw * 0.9,
          bottom.dy - fh * 0.45, tip.dx, tip.dy)
      ..close();
    if (outer) {
      canvas.drawPath(
          path,
          Paint()
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.35)
            ..color = _a(const Color(0xFFFF8A3D), 0.45));
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: outer
              ? [
                  _a(const Color(0xFFFF6A2A), 0.95),
                  _a(const Color(0xFFFFA347), 0.9),
                  _a(const Color(0xFFFFD27A), 0.25),
                ]
              : [
                  _a(const Color(0xFFFFF4C8), 0.95),
                  _a(const Color(0xFFFFD98A), 0.8),
                  _a(const Color(0xFFFFB347), 0.1),
                ],
        ).createShader(path.getBounds()),
    );
  }

  void _stones(Canvas canvas, double w, double h, double cx, double base,
      {required bool back}) {
    final stone = Paint()..color = const Color(0xFF4A4038);
    final light = Paint()..color = const Color(0xFF6A5D50);
    for (var i = 0; i < 9; i++) {
      final a = pi * (i / 8);
      final isBack = sin(a) < 0.35;
      if (isBack != back) continue;
      final c = Offset(cx + cos(a) * w * 0.4, base + h * 0.05 + sin(a) * h * 0.06);
      final r = Rect.fromCenter(center: c, width: w * 0.13, height: h * 0.065);
      canvas.drawOval(r, stone);
      canvas.drawOval(
          Rect.fromLTWH(r.left + r.width * 0.2, r.top, r.width * 0.6, r.height * 0.35),
          light);
    }
  }

  @override
  bool shouldRepaint(CampfirePainter old) =>
      old.progress != progress ||
      old.time != time ||
      old.color != color ||
      old.lit != lit;
}

/// The moon grows from a thin crescent to full as the round goes on.
class MoonPhasePainter extends CustomPainter {
  final double progress;
  final double time;
  final Color color;
  final bool lit;

  const MoonPhasePainter({
    required this.progress,
    required this.time,
    required this.color,
    this.lit = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final r = min(size.width, size.height) * 0.34;
    final c = size.center(Offset(0, sin(time * 0.5) * 2));

    // Halo — brighter as the moon fills
    final haloRect = Rect.fromCircle(center: c, radius: r * 1.9);
    canvas.drawCircle(
      c,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(colors: [
          _a(color, (0.10 + 0.22 * p) * (lit ? 1 : 0.5)),
          Colors.transparent,
        ]).createShader(haloRect),
    );

    // Stars around
    final sr = Random(23);
    final star = Paint();
    for (var i = 0; i < 16; i++) {
      final a = sr.nextDouble() * 2 * pi;
      final d = r * (1.35 + sr.nextDouble() * 0.6);
      final b = 0.5 + 0.5 * sin(time * (1 + sr.nextDouble() * 2) + i);
      star.color = _a(Colors.white, 0.15 + 0.5 * b);
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * d, 0.8 + sr.nextDouble(), star);
    }

    // Dark side
    canvas.drawCircle(c, r, Paint()..color = _a(const Color(0xFF1A2236), 0.92));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _a(Colors.white, 0.14));

    // Lit side: right half + a terminator ellipse
    final f = 0.04 + 0.96 * p;
    final rect = Rect.fromCircle(center: c, radius: r);
    final rx = max(r * (1 - 2 * f).abs(), 0.5);
    final terminator = Rect.fromCenter(center: c, width: rx * 2, height: r * 2);
    final litPath = Path()
      ..moveTo(c.dx, c.dy - r)
      ..arcTo(rect, -pi / 2, pi, false)
      ..arcTo(terminator, pi / 2, f < 0.5 ? -pi : pi, false)
      ..close();
    canvas.drawPath(
      litPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, -0.3),
          colors: [
            _a(const Color(0xFFFFF4DA), lit ? 1 : 0.6),
            _a(const Color(0xFFE5D3AA), lit ? 1 : 0.6),
          ],
        ).createShader(rect),
    );
    // Craters on the lit part
    canvas.save();
    canvas.clipPath(litPath);
    final crater = Paint()..color = _a(const Color(0xFFC9B68C), 0.55);
    for (final cr in const [(0.35, -0.3, 0.16), (0.1, 0.35, 0.11), (0.55, 0.25, 0.08), (-0.3, -0.1, 0.12)]) {
      canvas.drawCircle(c + Offset(cr.$1 * r, cr.$2 * r), cr.$3 * r, crater);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MoonPhasePainter old) =>
      old.progress != progress ||
      old.time != time ||
      old.color != color ||
      old.lit != lit;
}

/// A quiet ring for distraction-free work.
class RingPainter extends CustomPainter {
  final double progress;
  final double time;
  final Color color;
  final bool lit;

  const RingPainter({
    required this.progress,
    required this.time,
    required this.color,
    this.lit = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) * 0.42;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _a(Colors.white, 0.07));
    if (p > 0) {
      canvas.drawArc(
          rect,
          -pi / 2,
          2 * pi * p,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = _a(color, lit ? 0.9 : 0.45));
    }
    // Leading dot breathes very softly
    final a = -pi / 2 + 2 * pi * p;
    final dot = c + Offset(cos(a), sin(a)) * r;
    final pulse = lit ? 0.5 + 0.5 * sin(time * 1.6) : 0.0;
    canvas.drawCircle(dot, 5 + 2 * pulse, Paint()..color = _a(color, 0.18));
    canvas.drawCircle(dot, 3.2, Paint()..color = _a(color, lit ? 1 : 0.5));
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress ||
      old.time != time ||
      old.color != color ||
      old.lit != lit;
}

/// A candle on a little brass plate. It burns down as [burn] goes 0 → 1,
/// with a softly flickering flame and a warm glow.
class CandlePainter extends CustomPainter {
  /// 0 = fresh candle … 1 = burnt down (a stub always remains).
  final double burn;

  /// Seconds — drives the flicker.
  final double time;

  /// False while paused: the flame shrinks and dims, waiting.
  final bool lit;

  final Color glow;

  const CandlePainter({
    required this.burn,
    required this.time,
    this.lit = true,
    this.glow = const Color(0xFFE8A27A),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final plateY = h * 0.90;

    final candleW = w * 0.24;
    final bodyH = h * 0.52 * (1 - 0.72 * burn.clamp(0.0, 1.0));
    final topY = plateY - bodyH;

    final flicker = lit
        ? 1 + 0.06 * sin(time * 7.3) + 0.04 * sin(time * 13.7 + 1.3)
        : 0.55;
    final flameH = h * 0.13 * flicker;
    final flameW = candleW * 0.42 * (lit ? 1 : 0.8);
    final sway = lit ? sin(time * 1.9) * 2.0 + sin(time * 5.1) * 0.8 : 0.0;
    final base = Offset(cx, topY - h * 0.018);
    final tip = Offset(cx + sway, base.dy - flameH);

    // Warm light filling the space around the flame
    final glowCenter = Offset(cx, base.dy - flameH * 0.4);
    final glowRect = Rect.fromCircle(center: glowCenter, radius: w * 0.6);
    canvas.drawCircle(
      glowCenter,
      w * 0.6,
      Paint()
        ..shader = RadialGradient(colors: [
          _a(glow, (lit ? 0.24 : 0.08) * flicker),
          Colors.transparent,
        ]).createShader(glowRect),
    );

    // Plate with a soft shadow
    final plate = Rect.fromCenter(
        center: Offset(cx, plateY), width: w * 0.62, height: h * 0.07);
    canvas.drawOval(
        plate.shift(Offset(0, h * 0.014)),
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03)
          ..color = _a(Colors.black, 0.45));
    canvas.drawOval(
      plate,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9A7650), Color(0xFF3E2C1E)],
        ).createShader(plate),
    );
    canvas.drawOval(
        plate.deflate(w * 0.035),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _a(const Color(0xFFD9B488), 0.35));

    // Candle body
    final body = Rect.fromLTWH(cx - candleW / 2, topY, candleW, bodyH);
    canvas.drawRRect(
      RRect.fromRectAndCorners(body,
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4)),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFCDB898),
            Color(0xFFF6EBD8),
            Color(0xFFE9DAC0),
            Color(0xFFBFA683),
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ).createShader(body),
    );
    // Flame light falling on the wax
    final lightRect = Rect.fromLTWH(body.left, topY, candleW, bodyH * 0.4);
    canvas.drawRect(
      lightRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_a(glow, lit ? 0.32 : 0.1), Colors.transparent],
        ).createShader(lightRect),
    );
    // Wax drips hanging from the rim
    final drip = Paint()..color = const Color(0xFFF5E9D3);
    for (final d in const [(-0.36, 0.22), (0.10, 0.34), (0.38, 0.15)]) {
      final x = cx + candleW * d.$1;
      final len = bodyH * d.$2 * 0.9;
      final dw = candleW * 0.11;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - dw / 2, topY, dw, len),
              Radius.circular(dw / 2)),
          drip);
    }
    // Top of the candle, with a glowing pool of melted wax
    final top = Rect.fromCenter(
        center: Offset(cx, topY), width: candleW, height: candleW * 0.28);
    canvas.drawOval(top, Paint()..color = const Color(0xFFF3E4C8));
    canvas.drawOval(
      top.deflate(candleW * 0.08),
      Paint()
        ..shader = RadialGradient(colors: [
          _a(glow, lit ? 0.6 : 0.15),
          const Color(0xFFE8D2AE),
        ]).createShader(top),
    );

    // Wick
    canvas.drawLine(
        Offset(cx, topY - 1),
        Offset(cx + sway * 0.15, base.dy + 2),
        Paint()
          ..color = const Color(0xFF2A1E16)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);

    // Flame
    final flame = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(base.dx + flameW * 0.9, base.dy - flameH * 0.45,
          base.dx + flameW * 0.55, base.dy + flameW * 0.35, base.dx,
          base.dy + flameW * 0.35)
      ..cubicTo(base.dx - flameW * 0.55, base.dy + flameW * 0.35,
          base.dx - flameW * 0.9, base.dy - flameH * 0.45, tip.dx, tip.dy)
      ..close();
    canvas.drawPath(
        flame,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, flameW * 0.6)
          ..color = _a(const Color(0xFFFFA545), lit ? 0.6 : 0.3));
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            _a(const Color(0xFF7FA0FF), 0.75),
            const Color(0xFFFFF3C4),
            const Color(0xFFFFB347),
            _a(const Color(0xFFFF8A3D), 0.6),
          ],
          stops: const [0.0, 0.25, 0.7, 1.0],
        ).createShader(flame.getBounds()),
    );
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(base.dx + sway * 0.3, base.dy - flameH * 0.22),
            width: flameW * 0.45,
            height: flameH * 0.38),
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
          ..color = _a(Colors.white, lit ? 0.85 : 0.5));

    // A few embers drifting up
    if (lit) {
      final ember = Paint();
      for (var i = 0; i < 5; i++) {
        final f = (time * 0.35 + i / 5) % 1.0;
        final y = tip.dy - f * h * 0.25;
        final x = cx + sin(time * 1.3 + i * 2) * w * 0.06 * f;
        ember.color = _a(const Color(0xFFFFC27A), (1 - f) * 0.6);
        canvas.drawCircle(Offset(x, y), 1.3, ember);
      }
    }
  }

  @override
  bool shouldRepaint(CandlePainter old) =>
      old.burn != burn ||
      old.time != time ||
      old.lit != lit ||
      old.glow != glow;
}

/// A warm mug of tea with curling steam — for breaks.
class TeaPainter extends CustomPainter {
  final double time;
  final Color glow;

  const TeaPainter({required this.time, this.glow = const Color(0xFFE8A27A)});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.46;
    final topY = h * 0.50;
    final bottomY = h * 0.84;
    final topW = w * 0.46;
    final bottomW = w * 0.40;

    // Glow
    final glowRect = Rect.fromCircle(center: Offset(cx, h * 0.62), radius: w * 0.6);
    canvas.drawCircle(
      glowRect.center,
      w * 0.6,
      Paint()
        ..shader = RadialGradient(
                colors: [_a(glow, 0.16), Colors.transparent])
            .createShader(glowRect),
    );

    // Saucer
    final saucer = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.865), width: w * 0.8, height: h * 0.09);
    canvas.drawOval(
        saucer.shift(Offset(0, h * 0.012)),
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03)
          ..color = _a(Colors.black, 0.4));
    canvas.drawOval(
      saucer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEDE3D3), Color(0xFFB3A690)],
        ).createShader(saucer),
    );

    // Handle (behind the body's right edge)
    final handle = Rect.fromCenter(
        center: Offset(cx + bottomW / 2 + w * 0.03, h * 0.66),
        width: w * 0.2,
        height: h * 0.18);
    canvas.drawArc(
        handle,
        -pi / 2,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.045
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFDCCFBA));

    // Mug body, slightly tapered
    final body = Path()
      ..moveTo(cx - topW / 2, topY)
      ..lineTo(cx + topW / 2, topY)
      ..lineTo(cx + bottomW / 2, bottomY - w * 0.04)
      ..quadraticBezierTo(cx + bottomW / 2, bottomY, cx + bottomW / 2 - w * 0.04, bottomY)
      ..lineTo(cx - bottomW / 2 + w * 0.04, bottomY)
      ..quadraticBezierTo(cx - bottomW / 2, bottomY, cx - bottomW / 2, bottomY - w * 0.04)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFD7CBB7),
            Color(0xFFF4ECDD),
            Color(0xFFE6DAC5),
            Color(0xFFB8AA92),
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ).createShader(body.getBounds()),
    );
    // Terracotta band
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
        Rect.fromLTWH(0, topY + (bottomY - topY) * 0.55, w, h * 0.035),
        Paint()..color = _a(const Color(0xFFC9785A), 0.85));
    canvas.restore();

    // Rim and tea
    final rim = Rect.fromCenter(
        center: Offset(cx, topY), width: topW, height: topW * 0.24);
    canvas.drawOval(rim, Paint()..color = const Color(0xFFF7F0E4));
    final tea = rim.deflate(topW * 0.05);
    canvas.drawOval(
      tea,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [const Color(0xFFB0744A), const Color(0xFF6E3F22)],
        ).createShader(tea),
    );

    // Steam: three soft wisps rising and curling
    for (var k = 0; k < 3; k++) {
      final x0 = cx + (k - 1) * topW * 0.24;
      final startY = topY - h * 0.03;
      final height = h * (0.30 + 0.05 * k);
      final path = Path()..moveTo(x0, startY);
      const steps = 24;
      for (var j = 1; j <= steps; j++) {
        final f = j / steps;
        final y = startY - f * height;
        final x = x0 + sin(f * 5 - time * 1.6 + k * 2.1) * w * 0.035 * (0.3 + f);
        path.lineTo(x, y);
      }
      final bounds = Rect.fromLTRB(x0 - w * 0.1, startY - height, x0 + w * 0.1, startY);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.028
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              _a(Colors.white, 0.28 + 0.06 * sin(time * 0.9 + k)),
              _a(Colors.white, 0.0),
            ],
          ).createShader(bounds),
      );
    }
  }

  @override
  bool shouldRepaint(TeaPainter old) => old.time != time || old.glow != glow;
}
