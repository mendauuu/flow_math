import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../utils/app_theme.dart';
import 'flow_screen.dart';
import 'stats_screen.dart';
import 'analyze_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;
  final SettingsService _settings = SettingsService();
  final AudioService _audio = AudioService();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _settings.init().then((_) {
      _audio.setMode(_settings.soundMode);
      _audio.setVolume(_settings.volume);
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _audio.stop();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _HomeBgPainter(_bgCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.32)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  _header(),
                  const Spacer(),
                  _modeCard(
                    label: 'FLOW STATE',
                    subtitle: 'Pure focus. Silence the noise.',
                    emoji: '🌊',
                    mode: SessionMode.focus,
                    borderColor: AppColors.primary.withOpacity(0.35),
                    bgColor: const Color(0xFF0A2A1E),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 14),
                  _modeCard(
                    label: 'ANTI-SCROLL',
                    subtitle: 'Replace distraction. Build focus.',
                    emoji: '🌿',
                    mode: SessionMode.antiScroll,
                    borderColor: AppColors.gold.withOpacity(0.3),
                    bgColor: const Color(0xFF201E08),
                    accentColor: AppColors.gold,
                  ),
                  const SizedBox(height: 28),
                  _bottomRow(context),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.7),
                    blurRadius: 10,
                    spreadRadius: 2)
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text('FLOW MATH',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 22),
        const Text('Quiet\nyour mind.',
            style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w200,
                color: AppColors.textBright,
                height: 1.12,
                letterSpacing: -0.5)),
        const SizedBox(height: 12),
        const Text('Step into the forest.\nReplace scrolling with thinking.',
            style: TextStyle(
                fontSize: 14, color: AppColors.textDim, height: 1.65)),
      ],
    );
  }

  Widget _modeCard({
    required String label,
    required String subtitle,
    required String emoji,
    required SessionMode mode,
    required Color borderColor,
    required Color bgColor,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: () {
        if (_settings.haptics) HapticFeedback.mediumImpact();
        _start(mode);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.75),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                          letterSpacing: 2.5)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDim)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: accentColor.withOpacity(0.4), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _bottomRow(BuildContext context) {
    return Row(
      children: [
        // History
        GestureDetector(
          onTap: () => Navigator.push(
              context, _fadeRoute(StatsScreen(settings: _settings))),
          child: Row(children: const [
            Icon(Icons.show_chart, color: AppColors.textDim, size: 15),
            SizedBox(width: 6),
            Text('HISTORY',
                style: TextStyle(
                    fontSize: 10, color: AppColors.textDim, letterSpacing: 2)),
          ]),
        ),
        const Spacer(),
        // Settings
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            _fadeRoute(SettingsScreen(settings: _settings, audio: _audio)),
          ).then((_) {
            // Re-apply any changed settings when returning
            _audio.setMode(_settings.soundMode);
            _audio.setVolume(_settings.volume);
            setState(() {});
          }),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded,
                color: AppColors.textDim, size: 18),
          ),
        ),
      ],
    );
  }

  void _start(SessionMode mode) {
    // Pause home audio during session
    _audio.stop();
    final svc = SessionService();
    svc.startSession(mode);
    Navigator.push(
      context,
      _fadeRoute(FlowScreen(
        service: svc,
        settings: _settings,
      )),
    ).then((_) {
      // Resume home audio when returning
      _audio.setMode(_settings.soundMode);
      _audio.setVolume(_settings.volume);
    });
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      );
}

// ── Home background painter ───────────────────────────────────────────────────
class _HomeBgPainter extends CustomPainter {
  final double t;
  _HomeBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size sz) {
    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF010609), Color(0xFF040F18), Color(0xFF061A22)],
          ).createShader(Offset.zero & sz));

    // Moon
    final cx = sz.width * 0.78;
    final cy = sz.height * 0.18;
    canvas.drawCircle(
        Offset(cx, cy),
        sz.width * 0.35,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55)
          ..color = const Color(0xFF1A4A30).withOpacity(0.12));
    canvas.drawCircle(
        Offset(cx, cy),
        sz.width * 0.13,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
          ..color = const Color(0xFF3A7A50).withOpacity(0.20));
    canvas.drawCircle(
        Offset(cx, cy), 21, Paint()..color = const Color(0xFFE4F5EC));

    // Stars
    final r = Random(42);
    for (int i = 0; i < 70; i++) {
      final brightness = (sin(t * pi * 2 + r.nextDouble() * 6) + 1) / 2;
      canvas.drawCircle(
        Offset(r.nextDouble() * sz.width, r.nextDouble() * sz.height * 0.52),
        0.5 + r.nextDouble() * 1.0,
        Paint()
          ..color =
              Colors.white.withOpacity(brightness * 0.65 * r.nextDouble()),
      );
    }

    // Trees — 3 depth layers
    for (final layer in [
      (0.70, 0.16, const Color(0xFF0C2018), 23, 5),
      (0.78, 0.21, const Color(0xFF081410), 18, 9),
      (0.86, 0.29, const Color(0xFF040C08), 13, 13),
    ]) {
      final lr = Random(layer.$5);
      final p = Paint()..color = layer.$3;
      final step = sz.width / layer.$4;
      for (int i = 0; i < layer.$4; i++) {
        final x = i * step + lr.nextDouble() * step * 0.6;
        final h = sz.height * layer.$2 * (0.65 + lr.nextDouble() * 0.65);
        final w = h * (0.24 + lr.nextDouble() * 0.10);
        final yb = sz.height * layer.$1;
        canvas.drawPath(
            Path()
              ..moveTo(x, yb - h)
              ..lineTo(x - w / 2, yb)
              ..lineTo(x + w / 2, yb)
              ..close(),
            p);
        canvas.drawPath(
            Path()
              ..moveTo(x, yb - h * .70)
              ..lineTo(x - w * .60, yb - h * .27)
              ..lineTo(x + w * .60, yb - h * .27)
              ..close(),
            p);
        canvas.drawPath(
            Path()
              ..moveTo(x, yb - h * .44)
              ..lineTo(x - w * .44, yb - h * .10)
              ..lineTo(x + w * .44, yb - h * .10)
              ..close(),
            p);
      }
    }
    canvas.drawRect(
        Rect.fromLTWH(0, sz.height * .89, sz.width, sz.height * .11),
        Paint()..color = const Color(0xFF020A04));

    // Mist bands
    for (final m in [(0.62, 0.07, 28.0), (0.72, 0.05, 20.0)]) {
      final y = sz.height * m.$1 + sz.height * 0.015 * sin(t * pi + m.$1 * 4);
      canvas.drawRect(
          Rect.fromLTWH(0, y - 30, sz.width, 60),
          Paint()
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.$3)
            ..shader = LinearGradient(colors: [
              Colors.transparent,
              const Color(0xFF5A9A78).withOpacity(m.$2),
              Colors.transparent,
            ]).createShader(Rect.fromLTWH(0, y - 30, sz.width, 60)));
    }

    // Fireflies
    final fr = Random(77);
    for (int i = 0; i < 16; i++) {
      final phase = fr.nextDouble() * 2 * pi;
      final b = (sin(t * pi * 3 + phase) + 1) / 2;
      if (b < 0.28) continue;
      final fx = fr.nextDouble() * sz.width;
      final fy = sz.height * 0.44 + fr.nextDouble() * sz.height * 0.36;
      final dx = 7.0 * sin(t * pi * 2 + phase);
      final dy = 4.0 * cos(t * pi * 1.8 + phase);
      canvas.drawCircle(
          Offset(fx + dx, fy + dy),
          6,
          Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
            ..color = const Color(0xFF9AFF50).withOpacity(b * 0.32));
      canvas.drawCircle(Offset(fx + dx, fy + dy), 1.6,
          Paint()..color = const Color(0xFFC8FF88).withOpacity(b * 0.90));
    }

    // Vignette
    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.78,
            colors: [Colors.transparent, Colors.black.withOpacity(0.68)],
          ).createShader(Offset.zero & sz));
  }

  @override
  bool shouldRepaint(_HomeBgPainter old) => old.t != t;
}
