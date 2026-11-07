import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/palette.dart';

/// A radar ("spider") chart of skills, 0–1 per axis, in the theme's colours.
/// The shape grows outward when it first appears.
class SkillRadar extends StatelessWidget {
  final List<double> values;

  /// One label per axis; a second line (after "\n") is shown in the accent.
  final List<String> labels;

  const SkillRadar({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size.infinite,
        painter: _RadarPainter(
          values: [for (final v in values) v * t],
          labels: labels,
          palette: p,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Palette palette;

  _RadarPainter({
    required this.values,
    required this.labels,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 3) return;
    final p = palette;
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) / 2 - 30;
    if (r <= 0) return;
    Offset at(int i, double f) {
      final a = -pi / 2 + 2 * pi * i / n;
      return c + Offset(cos(a), sin(a)) * r * f;
    }

    Path ring(double f) {
      final path = Path()..moveTo(at(0, f).dx, at(0, f).dy);
      for (var i = 1; i < n; i++) {
        path.lineTo(at(i, f).dx, at(i, f).dy);
      }
      return path..close();
    }

    // Grid: four rings and the axes
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = p.line;
    for (var k = 1; k <= 4; k++) {
      canvas.drawPath(ring(k / 4), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, at(i, 1), grid);
    }
    canvas.drawPath(
        ring(1),
        Paint()
          ..style = PaintingStyle.fill
          ..color = p.surface.withValues(alpha: 0.35));

    // The skill shape
    final shape = Path();
    for (var i = 0; i < n; i++) {
      final pt = at(i, max(values[i], 0.03));
      i == 0 ? shape.moveTo(pt.dx, pt.dy) : shape.lineTo(pt.dx, pt.dy);
    }
    shape.close();
    canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.fill
          ..color = p.accent.withValues(alpha: 0.24));
    canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = p.accent);
    final dot = Paint()..color = p.accent;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(at(i, max(values[i], 0.03)), 3, dot);
    }

    // Labels around the outside
    for (var i = 0; i < n && i < labels.length; i++) {
      final parts = labels[i].split('\n');
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
              text: parts.first,
              style: TextStyle(fontSize: 10, color: p.textMid)),
          if (parts.length > 1)
            TextSpan(
                text: '\n${parts[1]}',
                style: TextStyle(
                    fontSize: 11,
                    color: p.accent,
                    fontWeight: FontWeight.w600)),
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final a = -pi / 2 + 2 * pi * i / n;
      final anchor = c + Offset(cos(a), sin(a)) * (r + 14);
      // Push labels outward so they never sit on the chart.
      final dx = anchor.dx - tp.width / 2 + cos(a) * tp.width / 2;
      final dy = anchor.dy - tp.height / 2 + sin(a) * tp.height / 2;
      tp.paint(
          canvas,
          Offset(dx.clamp(0, max(0, size.width - tp.width)),
              dy.clamp(0, max(0, size.height - tp.height))));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.palette != palette || !_same(old.values, values) || !_same(old.labels, labels);

  static bool _same<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
