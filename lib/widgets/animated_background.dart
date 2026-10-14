import 'dart:math';
import 'package:flutter/material.dart';

/// Wild forest night with theme variants: 'forest' | 'ocean' | 'desert'
class AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  final String theme;
  const AnimatedBackground(
      {super.key, required this.controller, this.theme = 'forest'});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _NaturePainter(controller.value, theme),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NaturePainter extends CustomPainter {
  final double t;
  final String theme;
  _NaturePainter(this.t, this.theme);

  // ── Theme palettes ──────────────────────────────────────────────────────
  Color get _skyTop => theme == 'ocean'
      ? const Color(0xFF010812)
      : theme == 'desert'
          ? const Color(0xFF0C0810)
          : const Color(0xFF010609);
  Color get _skyBottom => theme == 'ocean'
      ? const Color(0xFF061525)
      : theme == 'desert'
          ? const Color(0xFF1A100A)
          : const Color(0xFF071A28);
  Color get _mistColor => theme == 'ocean'
      ? const Color(0xFF4A7FA8)
      : theme == 'desert'
          ? const Color(0xFFB8906A)
          : const Color(0xFF5A9A78);
  Color get _moonColor => theme == 'ocean'
      ? const Color(0xFFCCE8FF)
      : theme == 'desert'
          ? const Color(0xFFFFE8CC)
          : const Color(0xFFE8F5EE);
  Color get _moonHalo => theme == 'ocean'
      ? const Color(0xFF1A3A5A)
      : theme == 'desert'
          ? const Color(0xFF5A3A1A)
          : const Color(0xFF1E4A30);
  Color get _treeBack =>
      theme == 'desert' ? const Color(0xFF1A1008) : const Color(0xFF0C2018);
  Color get _treeMid =>
      theme == 'desert' ? const Color(0xFF120B05) : const Color(0xFF081610);
  Color get _treeFront =>
      theme == 'desert' ? const Color(0xFF0A0703) : const Color(0xFF040E08);
  Color get _ground =>
      theme == 'desert' ? const Color(0xFF0D0805) : const Color(0xFF030A05);
  Color get _fireflyColor =>
      theme == 'desert' ? const Color(0xFFFFD080) : const Color(0xFFA8FF60);
  Color get _fireflyCore =>
      theme == 'desert' ? const Color(0xFFFFE8A0) : const Color(0xFFD0FF99);

  @override
  void paint(Canvas canvas, Size sz) {
    _sky(canvas, sz);
    _stars(canvas, sz);
    _moon(canvas, sz);
    _mist(canvas, sz);
    _trees(canvas, sz);
    _fireflies(canvas, sz);
    _vignette(canvas, sz);
  }

  void _sky(Canvas canvas, Size sz) {
    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _skyTop,
              _skyBottom.withBlue((_skyBottom.blue * 0.6).round())
            ],
            stops: const [0.0, 1.0],
          ).createShader(Offset.zero & sz));
  }

  void _stars(Canvas canvas, Size sz) {
    final r = Random(17);
    for (int i = 0; i < 85; i++) {
      final phase = r.nextDouble() * 2 * pi;
      final b = (sin(t * pi * 2 + phase) + 1) / 2;
      canvas.drawCircle(
        Offset(r.nextDouble() * sz.width, r.nextDouble() * sz.height * 0.55),
        0.5 + r.nextDouble() * 1.0,
        Paint()..color = Colors.white.withOpacity(b * 0.68 * r.nextDouble()),
      );
    }
  }

  void _moon(Canvas canvas, Size sz) {
    final cx = sz.width * 0.73;
    final cy = sz.height * 0.14 + sz.height * 0.025 * sin(t * pi);
    final pulse = 0.92 + 0.08 * sin(t * pi * 2);

    canvas.drawCircle(
        Offset(cx, cy),
        sz.width * 0.38,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
          ..color = _moonHalo.withOpacity(0.10 * pulse));
    canvas.drawCircle(
        Offset(cx, cy),
        sz.width * 0.15,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
          ..color = _moonHalo.withOpacity(0.22 * pulse));
    canvas.drawCircle(
        Offset(cx, cy),
        27,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..color = _moonColor.withOpacity(0.75 * pulse));
    canvas.drawCircle(
        Offset(cx, cy), 20, Paint()..color = _moonColor.withOpacity(pulse));
  }

  void _mist(Canvas canvas, Size sz) {
    for (final m in [
      (0.54, 0.055, 22.0),
      (0.61, 0.085, 32.0),
      (0.68, 0.065, 26.0),
      (0.74, 0.040, 18.0),
    ]) {
      final yOff = sz.height * 0.018 * sin(t * pi + m.$1 * 6);
      final y = sz.height * m.$1 + yOff;
      canvas.drawRect(
          Rect.fromLTWH(0, y - 35, sz.width, 70),
          Paint()
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.$3)
            ..shader = LinearGradient(colors: [
              Colors.transparent,
              _mistColor.withOpacity(m.$2),
              Colors.transparent,
            ]).createShader(Rect.fromLTWH(0, y - 35, sz.width, 70)));
    }
  }

  void _trees(Canvas canvas, Size sz) {
    _layer(canvas, sz, 0.73, 0.17, _treeBack, 24, 7);
    _layer(canvas, sz, 0.79, 0.22, _treeMid, 19, 3);
    _layer(canvas, sz, 0.86, 0.30, _treeFront, 14, 11);
    canvas.drawRect(
        Rect.fromLTWH(0, sz.height * 0.89, sz.width, sz.height * 0.11),
        Paint()..color = _ground);
  }

  void _layer(Canvas canvas, Size sz, double yFrac, double hFrac, Color color,
      int count, int seed) {
    final r = Random(seed);
    final p = Paint()..color = color;
    final step = sz.width / count;
    for (int i = 0; i < count; i++) {
      final x = i * step + r.nextDouble() * step * 0.7;
      final h = sz.height * hFrac * (0.65 + r.nextDouble() * 0.70);
      final w = h * (0.25 + r.nextDouble() * 0.12);
      final yb = sz.height * yFrac;

      if (theme == 'desert') {
        // Cactus-like silhouette
        canvas.drawRect(Rect.fromLTWH(x - w * 0.12, yb - h, w * 0.24, h), p);
        canvas.drawRect(
            Rect.fromLTWH(x - w * 0.4, yb - h * 0.55, w * 0.28, h * 0.18), p);
        canvas.drawRect(
            Rect.fromLTWH(x + w * 0.12, yb - h * 0.45, w * 0.28, h * 0.18), p);
      } else {
        // Pine tree
        canvas.drawPath(
            Path()
              ..moveTo(x, yb - h)
              ..lineTo(x - w / 2, yb)
              ..lineTo(x + w / 2, yb)
              ..close(),
            p);
        canvas.drawPath(
            Path()
              ..moveTo(x, yb - h * .72)
              ..lineTo(x - w * .62, yb - h * .28)
              ..lineTo(x + w * .62, yb - h * .28)
              ..close(),
            p);
        canvas.drawPath(
            Path()
              ..moveTo(x, yb - h * .45)
              ..lineTo(x - w * .45, yb - h * .10)
              ..lineTo(x + w * .45, yb - h * .10)
              ..close(),
            p);
      }
    }
  }

  void _fireflies(Canvas canvas, Size sz) {
    final r = Random(99);
    for (int i = 0; i < 22; i++) {
      final phase = r.nextDouble() * 2 * pi;
      final b = (sin(t * pi * 3 + phase) + 1) / 2;
      if (b < 0.25) continue;
      final fx = r.nextDouble() * sz.width;
      final fy = sz.height * 0.42 + r.nextDouble() * sz.height * 0.38;
      final dx = 8.0 * sin(t * pi * 2 + phase);
      final dy = 5.0 * cos(t * pi * 1.7 + phase);
      canvas.drawCircle(
          Offset(fx + dx, fy + dy),
          7,
          Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
            ..color = _fireflyColor.withOpacity(b * 0.35));
      canvas.drawCircle(Offset(fx + dx, fy + dy), 1.8,
          Paint()..color = _fireflyCore.withOpacity(b * 0.95));
    }
  }

  void _vignette(Canvas canvas, Size sz) {
    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.82,
            colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
          ).createShader(Offset.zero & sz));
  }

  @override
  bool shouldRepaint(_NaturePainter old) => old.t != t || old.theme != theme;
}
