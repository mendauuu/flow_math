import 'dart:math';
import 'package:flow_math/main.dart';
import 'package:flow_math/screens/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../utils/app_theme.dart';
import '../main.dart' show purchaseService;

class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  final AudioService audio;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.audio,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;

  SettingsService get s => widget.settings;
  AudioService get a => widget.audio;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated forest background (same as home)
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _SettingsBgPainter(_bgCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.55)),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(context),
                Expanded(
                  child: ListenableBuilder(
                    listenable: s,
                    builder: (_, __) => ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                      children: [
                        _sectionLabel('SOUND'),
                        _soundModeGrid(),
                        const SizedBox(height: 20),
                        _volumeRow(),
                        const SizedBox(height: 32),
                        _sectionLabel('BACKGROUND'),
                        _bgThemeGrid(),
                        const SizedBox(height: 32),
                        _sectionLabel('SESSION'),
                        _sessionTargetRow(),
                        const SizedBox(height: 16),
                        _toggleTile(
                          icon: Icons.flash_on_rounded,
                          label: 'Show streak counter',
                          sub: 'Flame icon while on a roll',
                          value: s.showStreak,
                          onChanged: s.setShowStreak,
                        ),
                        const SizedBox(height: 12),
                        _toggleTile(
                          icon: Icons.keyboard_rounded,
                          label: 'Auto-focus keyboard',
                          sub: 'Input ready the moment a problem appears',
                          value: s.autoStart,
                          onChanged: s.setAutoStart,
                        ),
                        const SizedBox(height: 32),
                        _sectionLabel('FEEL'),
                        _toggleTile(
                          icon: Icons.vibration_rounded,
                          label: 'Haptic feedback',
                          sub: 'Subtle vibration on tap',
                          value: s.haptics,
                          onChanged: s.setHaptics,
                        ),
                        const SizedBox(height: 40),
                        if (!purchaseService.isPro) _proTile(context),
                        if (!purchaseService.isPro) const SizedBox(height: 12),
                        _resetTile(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textMid, size: 16),
            ),
          ),
          const SizedBox(width: 16),
          const Text('SETTINGS',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textDim,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  // ── Sound mode grid ───────────────────────────────────────────────────────
  Widget _soundModeGrid() {
    final modes = [
      (SoundMode.off, '🔇', 'Silent'),
      (SoundMode.rain, '🌧', 'Rain'),
      (SoundMode.thunder, '⛈', 'Thunder'),
      (SoundMode.wind, '🌬', 'Wind'),
      (SoundMode.forest, '🌲', 'Forest'),
      (SoundMode.birds, '🐦', 'Birds'),
      (SoundMode.river, '🏞', 'River'),
      (SoundMode.stream, '💧', 'Stream'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: modes.map((m) {
        final active = s.soundMode == m.$1;
        return GestureDetector(
          onTap: () {
            if (s.haptics) HapticFeedback.selectionClick();
            s.setSoundMode(m.$1);
            a.setMode(m.$1);
            a.setVolume(s.volume);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? AppColors.primary.withOpacity(0.45)
                    : Colors.white.withOpacity(0.07),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.$2, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(m.$3,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? AppColors.primary : AppColors.textDim,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 0.5,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Volume slider ─────────────────────────────────────────────────────────
  Widget _volumeRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.volume_down_rounded,
                color: AppColors.textDim, size: 18),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: Colors.white.withOpacity(0.08),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withOpacity(0.12),
                ),
                child: Slider(
                  value: s.volume,
                  min: 0,
                  max: 1,
                  onChanged: (v) {
                    s.setVolume(v);
                    a.setVolume(v);
                  },
                ),
              ),
            ),
            const Icon(Icons.volume_up_rounded,
                color: AppColors.textDim, size: 18),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Volume  ${(s.volume * 100).round()}%',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textDim, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  // ── Background theme grid ─────────────────────────────────────────────────
  Widget _bgThemeGrid() {
    final themes = [
      ('forest', '🌲', 'Forest', const Color(0xFF0A2018)),
      ('ocean', '🌊', 'Ocean', const Color(0xFF08182A)),
      ('desert', '🌙', 'Desert', const Color(0xFF1E1408)),
    ];
    return Row(
      children: themes.map((t) {
        final active = s.bgTheme == t.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (s.haptics) HapticFeedback.selectionClick();
              s.setBgTheme(t.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: EdgeInsets.only(right: t.$1 == themes.last.$1 ? 0 : 10),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: active ? t.$4.withOpacity(0.8) : t.$4.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? AppColors.primary.withOpacity(0.45)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                children: [
                  Text(t.$2, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(t.$3,
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? AppColors.primary : AppColors.textDim,
                        letterSpacing: 1.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Session target ────────────────────────────────────────────────────────
  Widget _sessionTargetRow() {
    final options = [0, 5, 10, 20, 30];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Session length',
            style: TextStyle(fontSize: 13, color: AppColors.textMid)),
        const SizedBox(height: 10),
        Row(
          children: options.map((mins) {
            final active = s.sessionTarget == mins;
            final label = mins == 0 ? '∞' : '${mins}m';
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (s.haptics) HapticFeedback.selectionClick();
                  s.setSessionTarget(mins);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? AppColors.primary.withOpacity(0.4)
                          : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Center(
                    child: Text(label,
                        style: TextStyle(
                          fontSize: 13,
                          color: active ? AppColors.primary : AppColors.textDim,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Toggle tile ───────────────────────────────────────────────────────────
  Widget _toggleTile({
    required IconData icon,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textDim, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMid,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textDim)),
              ],
            ),
          ),
          _NatureSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ── Reset tile ────────────────────────────────────────────────────────────
  Widget _proTile(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) =>
                PaywallScreen(purchases: purchaseService, dismissible: true),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withOpacity(0.22)),
        ),
        child: Row(children: const [
          Text('🏆', style: TextStyle(fontSize: 18)),
          SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upgrade to Pro',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w500)),
              SizedBox(height: 2),
              Text('Analytics · Sounds · Streak calendar · \$4.99/mo',
                  style: TextStyle(fontSize: 11, color: AppColors.textDim)),
            ],
          )),
          Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.gold),
        ]),
      ),
    );
  }

  Widget _resetTile(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmReset(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.incorrect.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.incorrect.withOpacity(0.15)),
        ),
        child: Row(
          children: const [
            Icon(Icons.delete_outline_rounded,
                color: AppColors.incorrect, size: 18),
            SizedBox(width: 14),
            Text('Clear all session history',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.incorrect,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111E18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear history?',
            style: TextStyle(color: AppColors.textBright, fontSize: 18)),
        content: const Text(
            'All session data will be deleted. This cannot be undone.',
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () {
              // Hive clear
              final box = Hive.box('sessions');
              box.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('History cleared',
                      style: TextStyle(color: AppColors.textMid)),
                  backgroundColor: Color(0xFF111E18),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.incorrect)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textDim,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

// ── Custom nature-style toggle switch ─────────────────────────────────────────
class _NatureSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NatureSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: value
                ? AppColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.textDim,
              shape: BoxShape.circle,
              boxShadow: value
                  ? [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 6)
                    ]
                  : [],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Settings background painter (ocean/desert/forest themed) ─────────────────
class _SettingsBgPainter extends CustomPainter {
  final double t;
  _SettingsBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size sz) {
    // Sky
    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF010609), Color(0xFF04101A), Color(0xFF061822)],
          ).createShader(Offset.zero & sz));

    // Moon (left side for variety)
    final cx = sz.width * 0.22;
    final cy = sz.height * 0.20;
    canvas.drawCircle(
        Offset(cx, cy),
        sz.width * 0.3,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50)
          ..color = const Color(0xFF1A4A30).withOpacity(0.10));
    canvas.drawCircle(
        Offset(cx, cy), 18, Paint()..color = const Color(0xFFE0F2EA));

    // Stars
    final r = Random(55);
    for (int i = 0; i < 55; i++) {
      final b = (sin(t * pi * 2 + r.nextDouble() * 6) + 1) / 2;
      canvas.drawCircle(
        Offset(r.nextDouble() * sz.width, r.nextDouble() * sz.height * 0.48),
        0.5 + r.nextDouble() * 0.9,
        Paint()..color = Colors.white.withOpacity(b * 0.55 * r.nextDouble()),
      );
    }

    // Trees — 3 layers
    for (final layer in [
      (0.72, 0.15, const Color(0xFF0B1E14), 20, 6),
      (0.80, 0.20, const Color(0xFF071410), 16, 8),
      (0.87, 0.26, const Color(0xFF040C08), 12, 12),
    ]) {
      final lr = Random(layer.$5);
      final p = Paint()..color = layer.$3;
      final step = sz.width / layer.$4;
      for (int i = 0; i < layer.$4; i++) {
        final x = i * step + lr.nextDouble() * step * 0.6;
        final h = sz.height * layer.$2 * (0.6 + lr.nextDouble() * 0.7);
        final w = h * (0.24 + lr.nextDouble() * 0.1);
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
              ..moveTo(x, yb - h * .43)
              ..lineTo(x - w * .43, yb - h * .10)
              ..lineTo(x + w * .43, yb - h * .10)
              ..close(),
            p);
      }
    }

    canvas.drawRect(
        Rect.fromLTWH(0, sz.height * 0.90, sz.width, sz.height * 0.10),
        Paint()..color = const Color(0xFF020A04));

    // Mist
    for (final m in [(0.64, 0.06, 25.0), (0.74, 0.04, 18.0)]) {
      final y = sz.height * m.$1;
      canvas.drawRect(
          Rect.fromLTWH(0, y - 28, sz.width, 56),
          Paint()
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.$3)
            ..shader = LinearGradient(colors: [
              Colors.transparent,
              const Color(0xFF5A9A78).withOpacity(m.$2),
              Colors.transparent,
            ]).createShader(Rect.fromLTWH(0, y - 28, sz.width, 56)));
    }

    // Fireflies
    final fr = Random(33);
    for (int i = 0; i < 12; i++) {
      final phase = fr.nextDouble() * 2 * pi;
      final b = (sin(t * pi * 3 + phase) + 1) / 2;
      if (b < 0.28) continue;
      final fx = fr.nextDouble() * sz.width;
      final fy = sz.height * 0.44 + fr.nextDouble() * sz.height * 0.36;
      final dx = 6.0 * sin(t * pi * 2 + phase);
      final dy = 4.0 * cos(t * pi * 1.8 + phase);
      canvas.drawCircle(
          Offset(fx + dx, fy + dy),
          5,
          Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
            ..color = const Color(0xFF9AFF50).withOpacity(b * 0.30));
      canvas.drawCircle(Offset(fx + dx, fy + dy), 1.5,
          Paint()..color = const Color(0xFFC8FF88).withOpacity(b * 0.88));
    }

    // Vignette
    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.80,
            colors: [Colors.transparent, Colors.black.withOpacity(0.72)],
          ).createShader(Offset.zero & sz));
  }

  @override
  bool shouldRepaint(_SettingsBgPainter old) => old.t != t;
}
