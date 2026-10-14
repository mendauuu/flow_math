import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../utils/app_theme.dart';
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

  const FlowScreen({super.key, required this.service, required this.settings});

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen>
    with SingleTickerProviderStateMixin {
  String _input = '';
  late AnimationController _bgCtrl;
  late AudioService _audio;

  SettingsService get s => widget.settings;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);

    _audio = AudioService();
    _audio.setMode(s.soundMode);
    _audio.setVolume(s.volume);

    widget.service.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _tap(String v) {
    if (s.haptics) HapticFeedback.lightImpact();
    setState(() {
      if (v == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (v == '✓') {
        _submit();
      } else if (_input.length < 6) {
        _input += v;
      }
    });
  }

  void _submit() {
    if (_input.isEmpty) return;
    final ans = int.tryParse(_input);
    if (ans == null) return;
    setState(() => _input = '');
    widget.service.submitAnswer(ans);
  }

  void _end() {
    _audio.stop();
    widget.service.endSession();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) =>
            ResultsScreen(service: widget.service, settings: s),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final sz = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 500) _end();
        },
        child: Stack(
          children: [
            AnimatedBackground(controller: _bgCtrl, theme: s.bgTheme),
            Container(color: Colors.black.withOpacity(0.30)),

            SafeArea(
              child: Column(
                children: [
                  // ── HUD row ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 16, 0),
                    child: Row(
                      children: [
                        Expanded(child: SessionHud(service: svc, settings: s)),
                        SoundPickerWidget(audio: _audio),
                      ],
                    ),
                  ),

                  // ── Problem ───────────────────────────────────────────────
                  Expanded(
                    child: Center(
                      child: svc.currentProblem == null
                          ? const SizedBox()
                          : ProblemDisplay(
                              problem: svc.currentProblem!,
                              inputBuffer: _input,
                              showFeedback: svc.showFeedback,
                            ),
                    ),
                  ),

                  // ── Feedback / streak ─────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
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
                                      style: AppTextStyles.streakText),
                                ),
                              )
                            : const SizedBox(height: 36)),
                  ),

                  // ── Numpad ────────────────────────────────────────────────
                  NumpadWidget(onTap: _tap),
                  SizedBox(height: sz.height * 0.018),
                ],
              ),
            ),

            // END button top-right
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _end,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: const Text('END',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textDim,
                            letterSpacing: 2)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _audio.dispose();
    widget.service.removeListener(_onChange);
    super.dispose();
  }
}
