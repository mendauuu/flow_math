import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/palette.dart';
import '../widgets/animated_background.dart';
import '../widgets/themed.dart';
import 'home_screen.dart';

/// First launch: three quick, skippable questions that set the starting
/// level, the session length and the reminders. Nothing leaves the phone.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = 3;

  Palette get pal => context.palette;
  SettingsService get s => appSettings;

  int _step = 0;
  int? _level; // starting difficulty 1–10
  int _minutes = 10;
  bool _busy = false;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  bool get _canAdvance => _step != 0 || _level != null;

  void _tick() {
    if (s.haptics) HapticFeedback.selectionClick();
  }

  Future<void> _continue() async {
    if (!_canAdvance || _busy) return;
    if (_step < _steps - 1) {
      setState(() => _step++);
      _enter.forward(from: 0);
      return;
    }
    setState(() => _busy = true);
    final granted = await NotificationService.requestPermission();
    _finish(reminders: granted);
  }

  void _finish({required bool reminders}) {
    s.setStartLevel(_level ?? 3);
    s.setSessionTarget(_minutes);
    Hive.box('prefs').put('onboardingDone', true);
    unawaited(() async {
      await s.setRemindDaily(reminders);
      await s.setRemindStreak(reminders);
      await s.setRemindWeekly(reminders);
    }());
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

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _enter.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            AnimatedBackground(theme: s.bgTheme),
            const ThemedScrim(0.45),
            SafeArea(
              child: Column(
                children: [
                  _progress(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _enter,
                      child: SlideTransition(
                        position: Tween(
                                begin: const Offset(0.06, 0), end: Offset.zero)
                            .animate(CurvedAnimation(
                                parent: _enter, curve: Curves.easeOut)),
                        child: switch (_step) {
                          0 => _levelStep(),
                          1 => _lengthStep(),
                          _ => _reminderStep(),
                        },
                      ),
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        children: [
          Text('FLOW MATH', style: pal.labelText.copyWith(color: pal.accent)),
          const Spacer(),
          for (var i = 0; i < _steps; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == _step ? 20 : 6,
              height: 6,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: i <= _step
                    ? pal.accent
                    : pal.textBright.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _levelStep() => _shell(
        emoji: '🌲',
        title: 'Welcome to\nFlow Math.',
        subtitle: 'Calm math, deep focus and slow breathing in one cozy '
            'place. Where is your math right now?',
        children: [
          for (final o in const [
            (1, '🌱', 'Just starting', 'Adding and taking away'),
            (3, '🌿', 'Comfortable', 'Times tables and bigger sums'),
            (5, '🌳', 'Sharp', 'Bring on the tricky stuff'),
          ])
            _choice(
              emoji: o.$2,
              label: o.$3,
              sub: o.$4,
              selected: _level == o.$1,
              onTap: () => setState(() => _level = o.$1),
            ),
          const SizedBox(height: 6),
          _note('The level adapts as you play.'),
        ],
      );

  Widget _lengthStep() => _shell(
        emoji: '⏱',
        title: 'How long per\nsession?',
        subtitle: 'A gentle goal for each math session. '
            'You can always keep going.',
        children: [
          for (final o in const [
            (5, 'A quick warm-up'),
            (10, 'A calm, steady session'),
            (15, 'Settle in and focus'),
            (20, 'A long flow session'),
          ])
            _choice(
              label: '${o.$1} minutes',
              sub: o.$2,
              selected: _minutes == o.$1,
              onTap: () => setState(() => _minutes = o.$1),
            ),
        ],
      );

  Widget _reminderStep() {
    final hour = s.remindHour;
    final time = hour == 0
        ? '12 AM'
        : hour < 12
            ? '$hour AM'
            : hour == 12
                ? '12 PM'
                : '${hour - 12} PM';
    return _shell(
      emoji: '🔔',
      title: 'A gentle nudge\nnow and then?',
      subtitle: 'Quiet reminders to come back to your practice. '
          'No spam, ever.',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: pal.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reminderLine('🌙', 'A daily reminder at $time'),
              const SizedBox(height: 10),
              _reminderLine('🔥', 'A streak saver if you haven\'t played'),
              const SizedBox(height: 10),
              _reminderLine('📊', 'A weekly summary on Sunday'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _note('You can change this any time in Settings.'),
      ],
    );
  }

  Widget _reminderLine(String emoji, String text) => Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 14, color: pal.textMid)),
          ),
        ],
      );

  Widget _note(String text) => Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: pal.textDim)),
      );

  Widget _shell({
    required String emoji,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    // Short phones: tighter header so every choice fits without scrolling.
    final compact = MediaQuery.sizeOf(context).height < 720;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, compact ? 14 : 28, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: compact ? 26 : 34)),
          SizedBox(height: compact ? 8 : 14),
          Text(title,
              style: TextStyle(
                  fontSize: compact ? 27 : 34,
                  fontWeight: FontWeight.w200,
                  color: pal.textBright,
                  height: 1.12,
                  letterSpacing: -0.5)),
          SizedBox(height: compact ? 6 : 10),
          Text(subtitle,
              style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  color: pal.textDim,
                  height: 1.5)),
          SizedBox(height: compact ? 16 : 26),
          ...children,
        ],
      ),
    );
  }

  Widget _choice({
    String? emoji,
    required String label,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () {
          _tick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: selected ? pal.card(active: true) : pal.panel(),
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected ? pal.accent : pal.textMid)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(fontSize: 12, color: pal.textDim)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? pal.accent : Colors.transparent,
                  border: Border.all(
                      color: selected
                          ? pal.accent
                          : pal.textBright.withValues(alpha: 0.25)),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 13, color: pal.surface)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    final last = _step == _steps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _canAdvance ? 1 : 0.45,
            child: ThemedButton(
              label: last ? 'TURN ON REMINDERS' : 'CONTINUE',
              onTap: _canAdvance && !_busy ? _continue : null,
            ),
          ),
          SizedBox(
            height: 44,
            child: last
                ? TextButton(
                    onPressed: _busy ? null : () => _finish(reminders: false),
                    child: Text('Not now',
                        style: TextStyle(fontSize: 12, color: pal.textDim)),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
