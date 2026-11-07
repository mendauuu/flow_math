import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../widgets/themed.dart';
import 'package:flutter/services.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/numpad_widget.dart';
import '../widgets/session_hud.dart';
import '../widgets/problem_display.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/sound_picker_widget.dart';
import 'results_screen.dart';

class FlowScreen extends StatefulWidget {
  final SessionService service;
  final SettingsService settings;

  /// The shared ambient player from Home — it keeps playing all the way
  /// through the session and the results.
  final AudioService audio;

  const FlowScreen({
    super.key,
    required this.service,
    required this.settings,
    required this.audio,
  });

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  Palette get pal => context.palette;

  String _input = '';
  bool _ended = false;
  bool _wasInFlow = false;

  SettingsService get s => widget.settings;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted || _ended) return;
    final svc = widget.service;
    // Time is up / Daily set finished — end once any feedback has shown.
    if (svc.isOver && !svc.showFeedback) {
      _end();
      return;
    }
    // Entering flow deserves a little celebration.
    if (svc.inFlow && !_wasInFlow && s.haptics) HapticFeedback.heavyImpact();
    _wasInFlow = svc.inFlow;
    setState(() {});
  }

  void _skip() {
    if (s.haptics) HapticFeedback.selectionClick();
    setState(() => _input = '');
    widget.service.skip();
  }

  void _tap(String v) {
    if (s.haptics) HapticFeedback.lightImpact();
    if (v == '✓') {
      _submit();
      return;
    }
    setState(() {
      if (v == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (_input.length < 6) {
        _input += v;
      }
    });

    // Auto-submit: accept the answer the moment it's correct.
    if (s.autoSubmit && v != '⌫') {
      final svc = widget.service;
      final problem = svc.currentProblem;
      if (problem != null &&
          !svc.showFeedback &&
          int.tryParse(_input) == problem.correctAnswer) {
        _submit();
      }
    }
  }

  void _submit() {
    if (_input.isEmpty) return;
    final ans = int.tryParse(_input);
    if (ans == null) return;
    setState(() => _input = '');
    widget.service.submitAnswer(ans);
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    widget.service.endSession();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => ResultsScreen(
            service: widget.service, settings: s, audio: widget.audio),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final sz = MediaQuery.of(context).size;

    // System back = end the session properly (saves it, shows results).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _end();
      },
      child: Scaffold(
        body: GestureDetector(
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 500) _end();
          },
          child: Stack(
            children: [
              AnimatedBackground(theme: s.bgTheme),
              // In flow the scene brightens and warm light gathers at the edges.
              ThemedScrim(svc.inFlow ? 0.14 : 0.30),
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 900),
                  opacity: svc.inFlow ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.05,
                        colors: [
                          Colors.transparent,
                          pal.warm.withValues(alpha: 0.16),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // ── HUD row ────────────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                              child: SessionHud(service: svc, settings: s)),
                          SoundPickerWidget(
                            audio: widget.audio,
                            haptics: s.haptics,
                            onChanged: s.setSoundMode,
                            // Narrow phones: just the emoji, so the row fits.
                            compact: sz.width < 400,
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: _end,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: pal.panel(scale: 0.6),
                              child: Text('END',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: pal.textDim,
                                      letterSpacing: 2)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Flow meter + XP ────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _flowMeter(svc),
                    ),
                    // ── Problem ─────────────────────────────────────────────
                    // On short phones the whole problem block scales down
                    // instead of overflowing; long problems fit the width.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) => Center(
                          child: svc.currentProblem == null
                              ? SizedBox()
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth: max(0, box.maxWidth - 32)),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ProblemDisplay(
                                          problem: svc.currentProblem!,
                                          inputBuffer: _input,
                                          showFeedback: svc.showFeedback,
                                        ),
                                        SizedBox(height: 14),
                                        SizedBox(
                                          height: 40,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // Stuck? Skip shows the answer + a hint.
                                              AnimatedOpacity(
                                                duration:
                                                    Duration(milliseconds: 200),
                                                opacity:
                                                    svc.showFeedback ? 0 : 1,
                                                child: TextButton.icon(
                                                  onPressed: svc.showFeedback
                                                      ? null
                                                      : _skip,
                                                  icon: Icon(
                                                      Icons.skip_next_rounded,
                                                      size: 16,
                                                      color: pal.textDim),
                                                  label: Text('SKIP',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: pal.textDim,
                                                          letterSpacing: 2)),
                                                ),
                                              ),
                                              // "+18 XP" floats up from the answer
                                              if (svc.showFeedback &&
                                                  svc.isCorrect &&
                                                  svc.lastXpGain > 0)
                                                _XpPop(
                                                  key: ValueKey(
                                                      svc.totalProblems),
                                                  text: '+${svc.lastXpGain} XP',
                                                  color: svc.inFlow
                                                      ? pal.warm
                                                      : pal.accent,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // ── Feedback / streak ───────────────────────────────────
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 280),
                      child: svc.showFeedback
                          ? FeedbackOverlay(
                              message: svc.feedbackMessage,
                              isCorrect: svc.isCorrect,
                              reward: svc.lastReward,
                            )
                          : (s.showStreak && svc.streak > 2
                              ? SizedBox(
                                  height: 36,
                                  child: Center(
                                    child: Text(svc.streakMessage,
                                        style: pal.streakText),
                                  ),
                                )
                              : SizedBox(height: 36)),
                    ),

                    // ── Numpad ──────────────────────────────────────────────
                    NumpadWidget(onTap: _tap),
                    SizedBox(height: sz.height * 0.018),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "FLOW" + a meter that fast correct answers fill; full = 20 s in flow
  /// with double XP. The session's XP sits at the end.
  Widget _flowMeter(SessionService svc) {
    final color = svc.inFlow ? pal.warm : pal.accent;
    return Row(
      children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: 400),
          child: Text(
            svc.inFlow ? '🌊 IN FLOW · 2× XP' : 'FLOW',
            key: ValueKey(svc.inFlow),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: svc.inFlow ? pal.warm : pal.textDim,
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: pal.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: pal.line, width: 0.5),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: Duration(milliseconds: 500),
                curve: Curves.easeOut,
                widthFactor: svc.flowMeter.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.55), color]),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 250),
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: Text(
            '✦ ${svc.xp}',
            key: ValueKey(svc.xp),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: pal.warm.withValues(alpha: 0.9),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChange);
    super.dispose();
  }
}

/// A little "+18 XP" that floats up from the answer and fades.
class _XpPop extends StatefulWidget {
  final String text;
  final Color color;
  const _XpPop({super.key, required this.text, required this.color});

  @override
  State<_XpPop> createState() => _XpPopState();
}

class _XpPopState extends State<_XpPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final rise = Curves.easeOut.transform(_c.value);
        final fade = _c.value < 0.6 ? 1.0 : 1 - (_c.value - 0.6) / 0.4;
        return Transform.translate(
          offset: Offset(0, -22 * rise),
          child: Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Text(widget.text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                  letterSpacing: 1,
                )),
          ),
        );
      },
    );
  }
}
