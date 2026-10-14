import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OnboardingScreen — 4 steps, skippable, saves prefs
//  Step 0: Welcome + age group
//  Step 1: Why you're here (goal)
//  Step 2: Session length preference
//  Step 3: Notifications permission
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _step = 0;

  // Selections
  String _ageGroup = ''; // 'kid' | 'teen' | 'adult'
  String _goal = ''; // 'focus' | 'scroll' | 'sharp' | 'learn'
  int _sessionMin = 10;

  late AnimationController _bgCtrl;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 16))
          ..repeat(reverse: true);
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
      _slideCtrl.forward(from: 0);
    } else {
      _finish();
    }
  }

  bool get _canAdvance => switch (_step) {
        0 => _ageGroup.isNotEmpty,
        1 => _goal.isNotEmpty,
        2 => true,
        _ => true,
      };

  Future<void> _finish() async {
    final box = Hive.box('prefs');
    await box.put('onboardingDone', true);
    await box.put('ageGroup', _ageGroup);
    await box.put('goal', _goal);
    await box.put('sessionTarget', _sessionMin);
    // Set starting difficulty based on age
    await box.put(
        'startDifficulty',
        switch (_ageGroup) {
          'kid' => 1,
          'teen' => 3,
          _ => 4,
        });
    await NotificationService.scheduleDailyReminder();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ObBgPainter(_bgCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.40)),

          SafeArea(
            child: Column(
              children: [
                _buildProgress(),
                Expanded(
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _slideCtrl,
                      child: _buildStep(),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress dots ─────────────────────────────────────────────────────────
  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        children: [
          const Text('FLOW MATH',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          ...List.generate(
              4,
              (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _step ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
        ],
      ),
    );
  }

  // ── Step content ──────────────────────────────────────────────────────────
  Widget _buildStep() {
    return switch (_step) {
      0 => _stepAge(),
      1 => _stepGoal(),
      2 => _stepSession(),
      _ => _stepNotif(),
    };
  }

  // ── Step 0: Age group ─────────────────────────────────────────────────────
  Widget _stepAge() => _stepShell(
        emoji: '🌲',
        title: 'Welcome to\nFlow Math.',
        subtitle: 'A focus app disguised as math.\nWho\'s using it?',
        child: Column(
          children: [
            _choiceCard(
              label: 'A kid',
              sub: 'Ages 8–13',
              emoji: '🧒',
              selected: _ageGroup == 'kid',
              onTap: () => setState(() => _ageGroup = 'kid'),
            ),
            _choiceCard(
              label: 'A teenager',
              sub: 'Ages 14–19',
              emoji: '🧑',
              selected: _ageGroup == 'teen',
              onTap: () => setState(() => _ageGroup = 'teen'),
            ),
            _choiceCard(
              label: 'An adult',
              sub: 'Ages 20+',
              emoji: '🧔',
              selected: _ageGroup == 'adult',
              onTap: () => setState(() => _ageGroup = 'adult'),
            ),
          ],
        ),
      );

  // ── Step 1: Goal ──────────────────────────────────────────────────────────
  Widget _stepGoal() => _stepShell(
        emoji: '🎯',
        title: 'What brings\nyou here?',
        subtitle: 'We\'ll personalise your experience.',
        child: Column(
          children: [
            _choiceCard(
              label: 'I want to focus better',
              sub: 'Distracted mind, need clarity',
              emoji: '🧠',
              selected: _goal == 'focus',
              onTap: () => setState(() => _goal = 'focus'),
            ),
            _choiceCard(
              label: 'I scroll too much',
              sub: 'Replace TikTok / Instagram',
              emoji: '📵',
              selected: _goal == 'scroll',
              onTap: () => setState(() => _goal = 'scroll'),
            ),
            _choiceCard(
              label: 'Keep my mind sharp',
              sub: 'Daily mental workout',
              emoji: '⚡',
              selected: _goal == 'sharp',
              onTap: () => setState(() => _goal = 'sharp'),
            ),
            _choiceCard(
              label: 'Improve at math',
              sub: 'Practice and get better',
              emoji: '📐',
              selected: _goal == 'learn',
              onTap: () => setState(() => _goal = 'learn'),
            ),
          ],
        ),
      );

  // ── Step 2: Session length ────────────────────────────────────────────────
  Widget _stepSession() => _stepShell(
        emoji: '⏱',
        title: 'How long per\nsession?',
        subtitle: 'You can always go longer. This sets your goal.',
        child: Column(
          children: [5, 10, 15, 20]
              .map((mins) => _choiceCard(
                    label: '$mins minutes',
                    sub: mins == 5
                        ? 'Quick focus burst'
                        : mins == 10
                            ? 'Balanced — most popular'
                            : mins == 15
                                ? 'Deep work mode'
                                : 'Full flow session',
                    emoji: mins == 10 ? '✨' : '',
                    selected: _sessionMin == mins,
                    onTap: () => setState(() => _sessionMin = mins),
                    highlight: mins == 10,
                  ))
              .toList(),
        ),
      );

  // ── Step 3: Notifications ─────────────────────────────────────────────────
  Widget _stepNotif() => _stepShell(
        emoji: '🔔',
        title: 'Stay in the\nflow every day.',
        subtitle: 'We\'ll remind you once a day. No spam, ever.',
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('🌲  Daily focus reminder at 7 PM',
                      style: TextStyle(fontSize: 14, color: AppColors.textMid)),
                  SizedBox(height: 10),
                  Text('🔥  Streak saver if you haven\'t played',
                      style: TextStyle(fontSize: 14, color: AppColors.textMid)),
                  SizedBox(height: 10),
                  Text('📊  Weekly progress summary on Sunday',
                      style: TextStyle(fontSize: 14, color: AppColors.textMid)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can change this anytime in Settings.',
              style: TextStyle(fontSize: 12, color: AppColors.textDim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  // ── Shell layout ──────────────────────────────────────────────────────────
  Widget _stepShell({
    required String emoji,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  color: AppColors.textBright,
                  height: 1.12,
                  letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDim, height: 1.6)),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  // ── Choice card ───────────────────────────────────────────────────────────
  Widget _choiceCard({
    required String label,
    required String sub,
    required String emoji,
    required bool selected,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.50)
                : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (emoji.isNotEmpty) ...[
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMid,
                          )),
                      if (highlight) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Popular',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.gold,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textDim)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.20),
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final isLast = _step == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      child: Column(
        children: [
          // Main CTA
          GestureDetector(
            onTap: _canAdvance
                ? () async {
                    if (isLast) {
                      await NotificationService.requestPermission();
                    }
                    _next();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: _canAdvance
                    ? AppColors.primary.withOpacity(0.18)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _canAdvance
                      ? AppColors.primary.withOpacity(0.40)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Center(
                child: Text(
                  isLast ? 'START FLOWING' : 'CONTINUE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _canAdvance ? AppColors.primary : AppColors.textDim,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
          ),
          // Skip
          if (isLast)
            TextButton(
              onPressed: _finish,
              child: const Text('Skip notifications',
                  style: TextStyle(fontSize: 12, color: AppColors.textDim)),
            ),
        ],
      ),
    );
  }
}

// ── Onboarding background (reuse forest style) ────────────────────────────────
class _ObBgPainter extends CustomPainter {
  final double t;
  _ObBgPainter(this.t);
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

    final cx = sz.width * 0.78;
    final cy = sz.height * 0.15;
    canvas.drawCircle(
        Offset(cx, cy),
        sz.width * 0.3,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50)
          ..color = const Color(0xFF1A4A30).withOpacity(0.10));
    canvas.drawCircle(
        Offset(cx, cy), 20, Paint()..color = const Color(0xFFE4F5EC));

    final r = Random(42);
    for (int i = 0; i < 55; i++) {
      final b = (sin(t * pi * 2 + r.nextDouble() * 6) + 1) / 2;
      canvas.drawCircle(
          Offset(r.nextDouble() * sz.width, r.nextDouble() * sz.height * 0.45),
          0.5 + r.nextDouble() * 1.0,
          Paint()..color = Colors.white.withOpacity(b * 0.55 * r.nextDouble()));
    }

    for (final layer in [
      (0.72, 0.16, const Color(0xFF0B1E14), 20, 6),
      (0.81, 0.22, const Color(0xFF071410), 15, 9),
      (0.88, 0.28, const Color(0xFF040C08), 11, 13),
    ]) {
      final lr = Random(layer.$5);
      final p = Paint()..color = layer.$3;
      final step = sz.width / layer.$4;
      for (int i = 0; i < layer.$4; i++) {
        final x = i * step + lr.nextDouble() * step * 0.6;
        final h = sz.height * layer.$2 * (0.65 + lr.nextDouble() * 0.65);
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
      }
    }
    canvas.drawRect(
        Rect.fromLTWH(0, sz.height * .90, sz.width, sz.height * .10),
        Paint()..color = const Color(0xFF020A04));

    final fr = Random(55);
    for (int i = 0; i < 12; i++) {
      final phase = fr.nextDouble() * 2 * pi;
      final b = (sin(t * pi * 3 + phase) + 1) / 2;
      if (b < 0.28) continue;
      final fx = fr.nextDouble() * sz.width;
      final fy = sz.height * 0.45 + fr.nextDouble() * sz.height * 0.35;
      final dx = 7.0 * sin(t * pi * 2 + phase);
      final dy = 4.0 * cos(t * pi * 1.8 + phase);
      canvas.drawCircle(
          Offset(fx + dx, fy + dy),
          6,
          Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
            ..color = const Color(0xFF9AFF50).withOpacity(b * 0.30));
      canvas.drawCircle(Offset(fx + dx, fy + dy), 1.6,
          Paint()..color = const Color(0xFFC8FF88).withOpacity(b * 0.88));
    }
    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.80,
            colors: [Colors.transparent, Colors.black.withOpacity(0.60)],
          ).createShader(Offset.zero & sz));
  }

  @override
  bool shouldRepaint(_ObBgPainter old) => old.t != t;
}
