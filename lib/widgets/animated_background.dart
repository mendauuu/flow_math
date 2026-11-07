import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Animated nature backgrounds
//
//  Every scene is painted in code (no image assets) and is driven by a single
//  looping clock `t` (0 → 1 every 40 s). All motion uses whole-number cycles
//  per loop, so the animation repeats forever without a visible jump.
// ─────────────────────────────────────────────────────────────────────────────

class BackgroundTheme {
  final String id;
  final String name;
  final String emoji;

  /// Soft highlight colour that harmonises with the scene (used by the
  /// meditation orb).
  final Color accent;
  const BackgroundTheme(this.id, this.name, this.emoji, this.accent);
}

/// All selectable backgrounds, in the order shown in Settings.
const List<BackgroundTheme> kBackgroundThemes = [
  BackgroundTheme('forest', 'Forest', '🌲', Color(0xFF6EC6AA)),
  BackgroundTheme('ocean', 'Ocean', '🌊', Color(0xFF6EB6E6)),
  BackgroundTheme('desert', 'Desert', '🏜️', Color(0xFFE6B47E)),
  BackgroundTheme('aurora', 'Aurora', '🌌', Color(0xFF5CF0B8)),
  BackgroundTheme('snow', 'Snowfall', '❄️', Color(0xFFBCD6F2)),
  BackgroundTheme('sakura', 'Sakura', '🌸', Color(0xFFF7A8CB)),
  BackgroundTheme('sunset', 'Sunset', '🌄', Color(0xFFFFB27A)),
  BackgroundTheme('cosmos', 'Cosmos', '🪐', Color(0xFFA894FF)),
  BackgroundTheme('storm', 'Storm', '⛈️', Color(0xFF9FBAD6)),
  BackgroundTheme('autumn', 'Autumn', '🍁', Color(0xFFF2B15A)),
  BackgroundTheme('city', 'Rainy city', '🌃', Color(0xFF7EE0D5)),
  BackgroundTheme('lanterns', 'Lanterns', '🏮', Color(0xFFFF9F5E)),
  BackgroundTheme('deepsea', 'Deep sea', '🐠', Color(0xFF5ADCF0)),
  BackgroundTheme('meadow', 'Meadow', '🌼', Color(0xFFC8E07A)),
  BackgroundTheme('starfall', 'Starfall', '🌠', Color(0xFFF4D98B)),
];

bool isKnownBackground(String id) => kBackgroundThemes.any((b) => b.id == id);

Color backgroundAccent(String id) => kBackgroundThemes
    .firstWhere((b) => b.id == id, orElse: () => kBackgroundThemes.first)
    .accent;

/// Full-screen animated background. Owns its own animation clock and
/// cross-fades when [theme] changes.
class AnimatedBackground extends StatefulWidget {
  final String theme;
  const AnimatedBackground({super.key, this.theme = 'forest'});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: CustomPaint(
          key: ValueKey(widget.theme),
          painter: ScenePainter(widget.theme, animation: _clock),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// A still frame of a scene, used for the picker tiles in Settings.
class BackgroundPreview extends StatelessWidget {
  final String theme;
  const BackgroundPreview({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: ScenePainter(theme),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class ScenePainter extends CustomPainter {
  final String theme;
  final Animation<double>? animation;

  /// Frame used when there is no [animation] (previews).
  final double fixedT;

  ScenePainter(this.theme, {this.animation, this.fixedT = 0.44})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = _Scene(canvas, size, animation?.value ?? fixedT);
    switch (theme) {
      case 'ocean':
        s.ocean();
      case 'desert':
        s.desert();
      case 'aurora':
        s.aurora();
      case 'snow':
        s.snow();
      case 'sakura':
        s.sakura();
      case 'sunset':
        s.sunset();
      case 'cosmos':
        s.cosmos();
      case 'storm':
        s.storm();
      case 'autumn':
        s.autumn();
      case 'city':
        s.city();
      case 'lanterns':
        s.lanterns();
      case 'deepsea':
        s.deepSea();
      case 'meadow':
        s.meadow();
      case 'starfall':
        s.starfall();
      default:
        s.forest();
    }
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.theme != theme || old.animation != animation || old.fixedT != fixedT;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Scene drawing
// ─────────────────────────────────────────────────────────────────────────────
class _Scene {
  final Canvas c;
  final Size sz;
  final double t;
  final double w;
  final double h;

  /// Size unit: 1.0 on a ~400 px wide phone, smaller in preview tiles.
  final double u;

  /// Like [u] but never tiny, so particles stay visible in previews.
  final double pu;

  _Scene(this.c, this.sz, this.t)
      : w = sz.width,
        h = sz.height,
        u = sz.width / 400,
        pu = max(sz.width / 400, 0.45);

  static const _tau = 2 * pi;

  Rect get full => Offset.zero & sz;

  /// sin wave completing [k] whole cycles per loop.
  double wave(int k, [double phase = 0]) => sin(_tau * k * t + phase);

  static double frac(double x) => x - x.floorToDouble();

  static Color a(Color color, double opacity) =>
      color.withValues(alpha: opacity.clamp(0.0, 1.0));

  MaskFilter blur(double sigma) =>
      MaskFilter.blur(BlurStyle.normal, max(sigma * u, 0.5));

  // ── Building blocks ───────────────────────────────────────────────────────

  void sky(List<Color> colors, [List<double>? stops]) {
    c.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(full),
    );
  }

  void stars({
    int count = 80,
    int seed = 17,
    double maxY = 0.55,
    double alpha = 0.7,
  }) {
    final r = Random(seed);
    final p = Paint();
    for (var i = 0; i < count; i++) {
      final x = r.nextDouble() * w;
      final y = r.nextDouble() * h * maxY;
      final radius = (0.5 + r.nextDouble()) * pu;
      final base = 0.3 + r.nextDouble() * 0.7;
      final k = 2 + r.nextInt(5);
      final phase = r.nextDouble() * _tau;
      final b = (sin(_tau * k * t + phase) + 1) / 2;
      p.color = a(Colors.white, (0.2 + 0.8 * b) * alpha * base);
      c.drawCircle(Offset(x, y), radius, p);
    }
  }

  /// Glowing moon (or sun). Returns its centre.
  Offset moon(
    double fx,
    double fy, {
    double radius = 20,
    required Color color,
    required Color halo,
    double haloStrength = 1,
  }) {
    final center = Offset(w * fx, h * fy + h * 0.012 * wave(1));
    final pulse = 0.92 + 0.08 * wave(2);
    c.drawCircle(
        center,
        w * 0.38,
        Paint()
          ..maskFilter = blur(60)
          ..color = a(halo, 0.12 * pulse * haloStrength));
    c.drawCircle(
        center,
        w * 0.15,
        Paint()
          ..maskFilter = blur(20)
          ..color = a(halo, 0.24 * pulse * haloStrength));
    c.drawCircle(
        center,
        radius * u * 1.35,
        Paint()
          ..maskFilter = blur(8)
          ..color = a(color, 0.7 * pulse));
    c.drawCircle(center, radius * u, Paint()..color = a(color, pulse));
    return center;
  }

  /// Soft horizontal mist bands: (y fraction, opacity).
  void mist(Color color, List<(double, double)> bands) {
    for (final b in bands) {
      final y = h * b.$1 + h * 0.015 * wave(1, b.$1 * 6);
      final bh = h * 0.08;
      final rect = Rect.fromLTWH(0, y - bh / 2, w, bh);
      c.drawRect(
        rect,
        Paint()
          ..maskFilter = blur(24)
          ..shader = LinearGradient(colors: [
            Colors.transparent,
            a(color, b.$2),
            Colors.transparent,
          ]).createShader(rect),
      );
    }
  }

  /// A row of pine silhouettes standing on y = [base] (fraction of height).
  void pines({
    required double base,
    required double height,
    required Color color,
    required int count,
    required int seed,
    Color? snow,
  }) {
    final r = Random(seed);
    final p = Paint()..color = color;
    final sp = snow == null ? null : (Paint()..color = snow);
    final step = w / count;
    final yb = h * base;
    for (var i = 0; i <= count; i++) {
      final x = i * step + r.nextDouble() * step * 0.7 - step * 0.2;
      final th = h * height * (0.65 + r.nextDouble() * 0.7);
      final tw = th * (0.25 + r.nextDouble() * 0.12);
      // Each tier: (top, bottom, half-width) as fractions of the tree.
      for (final tier in const [
        (1.0, 0.0, 0.50),
        (0.72, 0.28, 0.62),
        (0.45, 0.10, 0.45),
      ]) {
        final topY = yb - th * tier.$1;
        final bottomY = yb - th * tier.$2;
        final hw = tw * tier.$3;
        c.drawPath(
          Path()
            ..moveTo(x, topY)
            ..lineTo(x - hw, bottomY)
            ..lineTo(x + hw, bottomY)
            ..close(),
          p,
        );
        if (sp != null) {
          const f = 0.32;
          final capY = topY + (bottomY - topY) * f;
          final capHw = hw * f;
          final d = (capY - topY) * 0.18;
          c.drawPath(
            Path()
              ..moveTo(x, topY)
              ..lineTo(x - capHw, capY)
              ..lineTo(x - capHw * 0.35, capY - d)
              ..lineTo(x + capHw * 0.25, capY + d * 0.5)
              ..lineTo(x + capHw, capY)
              ..close(),
            sp,
          );
        }
      }
    }
  }

  /// Jagged mountain ridge filled down to the bottom of the screen.
  void mountains({
    required double base,
    required double peak,
    required Color color,
    required int seed,
    int peaks = 4,
    Color? cap,
  }) {
    final r = Random(seed);
    final yb = h * base;
    final n = peaks * 2;
    final pts = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final jitter =
          (i == 0 || i == n) ? 0.0 : (r.nextDouble() - 0.5) * w / n * 0.6;
      final x = w * i / n + jitter;
      final rise =
          i.isOdd ? 0.6 + 0.4 * r.nextDouble() : 0.1 + 0.3 * r.nextDouble();
      pts.add(Offset(x, yb - h * peak * rise));
    }
    final path = Path()
      ..moveTo(-1, h)
      ..lineTo(-1, pts.first.dy);
    for (final p in pts) {
      path.lineTo(p.dx, p.dy);
    }
    path
      ..lineTo(w + 1, pts.last.dy)
      ..lineTo(w + 1, h)
      ..close();
    c.drawPath(path, Paint()..color = color);

    if (cap != null) {
      final cp = Paint()..color = cap;
      for (var i = 1; i < n; i += 2) {
        final top = pts[i];
        final left = Offset.lerp(top, pts[i - 1], 0.28)!;
        final right = Offset.lerp(top, pts[i + 1], 0.28)!;
        final mid = Offset.lerp(left, right, 0.5)!
            .translate(0, -(left.dy - top.dy) * 0.3);
        c.drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..lineTo(left.dx, left.dy)
            ..lineTo(mid.dx, mid.dy)
            ..lineTo(right.dx, right.dy)
            ..close(),
          cp,
        );
      }
    }
  }

  /// Smooth rolling ridge (dunes, hills). Returns the ridge height at any x.
  double Function(double x) hills({
    required double base,
    required double amp,
    required Color color,
    required int seed,
  }) {
    final r = Random(seed);
    final f1 = 0.6 + r.nextDouble() * 0.8;
    final p1 = r.nextDouble() * _tau;
    final f2 = 1.5 + r.nextDouble() * 1.5;
    final p2 = r.nextDouble() * _tau;
    double ridge(double x) =>
        h * base -
        h *
            amp *
            (0.6 * sin(_tau * f1 * x / w + p1) +
                0.4 * sin(_tau * f2 * x / w + p2));

    final path = Path()..moveTo(0, h);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      path.lineTo(x, ridge(x));
    }
    path
      ..lineTo(w, h)
      ..close();
    c.drawPath(path, Paint()..color = color);
    return ridge;
  }

  void ground(double top, Color color) {
    c.drawRect(
        Rect.fromLTWH(0, h * top, w, h * (1 - top)), Paint()..color = color);
  }

  void fireflies({
    required int count,
    required int seed,
    required Color glow,
    required Color core,
    double top = 0.42,
    double span = 0.38,
  }) {
    final r = Random(seed);
    for (var i = 0; i < count; i++) {
      // Draw every random number up front so positions never shift.
      final phase = r.nextDouble() * _tau;
      final k = 2 + r.nextInt(3);
      final fx = r.nextDouble() * w;
      final fy = h * top + r.nextDouble() * h * span;
      final b = (sin(_tau * k * t + phase) + 1) / 2;
      if (b < 0.25) continue;
      final pos = Offset(
        fx + 8 * u * sin(_tau * 3 * t + phase),
        fy + 5 * u * cos(_tau * 2 * t + phase),
      );
      c.drawCircle(
          pos,
          7 * pu,
          Paint()
            ..maskFilter = blur(7)
            ..color = a(glow, b * 0.35));
      c.drawCircle(pos, 1.8 * pu, Paint()..color = a(core, b * 0.95));
    }
  }

  void vignette([double strength = 0.65]) {
    c.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          radius: 0.82,
          colors: [Colors.transparent, a(Colors.black, strength)],
        ).createShader(full),
    );
  }

  // ── 1. Forest — moonlit pines and fireflies ───────────────────────────────
  void forest() {
    sky(const [Color(0xFF010609), Color(0xFF04101A), Color(0xFF071A28)]);
    stars(count: 85, seed: 17);
    moon(0.73, 0.14,
        color: const Color(0xFFE8F5EE), halo: const Color(0xFF1E4A30));
    mist(const Color(0xFF5A9A78), const [
      (0.54, 0.055),
      (0.61, 0.085),
      (0.68, 0.065),
      (0.74, 0.040),
    ]);
    pines(
        base: 0.73,
        height: 0.17,
        color: const Color(0xFF0C2018),
        count: 24,
        seed: 7);
    pines(
        base: 0.79,
        height: 0.22,
        color: const Color(0xFF081610),
        count: 19,
        seed: 3);
    pines(
        base: 0.86,
        height: 0.30,
        color: const Color(0xFF040E08),
        count: 14,
        seed: 11);
    ground(0.855, const Color(0xFF030A05));
    fireflies(
        count: 22,
        seed: 99,
        glow: const Color(0xFFA8FF60),
        core: const Color(0xFFD0FF99));
    vignette();
  }

  // ── 2. Ocean — moon path on rolling water ─────────────────────────────────
  void ocean() {
    const horizon = 0.60;
    sky(const [Color(0xFF010812), Color(0xFF06182C), Color(0xFF0E2A44)],
        const [0.0, 0.45, 0.60]);
    stars(count: 70, seed: 23, maxY: 0.5);
    final m = moon(0.70, 0.16,
        color: const Color(0xFFCCE8FF), halo: const Color(0xFF1A3A5A));
    mountains(
        base: horizon,
        peak: 0.035,
        color: const Color(0xFF061322),
        seed: 4,
        peaks: 3);

    final water = Rect.fromLTWH(0, h * horizon, w, h * (1 - horizon));
    c.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B2236), Color(0xFF030C16)],
        ).createShader(water),
    );

    // Moon reflection: a shimmering column of short strokes.
    final rp = Paint()..strokeCap = StrokeCap.round;
    for (var j = 0; j < 22; j++) {
      final f = j / 22;
      final y = h * (horizon + 0.008) + f * h * 0.34;
      final shimmer = 0.55 + 0.45 * sin(_tau * 5 * t + j * 1.7);
      final half = (6 + 34 * f) * u * shimmer;
      final cx = m.dx + 6 * u * sin(_tau * 3 * t + j);
      rp
        ..strokeWidth = (1.2 + 1.8 * f) * pu
        ..color = a(const Color(0xFFCCE8FF), 0.32 * (1 - f) * shimmer);
      c.drawLine(Offset(cx - half, y), Offset(cx + half, y), rp);
    }

    // Wave lines, closer together near the horizon for depth.
    final wp = Paint()..style = PaintingStyle.stroke;
    for (var row = 0; row < 12; row++) {
      final f = row / 11;
      final y = h * horizon +
          h * (1 - horizon) * pow(f, 1.6).toDouble() * 0.95 +
          h * 0.01;
      final amp = (1 + 5 * f) * u;
      final length = w / (2 + 2 * (1 - f));
      final dir = row.isEven ? 1 : -1;
      final phase = _tau * (2 + row % 3) * t * dir + row;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w + 6 * pu; x += 6 * pu) {
        path.lineTo(x, y + amp * sin(_tau * x / length + phase));
      }
      wp
        ..strokeWidth = (0.6 + 1.2 * f) * pu
        ..color = a(const Color(0xFF7FB4DE), 0.05 + 0.10 * f);
      c.drawPath(path, wp);
    }

    // Dark swell in the foreground.
    final swell = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w + 8 * pu; x += 8 * pu) {
      swell.lineTo(
          x, h * 0.9 + 6 * u * sin(_tau * x / (w * 0.7) + _tau * 2 * t));
    }
    swell
      ..lineTo(w + 8 * pu, h)
      ..close();
    c.drawPath(swell, Paint()..color = const Color(0xFF020A12));

    mist(const Color(0xFF4A7FA8), const [(0.585, 0.07), (0.64, 0.04)]);
    vignette();
  }

  // ── 3. Desert — dunes, saguaros and drifting sand ─────────────────────────
  void desert() {
    sky(const [
      Color(0xFF0B0714),
      Color(0xFF1C1028),
      Color(0xFF3A1C2C),
      Color(0xFF5A2E26),
    ], const [
      0.0,
      0.40,
      0.62,
      0.74,
    ]);
    stars(count: 70, seed: 31, maxY: 0.45, alpha: 0.6);
    moon(0.26, 0.20,
        radius: 24,
        color: const Color(0xFFFFE8CC),
        halo: const Color(0xFF6A3A1A));
    mist(const Color(0xFFD8A070), const [(0.66, 0.07), (0.72, 0.05)]);
    hills(base: 0.70, amp: 0.035, color: const Color(0xFF2E1A1C), seed: 5);
    final middle =
        hills(base: 0.79, amp: 0.04, color: const Color(0xFF1E110F), seed: 8);

    final r = Random(12);
    for (var i = 0; i < 5; i++) {
      final x = w * (0.08 + i * 0.21 + r.nextDouble() * 0.08);
      final height = h * (0.06 + r.nextDouble() * 0.06);
      _cactus(Offset(x, middle(x) + 2 * u), height, const Color(0xFF140B09), r);
    }

    hills(base: 0.90, amp: 0.03, color: const Color(0xFF0C0706), seed: 14);

    // Drifting sand grains.
    final sr = Random(41);
    final sp = Paint();
    for (var i = 0; i < 26; i++) {
      final x0 = sr.nextDouble();
      final y = h * (0.72 + sr.nextDouble() * 0.22);
      final k = 1 + sr.nextInt(3);
      final o = 0.1 + sr.nextDouble() * 0.25;
      final size = (0.6 + sr.nextDouble()) * pu;
      sp.color = a(const Color(0xFFF0C89A), o);
      c.drawCircle(
        Offset(frac(x0 + k * t) * w, y + 3 * u * sin(_tau * 4 * t + i)),
        size,
        sp,
      );
    }
    vignette();
  }

  void _cactus(Offset base, double height, Color color, Random r) {
    final p = Paint()..color = color;
    final tw = height * 0.16;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - tw / 2, base.dy - height, tw, height),
        Radius.circular(tw / 2),
      ),
      p,
    );
    for (final side in const [-1.0, 1.0]) {
      final ay = base.dy - height * (0.35 + r.nextDouble() * 0.25);
      final ah = height * (0.25 + r.nextDouble() * 0.2);
      final aw = tw * 0.8;
      final ax = base.dx + side * (tw / 2 + aw * 0.9);
      // Elbow
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
              min(base.dx, ax), ay - aw / 2, max(base.dx, ax), ay + aw / 2),
          Radius.circular(aw / 2),
        ),
        p,
      );
      // Upright arm
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(ax - aw / 2, ay - ah, aw, ah + aw / 2),
          Radius.circular(aw / 2),
        ),
        p,
      );
    }
  }

  // ── 4. Aurora — northern lights over snowy peaks ──────────────────────────
  void aurora() {
    sky(const [Color(0xFF01030B), Color(0xFF041024), Color(0xFF0A1E34)]);
    stars(count: 120, seed: 52, maxY: 0.6, alpha: 0.75);

    const colors = [Color(0xFF4DFFB0), Color(0xFF2ED8C8), Color(0xFF9A7CFF)];
    for (var i = 0; i < colors.length; i++) {
      final baseY = h * (0.20 + i * 0.07);
      final curtain = h * (0.13 + i * 0.02);
      final glow = 0.75 + 0.25 * wave(3, i * 2.0);
      final pts = <Offset>[];
      const steps = 40;
      for (var s = 0; s <= steps; s++) {
        final x = -0.1 * w + 1.2 * w * s / steps;
        final y = baseY +
            h *
                0.045 *
                sin(_tau * (1.1 + i * 0.3) * x / w + _tau * (1 + i) * t + i) +
            h * 0.02 * sin(_tau * 3.2 * x / w - _tau * 2 * t + i * 2);
        pts.add(Offset(x, y));
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts) {
        path.lineTo(p.dx, p.dy);
      }
      for (final p in pts.reversed) {
        final height =
            curtain * (0.7 + 0.3 * sin(p.dx / w * 9 + _tau * 2 * t + i));
        path.lineTo(p.dx, p.dy - height);
      }
      path.close();
      final bounds =
          Rect.fromLTWH(0, baseY - curtain - h * 0.07, w, curtain + h * 0.14);
      c.drawPath(
        path,
        Paint()
          ..maskFilter = blur(14)
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              a(colors[i], 0.42 * glow),
              a(colors[i], 0.12 * glow),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(bounds),
      );
    }

    mountains(
      base: 0.80,
      peak: 0.16,
      color: const Color(0xFF0B1A2A),
      seed: 21,
      peaks: 4,
      cap: a(const Color(0xFFCFE2F0), 0.55),
    );
    mist(const Color(0xFF3DBFA0), const [(0.70, 0.05)]);
    mountains(
        base: 0.86,
        peak: 0.08,
        color: const Color(0xFF06101B),
        seed: 9,
        peaks: 6);
    pines(
        base: 0.90,
        height: 0.12,
        color: const Color(0xFF02070D),
        count: 16,
        seed: 19);
    ground(0.895, const Color(0xFF02070D));
    vignette();
  }

  // ── 5. Snowfall — quiet winter night ──────────────────────────────────────
  void snow() {
    sky(const [Color(0xFF0A1322), Color(0xFF15253B), Color(0xFF243851)]);
    stars(count: 40, seed: 61, maxY: 0.4, alpha: 0.45);
    moon(0.72, 0.15,
        radius: 19,
        color: const Color(0xFFEFF5FF),
        halo: const Color(0xFF4A5E80),
        haloStrength: 1.3);
    mountains(
      base: 0.70,
      peak: 0.15,
      color: const Color(0xFF1C2B42),
      seed: 33,
      peaks: 3,
      cap: a(const Color(0xFFE6EEF8), 0.7),
    );
    mist(const Color(0xFFB8C8E0), const [(0.66, 0.06), (0.74, 0.05)]);
    pines(
      base: 0.80,
      height: 0.18,
      color: const Color(0xFF13233A),
      count: 20,
      seed: 44,
      snow: a(const Color(0xFFDDE8F5), 0.55),
    );
    pines(
      base: 0.88,
      height: 0.26,
      color: const Color(0xFF0A1626),
      count: 13,
      seed: 45,
      snow: a(const Color(0xFFE8F0FA), 0.75),
    );
    final snowGround = Rect.fromLTWH(0, h * 0.875, w, h * 0.125);
    c.drawRect(
      snowGround,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF52627A), Color(0xFF2A3850)],
        ).createShader(snowGround),
    );

    // Falling snow
    final r = Random(71);
    final p = Paint();
    for (var i = 0; i < 90; i++) {
      final x0 = r.nextDouble() * w;
      final y0 = r.nextDouble();
      final k = 2 + r.nextInt(4);
      final size = (0.8 + r.nextDouble() * 2.0) * pu;
      final sway = (6 + r.nextDouble() * 14) * u;
      final ph = r.nextDouble() * _tau;
      final sk = 3 + r.nextInt(4);
      final y = frac(y0 + k * t) * h * 1.04 - h * 0.02;
      final x = x0 + sway * sin(_tau * sk * t + ph);
      p.color = a(Colors.white, 0.35 + 0.18 * size / pu);
      c.drawCircle(Offset(x, y), size, p);
    }
    vignette();
  }

  // ── 6. Sakura — cherry blossoms at dusk ───────────────────────────────────
  void sakura() {
    sky(const [
      Color(0xFF130A1E),
      Color(0xFF2A1332),
      Color(0xFF4C1F3E),
      Color(0xFF6A2C46),
    ], const [
      0.0,
      0.35,
      0.62,
      0.78,
    ]);
    stars(count: 35, seed: 81, maxY: 0.4, alpha: 0.5);
    moon(0.72, 0.19,
        radius: 26,
        color: const Color(0xFFFFE3EC),
        halo: const Color(0xFF8A3A62),
        haloStrength: 1.2);
    mist(const Color(0xFFFFA6C9), const [(0.64, 0.06), (0.72, 0.05)]);
    hills(base: 0.74, amp: 0.035, color: const Color(0xFF2C1530), seed: 3);
    hills(base: 0.82, amp: 0.03, color: const Color(0xFF1C0D20), seed: 6);
    _cherryTree(Offset(w * 0.16, h * 0.93), h * 0.10, 5);
    _cherryTree(Offset(w * 0.88, h * 0.95), h * 0.075, 9);
    hills(base: 0.93, amp: 0.015, color: const Color(0xFF0E0611), seed: 10);

    // Falling petals
    final r = Random(91);
    final p = Paint();
    for (var i = 0; i < 40; i++) {
      final x0 = r.nextDouble();
      final y0 = r.nextDouble();
      final k = 1 + r.nextInt(3);
      final s = (3 + r.nextDouble() * 3) * pu;
      final spin = 2 + r.nextInt(4);
      final ph = r.nextDouble() * _tau;
      final o = 0.55 + r.nextDouble() * 0.3;
      final y = frac(y0 + k * t) * h * 1.06 - h * 0.03;
      final x =
          frac(x0 + t) * w * 1.1 - w * 0.05 + 10 * u * sin(_tau * 5 * t + ph);
      p.color =
          a(i.isEven ? const Color(0xFFFFB3D1) : const Color(0xFFF59BC0), o);
      c.save();
      c.translate(x, y);
      c.rotate(ph + _tau * spin * t);
      c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s), p);
      c.restore();
    }
    vignette();
  }

  void _cherryTree(Offset root, double trunk, int seed) {
    final r = Random(seed);
    final wood = Paint()
      ..color = const Color(0xFF12070F)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final blossoms = <(Offset, double)>[];

    void branch(
        Offset from, double angle, double len, double width, int depth) {
      final sway = 0.025 * sin(_tau * 2 * t + depth + from.dx / w * 3);
      final ang = angle + sway;
      final to = from + Offset(cos(ang), sin(ang)) * len;
      wood.strokeWidth = width;
      c.drawLine(from, to, wood);
      if (depth == 0) {
        blossoms.add((to, len));
        return;
      }
      final spread = 0.3 + r.nextDouble() * 0.25;
      branch(to, ang - spread, len * (0.68 + r.nextDouble() * 0.1),
          width * 0.68, depth - 1);
      branch(to, ang + spread * 0.9, len * (0.66 + r.nextDouble() * 0.1),
          width * 0.68, depth - 1);
      if (depth >= 3) blossoms.add((Offset.lerp(from, to, 0.7)!, len * 0.6));
    }

    branch(
        root, -pi / 2 + (r.nextDouble() - 0.5) * 0.3, trunk, trunk * 0.11, 4);

    final glow = Paint()..maskFilter = blur(10);
    final petal = Paint();
    for (final (pos, size) in blossoms) {
      glow.color = a(const Color(0xFFFF8FBF), 0.22);
      c.drawCircle(pos, size * 0.9, glow);
      for (var j = 0; j < 7; j++) {
        final off = Offset(
            (r.nextDouble() - 0.5) * size * 1.4, (r.nextDouble() - 0.5) * size);
        petal.color = a(
            j.isEven ? const Color(0xFFF7A8CB) : const Color(0xFFFFC7DD),
            0.55 + r.nextDouble() * 0.3);
        c.drawCircle(pos + off, size * (0.18 + r.nextDouble() * 0.16), petal);
      }
    }
  }

  // ── 7. Sunset — warm sky over layered mountains ───────────────────────────
  void sunset() {
    sky(const [
      Color(0xFF1B1038),
      Color(0xFF4A1E50),
      Color(0xFF9C3E5C),
      Color(0xFFD9704A),
      Color(0xFFF0A055),
    ], const [
      0.0,
      0.30,
      0.50,
      0.63,
      0.72,
    ]);

    final sun = Offset(w * 0.5, h * (0.665 + 0.008 * wave(1)));
    c.drawCircle(
        sun,
        w * 0.45,
        Paint()
          ..maskFilter = blur(70)
          ..color = a(const Color(0xFFFFA860), 0.35));
    c.drawCircle(
        sun,
        w * 0.17,
        Paint()
          ..maskFilter = blur(18)
          ..color = a(const Color(0xFFFFC27A), 0.6));
    c.drawCircle(sun, w * 0.11, Paint()..color = const Color(0xFFFFD69A));

    // Thin drifting cloud streaks
    final r = Random(13);
    final cp = Paint()..maskFilter = blur(6);
    for (var i = 0; i < 7; i++) {
      final y = h * (0.28 + r.nextDouble() * 0.30);
      final cw = w * (0.25 + r.nextDouble() * 0.35);
      final x0 = r.nextDouble();
      final o = 0.12 + r.nextDouble() * 0.18;
      final th = (3 + r.nextDouble() * 5) * u;
      final left = frac(x0 + t) * (w + cw) - cw;
      cp.color = a(const Color(0xFFFFB08A), o);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(left, y, cw, th), Radius.circular(th)),
          cp);
    }

    mountains(
        base: 0.74,
        peak: 0.10,
        color: const Color(0xFF6E2C4C),
        seed: 2,
        peaks: 4);
    mountains(
        base: 0.80,
        peak: 0.13,
        color: const Color(0xFF41193A),
        seed: 15,
        peaks: 3);
    mountains(
        base: 0.90,
        peak: 0.12,
        color: const Color(0xFF200B20),
        seed: 27,
        peaks: 5);
    ground(0.895, const Color(0xFF14061A));

    // Birds gliding home
    final bp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * pu
      ..strokeCap = StrokeCap.round
      ..color = a(const Color(0xFF2A0F24), 0.75);
    final br = Random(8);
    for (var i = 0; i < 6; i++) {
      final x0 = br.nextDouble();
      final y = h * (0.30 + br.nextDouble() * 0.18);
      final s = (5 + br.nextDouble() * 4) * pu;
      final ph = br.nextDouble() * _tau;
      final x = frac(x0 + t) * (w * 1.3) - w * 0.15;
      final flap = 0.35 + 0.35 * sin(_tau * 40 * t + ph);
      final by = y + 6 * u * sin(_tau * 2 * t + ph);
      c.drawPath(
        Path()
          ..moveTo(x - s, by - s * flap)
          ..quadraticBezierTo(x - s * 0.4, by - s * flap * 0.2, x, by)
          ..quadraticBezierTo(
              x + s * 0.4, by - s * flap * 0.2, x + s, by - s * flap),
        bp,
      );
    }
    vignette(0.5);
  }

  // ── 8. Cosmos — nebula, ringed planet, shooting stars ─────────────────────
  void cosmos() {
    sky(const [Color(0xFF02010A), Color(0xFF080522), Color(0xFF0B0B28)]);

    final nr = Random(4);
    const nebula = [
      Color(0xFF6A3CFF),
      Color(0xFFC03A9A),
      Color(0xFF2AA8C8),
      Color(0xFF6A3CFF),
      Color(0xFF3A5CFF),
    ];
    for (var i = 0; i < nebula.length; i++) {
      final cx =
          w * (0.1 + nr.nextDouble() * 0.8) + w * 0.04 * wave(1, i * 1.0);
      final cy =
          h * (0.1 + nr.nextDouble() * 0.6) + h * 0.02 * wave(1, i + 1.5);
      final radius = w * (0.25 + nr.nextDouble() * 0.25);
      final o = 0.10 + nr.nextDouble() * 0.08;
      c.drawCircle(
          Offset(cx, cy),
          radius,
          Paint()
            ..maskFilter = blur(60)
            ..color = a(nebula[i], o));
    }

    stars(count: 160, seed: 3, maxY: 1.0, alpha: 0.85);

    // A few bright stars with glints
    final gr = Random(77);
    for (var i = 0; i < 6; i++) {
      final p = Offset(gr.nextDouble() * w, gr.nextDouble() * h * 0.85);
      final b = 0.6 + 0.4 * sin(_tau * (2 + i % 3) * t + i);
      c.drawCircle(
          p,
          6 * pu,
          Paint()
            ..maskFilter = blur(5)
            ..color = a(const Color(0xFFBFD4FF), 0.35 * b));
      final lp = Paint()
        ..strokeWidth = 0.8 * pu
        ..color = a(Colors.white, 0.5 * b);
      final l = 7 * pu * b;
      c.drawLine(p.translate(-l, 0), p.translate(l, 0), lp);
      c.drawLine(p.translate(0, -l), p.translate(0, l), lp);
      c.drawCircle(p, 1.4 * pu, Paint()..color = a(Colors.white, 0.95));
    }

    _planet(Offset(w * 0.74, h * 0.30 + h * 0.01 * wave(1)), w * 0.10);

    final moonPos = Offset(w * 0.22, h * 0.62);
    final moonR = w * 0.03;
    c.drawCircle(
      moonPos,
      moonR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Color(0xFF9FC4E8), Color(0xFF2A3E5A)],
        ).createShader(Rect.fromCircle(center: moonPos, radius: moonR)),
    );

    _shootingStar(
        0.42, 0.05, const Offset(0.15, 0.12), const Offset(0.55, 0.32));
    _shootingStar(
        0.81, 0.04, const Offset(0.90, 0.45), const Offset(0.60, 0.60));
    vignette(0.7);
  }

  void _planet(Offset center, double radius) {
    final ringRect = Rect.fromCenter(
        center: Offset.zero, width: radius * 3.6, height: radius * 0.9);
    final outerRect = ringRect.inflate(radius * 0.18);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * pu
      ..color = a(const Color(0xFFE8C9A0), 0.55);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * pu
      ..color = a(const Color(0xFFE8C9A0), 0.3);

    void rings(double start) {
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(-0.32);
      c.drawArc(ringRect, start, pi, false, ring);
      c.drawArc(outerRect, start, pi, false, outer);
      c.restore();
    }

    rings(pi); // back half, behind the planet
    c.drawCircle(
        center,
        radius * 1.4,
        Paint()
          ..maskFilter = blur(25)
          ..color = a(const Color(0xFFE09A60), 0.15));
    c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFF0C890), Color(0xFFB0643C), Color(0xFF3A160E)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    rings(0); // front half, over the planet
  }

  void _shootingStar(double start, double duration, Offset from, Offset to) {
    final p = (t - start) / duration;
    if (p < 0 || p > 1) return;
    final a0 = Offset(from.dx * w, from.dy * h);
    final b0 = Offset(to.dx * w, to.dy * h);
    final head = Offset.lerp(a0, b0, p)!;
    final delta = b0 - a0;
    final tail = head - delta / delta.distance * (90 * u);
    final fade = sin(p * pi);
    c.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.6 * pu
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
            tail, head, [Colors.transparent, a(Colors.white, 0.9 * fade)]),
    );
    c.drawCircle(
        head,
        3 * pu,
        Paint()
          ..maskFilter = blur(3)
          ..color = a(Colors.white, 0.8 * fade));
  }

  // ── 9. Storm — rain, rolling clouds, distant lightning ────────────────────
  void storm() {
    sky(const [Color(0xFF04070B), Color(0xFF0B131B), Color(0xFF131D27)]);
    final flash = _lightning();
    _clouds(
        seed: 5, count: 6, y: 0.08, color: const Color(0xFF1A2531), speed: 1);
    if (flash > 0.35) _bolt(flash, seed: t > 0.5 ? 8 : 3);
    _clouds(
        seed: 9, count: 5, y: 0.20, color: const Color(0xFF0F171F), speed: 2);
    mountains(
        base: 0.82,
        peak: 0.09,
        color: const Color(0xFF080D12),
        seed: 17,
        peaks: 4);
    mist(const Color(0xFF6A7C8E), const [(0.72, 0.06), (0.80, 0.05)]);
    pines(
        base: 0.90,
        height: 0.16,
        color: const Color(0xFF03070A),
        count: 18,
        seed: 23);
    ground(0.895, const Color(0xFF03070A));
    _rain();
    if (flash > 0) {
      c.drawRect(
          full, Paint()..color = a(const Color(0xFFCFE0FF), 0.10 * flash));
    }
    vignette(0.7);
  }

  /// 0–1 brightness of the current lightning flash (two soft strikes a loop).
  double _lightning() {
    double pulse(double start) {
      final d = t - start;
      if (d < 0 || d > 0.012) return 0;
      if (d < 0.004) return 1 - d / 0.004; // main flash
      if (d > 0.006) return 0.6 * (1 - (d - 0.006) / 0.006); // flicker
      return 0;
    }

    return max(pulse(0.31), pulse(0.78));
  }

  void _bolt(double strength, {required int seed}) {
    final r = Random(seed);
    var p = Offset(w * (0.3 + r.nextDouble() * 0.5), h * 0.18);
    final path = Path()..moveTo(p.dx, p.dy);
    while (p.dy < h * 0.78) {
      p += Offset((r.nextDouble() - 0.5) * w * 0.08,
          h * (0.03 + r.nextDouble() * 0.04));
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * pu
          ..maskFilter = blur(8)
          ..color = a(const Color(0xFFBFD6FF), 0.5 * strength));
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * pu
          ..color = a(Colors.white, 0.9 * strength));
  }

  void _clouds({
    required int seed,
    required int count,
    required double y,
    required Color color,
    required int speed,
  }) {
    final r = Random(seed);
    final p = Paint()
      ..maskFilter = blur(18)
      ..color = color;
    final margin = w * 0.7;
    for (var i = 0; i < count; i++) {
      final x0 = r.nextDouble();
      final cy = h * (y + r.nextDouble() * 0.08);
      final s = w * (0.16 + r.nextDouble() * 0.1);
      final cx = frac(x0 + speed * t) * (w + margin * 2) - margin;
      for (var j = 0; j < 3; j++) {
        c.drawCircle(
          Offset(cx + (j - 1) * s * 0.8, cy + (j == 1 ? -s * 0.25 : 0)),
          s * (j == 1 ? 1.0 : 0.75),
          p,
        );
      }
    }
  }

  void _rain({
    int count = 140,
    int seed = 101,
    Color color = const Color(0xFFB8CCE0),
  }) {
    final r = Random(seed);
    final p = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final x0 = r.nextDouble();
      final y0 = r.nextDouble();
      final k = 38 + r.nextInt(24);
      final len = h * (0.018 + r.nextDouble() * 0.02);
      final o = 0.10 + r.nextDouble() * 0.18;
      final sw = (0.7 + r.nextDouble() * 0.6) * pu;
      final y = frac(y0 + k * t) * h * 1.1 - h * 0.05;
      final x = frac(x0 - 0.05 * y / h) * w;
      p
        ..strokeWidth = sw
        ..color = a(color, o);
      c.drawLine(Offset(x, y), Offset(x - len * 0.18, y + len), p);
    }
  }

  // ── 10. Autumn — maple leaves tumbling down at golden dusk ────────────────
  void autumn() {
    sky(const [
      Color(0xFF1E1020),
      Color(0xFF4A2030),
      Color(0xFF8E3C2A),
      Color(0xFFCF6C30),
    ], const [
      0.0,
      0.38,
      0.62,
      0.78,
    ]);
    stars(count: 25, seed: 5, maxY: 0.3, alpha: 0.4);
    final sun = Offset(w * 0.62, h * (0.70 + 0.006 * wave(1)));
    c.drawCircle(
        sun,
        w * 0.5,
        Paint()
          ..maskFilter = blur(70)
          ..color = a(const Color(0xFFFF9A4A), 0.30));
    c.drawCircle(
        sun, w * 0.09, Paint()..color = a(const Color(0xFFFFC27A), 0.9));
    hills(base: 0.72, amp: 0.03, color: const Color(0xFF4A2026), seed: 31);
    mist(const Color(0xFFFFB070), const [(0.68, 0.07), (0.75, 0.05)]);
    _roundTrees(
        base: 0.80,
        height: 0.20,
        count: 7,
        seed: 12,
        canopy: const Color(0xFF5A2216),
        trunk: const Color(0xFF2A1010),
        rim: const Color(0xFFE8743C));
    hills(base: 0.86, amp: 0.02, color: const Color(0xFF2A1014), seed: 9);
    _roundTrees(
        base: 0.93,
        height: 0.26,
        count: 4,
        seed: 4,
        canopy: const Color(0xFF3A140E),
        trunk: const Color(0xFF1A0808),
        rim: const Color(0xFFD9481E));
    ground(0.92, const Color(0xFF1A0A0C));
    _leaves(count: 46, seed: 77);
    vignette(0.6);
  }

  /// Round-crowned trees whose sunny side catches the light.
  void _roundTrees({
    required double base,
    required double height,
    required int count,
    required int seed,
    required Color canopy,
    required Color trunk,
    required Color rim,
  }) {
    final r = Random(seed);
    final step = w / count;
    final trunkP = Paint()..color = trunk;
    final crownP = Paint()..color = canopy;
    final lightP = Paint()..color = a(rim, 0.22);
    for (var i = 0; i <= count; i++) {
      final x = i * step + (r.nextDouble() - 0.5) * step * 0.6;
      final th = h * height * (0.7 + r.nextDouble() * 0.5);
      final yb = h * base;
      final tw = th * 0.07;
      c.drawRect(
          Rect.fromLTWH(x - tw / 2, yb - th * 0.55, tw, th * 0.55), trunkP);
      final cr = th * 0.28;
      final sway = 2 * u * wave(2, i.toDouble());
      for (final b in const [
        (0.0, 0.0, 1.0),
        (-0.55, 0.25, 0.75),
        (0.55, 0.2, 0.8),
        (-0.25, -0.45, 0.7),
        (0.3, -0.4, 0.72),
      ]) {
        final center = Offset(x + b.$1 * cr + sway, yb - th * 0.62 + b.$2 * cr);
        c.drawCircle(center, cr * b.$3, crownP);
        c.drawCircle(center.translate(cr * 0.15 * b.$3, -cr * 0.2 * b.$3),
            cr * b.$3 * 0.7, lightP);
      }
    }
  }

  /// Three-lobed leaves that spin and flip as they fall.
  void _leaves({required int count, required int seed}) {
    const colors = [
      Color(0xFFE8742C),
      Color(0xFFD9481E),
      Color(0xFFF2B23A),
      Color(0xFFB8461F),
    ];
    final r = Random(seed);
    final p = Paint();
    final stem = Paint()
      ..strokeWidth = max(0.8, pu)
      ..color = a(const Color(0xFF3A1A0A), 0.8);
    Path lobe(double l) => Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(l * 0.5, -l * 0.32, l, 0)
      ..quadraticBezierTo(l * 0.5, l * 0.32, 0, 0)
      ..close();
    for (var i = 0; i < count; i++) {
      final x0 = r.nextDouble();
      final y0 = r.nextDouble();
      final k = 1 + r.nextInt(2);
      final s = (5 + r.nextDouble() * 5) * pu;
      final spin = 1 + r.nextInt(3);
      final flip = 2 + r.nextInt(3);
      final ph = r.nextDouble() * _tau;
      final col = colors[r.nextInt(colors.length)];
      final o = 0.65 + r.nextDouble() * 0.3;
      final y = frac(y0 + k * t) * h * 1.08 - h * 0.04;
      final x =
          frac(x0 + t) * w * 1.1 - w * 0.05 + 16 * u * sin(_tau * 3 * t + ph);
      c.save();
      c.translate(x, y);
      c.rotate(ph + _tau * spin * t);
      c.scale(max(0.15, cos(_tau * flip * t + ph).abs()), 1); // tumbling
      p.color = a(col, o);
      for (final ang in const [-pi / 2, -pi / 2 - 0.9, -pi / 2 + 0.9]) {
        c.save();
        c.rotate(ang);
        c.drawPath(lobe(ang == -pi / 2 ? s : s * 0.7), p);
        c.restore();
      }
      c.drawLine(Offset.zero, Offset(0, s * 0.5), stem);
      c.restore();
    }
  }

  // ── 11. Rainy city — night rain, glowing windows, wet street ──────────────
  void city() {
    const street = 0.86;
    sky(const [Color(0xFF070A12), Color(0xFF101828), Color(0xFF1C2638)]);
    _clouds(
        seed: 21, count: 5, y: 0.04, color: const Color(0xFF151D2A), speed: 1);
    _buildings(
        seed: 3,
        count: 9,
        base: street,
        minH: 0.25,
        maxH: 0.45,
        color: const Color(0xFF131B28),
        lit: 0.16);
    mist(const Color(0xFF6A88A8), const [(0.6, 0.05)]);
    _buildings(
        seed: 8,
        count: 6,
        base: street,
        minH: 0.15,
        maxH: 0.32,
        color: const Color(0xFF0A0F18),
        lit: 0.3,
        sign: true);
    final road = Rect.fromLTWH(0, h * street, w, h * (1 - street));
    c.drawRect(
      road,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1420), Color(0xFF05080E)],
        ).createShader(road),
    );
    // Lights smeared on the wet street
    final rr = Random(14);
    for (var i = 0; i < 12; i++) {
      final x = rr.nextDouble() * w;
      final sw = (3 + rr.nextDouble() * 6) * pu;
      final col = [
        const Color(0xFFFFCF8A),
        const Color(0xFF9FD8FF),
        const Color(0xFF7EE0D5),
      ][rr.nextInt(3)];
      final ph = rr.nextDouble() * _tau;
      final o = 0.12 + 0.08 * sin(_tau * 3 * t + ph);
      final streak = Rect.fromLTWH(
          x + 2 * u * sin(_tau * 5 * t + ph), h * street, sw, h * (1 - street));
      c.drawRect(
        streak,
        Paint()
          ..maskFilter = blur(3)
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [a(col, o), Colors.transparent],
          ).createShader(streak),
      );
    }
    _rain(count: 170, seed: 55, color: const Color(0xFFA8C4E0));
    // Ripples where drops hit the street
    final rp = Random(23);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, 0.7 * pu);
    for (var i = 0; i < 14; i++) {
      final x = rp.nextDouble() * w;
      final y = h * (street + 0.02 + rp.nextDouble() * 0.11);
      final ph = rp.nextDouble();
      final f = frac(30 * t + ph);
      final rad = (2 + f * 10) * pu;
      ring.color = a(const Color(0xFFB8CCE0), (1 - f) * 0.35);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), width: rad * 2, height: rad * 0.7),
          ring);
    }
    vignette(0.65);
  }

  void _buildings({
    required int seed,
    required int count,
    required double base,
    required double minH,
    required double maxH,
    required Color color,
    required double lit,
    bool sign = false,
  }) {
    final r = Random(seed);
    final yb = h * base;
    final body = Paint()..color = color;
    final win = Paint();
    final step = w * 1.1 / count;
    final ww = w * 0.022;
    final wh = h * 0.016;
    final gx = ww * 0.8;
    final gy = wh * 1.1;
    var x = -w * 0.05;
    for (var i = 0; i < count; i++) {
      final bw = step * (0.8 + r.nextDouble() * 0.4);
      final bh = h * (minH + r.nextDouble() * (maxH - minH));
      final top = yb - bh;
      c.drawRect(Rect.fromLTWH(x, top, bw, bh), body);
      if (r.nextDouble() < 0.5) {
        c.drawRect(
            Rect.fromLTWH(x + bw * 0.2, top - h * 0.015, bw * 0.15, h * 0.015),
            body);
      }
      final cols = ((bw - gx) / (ww + gx)).floor();
      final rows = ((bh - gy * 2) / (wh + gy)).floor();
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          final roll = r.nextDouble();
          final blinks = r.nextInt(6) == 0;
          if (roll > lit) continue;
          final warm = r.nextDouble() < 0.7;
          // A few windows slowly switch on and off.
          if (blinks && sin(_tau * 2 * t + row + col * 1.7) < -0.6) continue;
          win.color = a(
              warm ? const Color(0xFFFFCF8A) : const Color(0xFF9FD8FF),
              0.5 + 0.35 * roll / lit);
          c.drawRect(
              Rect.fromLTWH(
                  x + gx + col * (ww + gx), top + gy + row * (wh + gy), ww, wh),
              win);
        }
      }
      if (sign && i == 2) {
        // A small neon sign, softly flickering
        final rect =
            Rect.fromLTWH(x + bw * 0.15, top + bh * 0.25, bw * 0.7, h * 0.03);
        final on = 0.75 + 0.25 * sin(_tau * 7 * t);
        const neon = Color(0xFF7EE0D5);
        c.drawRRect(
            RRect.fromRectAndRadius(
                rect.inflate(4 * u), Radius.circular(6 * u)),
            Paint()
              ..maskFilter = blur(10)
              ..color = a(neon, 0.35 * on));
        c.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(4 * u)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(1.0, 1.6 * pu)
              ..color = a(neon, 0.9 * on));
      }
      x += step;
    }
  }

  // ── 12. Lanterns — sky lanterns rising from a still lake ──────────────────
  void lanterns() {
    const horizon = 0.66;
    sky(const [Color(0xFF060818), Color(0xFF151A3C), Color(0xFF2C2646)],
        const [0.0, 0.5, 0.66]);
    stars(count: 70, seed: 41, maxY: 0.6, alpha: 0.55);
    mountains(
        base: horizon,
        peak: 0.07,
        color: const Color(0xFF0E1026),
        seed: 6,
        peaks: 3);
    final water = Rect.fromLTWH(0, h * horizon, w, h * (1 - horizon));
    c.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12142E), Color(0xFF05060F)],
        ).createShader(water),
    );
    mist(const Color(0xFFFFB070), const [(0.64, 0.05)]);

    final r = Random(17);
    final glow = Paint();
    final body = Paint();
    final mirror = Paint();
    for (var i = 0; i < 24; i++) {
      final x0 = r.nextDouble();
      final y0 = r.nextDouble();
      final depth = 0.35 + r.nextDouble() * 0.65; // 1 = close by
      final ph = r.nextDouble() * _tau;
      final f = frac(y0 + (depth > 0.7 ? 2 : 1) * t);
      final y = h * (horizon + 0.03) - f * h * (horizon + 0.2);
      final x = w * x0 + 10 * u * sin(_tau * 2 * t + ph) * depth;
      final s = (7 + 12 * depth) * pu;
      final o = (f / 0.12).clamp(0.0, 1.0) *
          ((1 - f) / 0.25).clamp(0.0, 1.0) *
          (0.55 + 0.45 * depth);
      final flicker = 0.85 + 0.15 * sin(_tau * (5 + i % 4) * t + ph);
      glow
        ..maskFilter = blur(14 * depth)
        ..color = a(const Color(0xFFFFA24A), 0.32 * o * flicker);
      c.drawCircle(Offset(x, y), s * 1.4, glow);
      final rect =
          Rect.fromCenter(center: Offset(x, y), width: s * 0.8, height: s);
      body.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          a(const Color(0xFFC4562A), o),
          a(const Color(0xFFFF9A42), o),
          a(const Color(0xFFFFE2A0), o * flicker),
        ],
      ).createShader(rect);
      c.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(s * 0.22)), body);
      // Its reflection on the lake
      final ry = 2 * h * horizon - y;
      if (ry > h * horizon && ry < h) {
        final fade = 1 - (ry - h * horizon) / (h * (1 - horizon));
        mirror.color = a(const Color(0xFFFFB060), o * 0.35 * fade);
        c.drawOval(
            Rect.fromCenter(
                center: Offset(x + 3 * u * sin(_tau * 6 * t + i), ry),
                width: s * 0.9,
                height: s * 0.35),
            mirror);
      }
    }
    hills(base: 0.97, amp: 0.012, color: const Color(0xFF04050C), seed: 2);
    vignette(0.6);
  }

  // ── 13. Deep sea — light rays, bubbles, kelp and jellyfish ────────────────
  void deepSea() {
    sky(const [
      Color(0xFF0B3550),
      Color(0xFF062440),
      Color(0xFF031426),
      Color(0xFF010812),
    ], const [
      0.0,
      0.3,
      0.65,
      1.0,
    ]);
    // Sunlight from the surface
    for (var i = 0; i < 5; i++) {
      final cx = w * (0.1 + i * 0.2) + w * 0.03 * wave(1, i * 1.3);
      final path = Path()
        ..moveTo(cx - w * 0.05, 0)
        ..lineTo(cx + w * 0.05, 0)
        ..lineTo(cx + w * 0.34, h * 0.75)
        ..lineTo(cx - w * 0.06, h * 0.75)
        ..close();
      final o = 0.05 + 0.03 * wave(2, i.toDouble());
      c.drawPath(
        path,
        Paint()
          ..maskFilter = blur(12)
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [a(const Color(0xFFBFF4FF), o), Colors.transparent],
          ).createShader(Rect.fromLTWH(0, 0, w, h * 0.75)),
      );
    }
    // Shimmer of the surface far above
    final shimmer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, pu)
      ..color = a(const Color(0xFFBFF4FF), 0.12);
    for (var row = 0; row < 3; row++) {
      final y = h * (0.02 + row * 0.025);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w + 8 * pu; x += 8 * pu) {
        path.lineTo(
            x, y + 3 * u * sin(_tau * x / (w * 0.3) + _tau * (2 + row) * t));
      }
      c.drawPath(path, shimmer);
    }
    // Sea snow drifting down
    final ms = Random(9);
    final dust = Paint()..color = a(Colors.white, 0.18);
    for (var i = 0; i < 60; i++) {
      final x0 = ms.nextDouble() * w;
      final y0 = ms.nextDouble();
      final k = 1 + ms.nextInt(2);
      final size = (0.5 + ms.nextDouble()) * pu;
      c.drawCircle(
          Offset(x0 + 6 * u * sin(_tau * 2 * t + i), frac(y0 + k * t) * h),
          size,
          dust);
    }
    _jellyfish();
    hills(base: 0.9, amp: 0.03, color: const Color(0xFF041622), seed: 13);
    _kelp();
    hills(base: 0.96, amp: 0.015, color: const Color(0xFF020B12), seed: 21);
    _bubbles();
    vignette(0.72);
  }

  void _kelp() {
    final r = Random(33);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final x0 = w * (0.05 + r.nextDouble() * 0.9);
      final height = h * (0.25 + r.nextDouble() * 0.3);
      final thick = (3 + r.nextDouble() * 3) * pu;
      final ph = r.nextDouble() * _tau;
      final base = h * 0.95;
      final path = Path()..moveTo(x0, base);
      for (var s = 1; s <= 12; s++) {
        final f = s / 12;
        path.lineTo(x0 + sin(_tau * 2 * t + ph + f * 3) * 14 * u * f,
            base - f * height);
      }
      p
        ..strokeWidth = thick
        ..color = i.isEven ? const Color(0xFF0B3A36) : const Color(0xFF0E2E3C);
      c.drawPath(path, p);
    }
  }

  void _bubbles() {
    final r = Random(61);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, pu * 0.8);
    final shine = Paint();
    for (var i = 0; i < 46; i++) {
      final x0 = r.nextDouble() * w;
      final y0 = r.nextDouble();
      final k = 2 + r.nextInt(3);
      final s = (1.5 + r.nextDouble() * 3.5) * pu;
      final ph = r.nextDouble() * _tau;
      final f = frac(y0 + k * t);
      final y = h * 1.02 - f * h * 1.06;
      final x = x0 + 5 * u * sin(_tau * 6 * t + ph);
      final o = (1 - f) * 0.3 + 0.2;
      ring.color = a(const Color(0xFFCFF6FF), o);
      c.drawCircle(Offset(x, y), s, ring);
      shine.color = a(Colors.white, o);
      c.drawCircle(Offset(x - s * 0.35, y - s * 0.35), s * 0.25, shine);
    }
  }

  void _jellyfish() {
    final r = Random(5);
    for (var i = 0; i < 3; i++) {
      final x0 = r.nextDouble();
      final y0 = r.nextDouble();
      final s = (14 + r.nextDouble() * 10) * pu;
      final ph = r.nextDouble() * _tau;
      final col = i.isEven ? const Color(0xFFF2A8E0) : const Color(0xFF8FE8FF);
      final f = frac(y0 + t);
      final y = h * 0.85 - f * h * 0.95;
      final x = w * (0.15 + x0 * 0.7) + 12 * u * sin(_tau * 2 * t + ph);
      final pulse = 0.85 + 0.15 * sin(_tau * 10 * t + ph);
      final fade = sin(f * pi).clamp(0.0, 1.0);
      final center = Offset(x, y);
      c.drawCircle(
          center,
          s * 1.6,
          Paint()
            ..maskFilter = blur(16)
            ..color = a(col, 0.18 * fade));
      c.drawArc(
          Rect.fromCenter(
              center: center,
              width: s * 2 * pulse,
              height: s * 1.5 * (2 - pulse)),
          pi,
          pi,
          true,
          Paint()..color = a(col, 0.45 * fade));
      final tentacle = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, pu)
        ..color = a(col, 0.35 * fade);
      for (var k = 0; k < 4; k++) {
        final tx = x - s * 0.6 + k * s * 0.4;
        final path = Path()..moveTo(tx, y);
        for (var j = 1; j <= 8; j++) {
          final fy = j / 8;
          path.lineTo(
              tx + sin(_tau * 3 * t + k + fy * 4) * 3 * u, y + fy * s * 2.2);
        }
        c.drawPath(path, tentacle);
      }
    }
  }

  // ── 14. Meadow — summer dusk, grass in the wind, dandelion seeds ──────────
  void meadow() {
    sky(const [
      Color(0xFF1C2448),
      Color(0xFF5A4A72),
      Color(0xFFD98C6C),
      Color(0xFFF4C47C),
    ], const [
      0.0,
      0.4,
      0.66,
      0.78,
    ]);
    stars(count: 20, seed: 71, maxY: 0.3, alpha: 0.35);
    final sun = Offset(w * 0.28, h * (0.72 + 0.006 * wave(1)));
    c.drawCircle(
        sun,
        w * 0.45,
        Paint()
          ..maskFilter = blur(70)
          ..color = a(const Color(0xFFFFB070), 0.32));
    c.drawCircle(
        sun, w * 0.08, Paint()..color = a(const Color(0xFFFFD69A), 0.95));
    hills(base: 0.74, amp: 0.025, color: const Color(0xFF4A3A58), seed: 44);
    mist(const Color(0xFFFFC890), const [(0.72, 0.06)]);
    hills(base: 0.80, amp: 0.03, color: const Color(0xFF2C2C3A), seed: 18);
    final field = Rect.fromLTWH(0, h * 0.82, w, h * 0.18);
    c.drawRect(
      field,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF242A20), Color(0xFF12160F)],
        ).createShader(field),
    );
    _grass(count: 110, seed: 7);
    _dandelions();
    _seeds(count: 32, seed: 13);
    fireflies(
        count: 10,
        seed: 3,
        glow: const Color(0xFFE8FF8A),
        core: const Color(0xFFF6FFC8),
        top: 0.62,
        span: 0.3);
    vignette(0.5);
  }

  /// Grass blades; a wave of wind rolls across the field.
  void _grass({required int count, required int seed}) {
    final r = Random(seed);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final x = r.nextDouble() * w;
      final hh = h * (0.06 + r.nextDouble() * 0.12);
      final base = h * (0.84 + r.nextDouble() * 0.16);
      final lean = (r.nextDouble() - 0.5) * 0.3;
      final shade = r.nextDouble();
      final wind = sin(_tau * 2 * t - x / w * 4) * 0.18 + lean;
      final tip = Offset(x + sin(wind) * hh, base - cos(wind) * hh);
      final ctrl = Offset(x + sin(wind) * hh * 0.3, base - hh * 0.6);
      p
        ..strokeWidth = (1 + shade * 1.4) * pu
        ..color = Color.lerp(
            const Color(0xFF1E2A18), const Color(0xFF6E6A3A), shade * 0.6)!;
      c.drawPath(
          Path()
            ..moveTo(x, base)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy),
          p);
    }
  }

  /// Dandelion puffballs on swaying stems.
  void _dandelions() {
    final r = Random(29);
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, 1.4 * pu)
      ..color = const Color(0xFF3A4A2A);
    final fil = Paint()
      ..strokeWidth = max(0.6, 0.7 * pu)
      ..color = a(const Color(0xFFF4F0E2), 0.55);
    final dot = Paint()..color = a(Colors.white, 0.75);
    for (var i = 0; i < 4; i++) {
      final x = w * (0.12 + i * 0.25 + r.nextDouble() * 0.08);
      final base = h * (0.97 + r.nextDouble() * 0.02);
      final hh = h * (0.12 + r.nextDouble() * 0.06);
      final rad = (9 + r.nextDouble() * 4) * pu;
      final wind = sin(_tau * 2 * t - x / w * 4) * 0.12;
      final head = Offset(x + sin(wind) * hh, base - cos(wind) * hh);
      c.drawPath(
          Path()
            ..moveTo(x, base)
            ..quadraticBezierTo(
                x + sin(wind) * hh * 0.3, base - hh * 0.6, head.dx, head.dy),
          stem);
      for (var k = 0; k < 16; k++) {
        final ang = k / 16 * _tau;
        final end = head + Offset(cos(ang), sin(ang)) * rad;
        c.drawLine(head, end, fil);
        c.drawCircle(end, 0.9 * pu, dot);
      }
      c.drawCircle(head, 1.6 * pu, Paint()..color = const Color(0xFFB8A878));
    }
  }

  /// Dandelion seeds floating across on the breeze.
  void _seeds({required int count, required int seed}) {
    final r = Random(seed);
    final fil = Paint()..strokeWidth = max(0.5, 0.6 * pu);
    final core = Paint();
    for (var i = 0; i < count; i++) {
      final x0 = r.nextDouble();
      final y0 = h * (0.15 + r.nextDouble() * 0.6);
      final k = 1 + r.nextInt(2);
      final s = (3 + r.nextDouble() * 3) * pu;
      final ph = r.nextDouble() * _tau;
      final o = 0.4 + r.nextDouble() * 0.4;
      final x = frac(x0 + k * t) * w * 1.1 - w * 0.05;
      final y =
          y0 + 18 * u * sin(_tau * 2 * t + ph) - 6 * u * sin(_tau * 5 * t + ph);
      final tilt = 0.4 * sin(_tau * 3 * t + ph);
      final top = Offset(x + sin(tilt) * s, y - cos(tilt) * s);
      fil.color = a(const Color(0xFFFFF8E8), o);
      c.drawLine(Offset(x, y), top, fil);
      for (var f = 0; f < 6; f++) {
        final ang = -pi / 2 + tilt + (f - 2.5) * 0.35;
        c.drawLine(top, top + Offset(cos(ang), sin(ang)) * s * 0.8, fil);
      }
      core.color = a(const Color(0xFFB8A070), o);
      c.drawCircle(Offset(x, y), 0.8 * pu, core);
    }
  }

  // ── 15. Starfall — a meteor shower over a mirror lake ─────────────────────
  void starfall() {
    const horizon = 0.64;
    sky(const [Color(0xFF03040E), Color(0xFF0A1028), Color(0xFF1A1E40)],
        const [0.0, 0.45, 0.64]);
    // The Milky Way: a soft diagonal band dusted with tiny stars
    final band = Paint()..maskFilter = blur(40);
    for (var i = 0; i < 6; i++) {
      final f = i / 5;
      band.color =
          a(i.isEven ? const Color(0xFF8A7CC8) : const Color(0xFF6A8AC8), 0.10);
      c.drawCircle(
          Offset(w * (0.05 + f * 0.95), h * (0.55 - f * 0.45)), w * 0.22, band);
    }
    final dr = Random(19);
    final dust = Paint();
    for (var i = 0; i < 90; i++) {
      final f = dr.nextDouble();
      final off = (dr.nextDouble() - 0.5) * w * 0.25;
      dust.color = a(Colors.white, 0.15 + dr.nextDouble() * 0.3);
      c.drawCircle(
          Offset(w * (0.05 + f * 0.95) + off * 0.5,
              h * (0.55 - f * 0.45) + off * 0.6),
          (0.4 + dr.nextDouble() * 0.6) * pu,
          dust);
    }
    stars(count: 150, seed: 88, maxY: horizon, alpha: 0.8);
    // Meteors, all streaming from the upper left
    const meteors = [
      (0.05, 0.035, Offset(0.10, 0.06), Offset(0.42, 0.28)),
      (0.18, 0.030, Offset(0.30, 0.02), Offset(0.62, 0.22)),
      (0.31, 0.035, Offset(0.02, 0.18), Offset(0.30, 0.40)),
      (0.42, 0.045, Offset(0.20, 0.08), Offset(0.58, 0.36)),
      (0.57, 0.030, Offset(0.45, 0.04), Offset(0.80, 0.24)),
      (0.70, 0.035, Offset(0.12, 0.12), Offset(0.40, 0.42)),
      (0.83, 0.030, Offset(0.55, 0.10), Offset(0.92, 0.30)),
      (0.93, 0.030, Offset(0.25, 0.20), Offset(0.50, 0.46)),
    ];
    for (final m in meteors) {
      _shootingStar(m.$1, m.$2, m.$3, m.$4);
    }
    // …plus a steady shower in between, so there's almost always one falling.
    final mr = Random(404);
    const shower = 26;
    for (var i = 0; i < shower; i++) {
      final dur = 0.016 + mr.nextDouble() * 0.016;
      final start = min((i + mr.nextDouble() * 0.6) / shower, 1 - dur);
      final from =
          Offset(0.02 + mr.nextDouble() * 0.7, 0.01 + mr.nextDouble() * 0.3);
      final len = 0.18 + mr.nextDouble() * 0.16;
      _shootingStar(start, dur, from, from + Offset(len, len * 0.7));
    }
    // Faint radiant glow where the shower seems to come from
    c.drawCircle(
        Offset(w * 0.08, h * 0.04),
        w * 0.3,
        Paint()
          ..maskFilter = blur(50)
          ..color = a(const Color(0xFFF4D98B), 0.07 + 0.03 * wave(3)));
    mountains(
      base: horizon,
      peak: 0.16,
      color: const Color(0xFF0C1028),
      seed: 51,
      peaks: 4,
      cap: a(const Color(0xFFCFD8F0), 0.35),
    );
    final lake = Rect.fromLTWH(0, h * horizon, w, h * (1 - horizon));
    c.drawRect(
      lake,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141A3A), Color(0xFF04050E)],
        ).createShader(lake),
    );
    // Stars twinkling in the water
    final sr = Random(12);
    final glint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 30; i++) {
      final x = sr.nextDouble() * w;
      final y = h * (horizon + 0.02 + sr.nextDouble() * 0.3);
      final b = 0.5 + 0.5 * sin(_tau * (2 + i % 3) * t + i);
      glint
        ..strokeWidth = max(0.8, pu)
        ..color = a(Colors.white, 0.18 * b);
      c.drawLine(Offset(x, y), Offset(x, y + 4 * pu), glint);
    }
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, 0.8 * pu)
      ..color = a(const Color(0xFFAAB8FF), 0.08);
    for (var row = 0; row < 6; row++) {
      final y = h * (horizon + 0.03 + row * 0.05);
      final dir = row.isEven ? 1 : -1;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w + 8 * pu; x += 8 * pu) {
        path.lineTo(
            x,
            y +
                2 *
                    u *
                    sin(_tau * x / (w * 0.4) + dir * _tau * (2 + row % 2) * t));
      }
      c.drawPath(path, ripple);
    }
    pines(
        base: 0.97,
        height: 0.1,
        color: const Color(0xFF02030A),
        count: 14,
        seed: 66);
    vignette(0.7);
  }
}
