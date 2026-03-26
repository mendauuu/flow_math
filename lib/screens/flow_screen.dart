import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/session_service.dart';
import '../utils/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/numpad_widget.dart';
import '../widgets/session_hud.dart';
import '../widgets/problem_display.dart';
import '../widgets/feedback_overlay.dart';
import 'results_screen.dart';

class FlowScreen extends StatefulWidget {
  final SessionService service;
  const FlowScreen({super.key, required this.service});

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen>
    with SingleTickerProviderStateMixin {
  String _inputBuffer = '';
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    widget.service.addListener(_onServiceChange);
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  void _onNumpadTap(String value) {
    HapticFeedback.lightImpact();
    if (value == '⌫') {
      if (_inputBuffer.isNotEmpty) {
        setState(() => _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1));
      }
    } else if (value == '✓') {
      _submit();
    } else if (_inputBuffer.length < 6) {
      setState(() => _inputBuffer += value);
    }
  }

  void _submit() {
    if (_inputBuffer.isEmpty) return;
    final answer = int.tryParse(_inputBuffer);
    if (answer == null) return;
    setState(() => _inputBuffer = '');
    widget.service.submitAnswer(answer);
  }

  void _endSession() {
    widget.service.endSession();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => ResultsScreen(service: widget.service),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        // Swipe down to end session
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 500) {
            _endSession();
          }
        },
        child: Stack(
          children: [
            // Animated nature background
            AnimatedBackground(controller: _bgController),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // HUD
                  SessionHud(service: svc),

                  // Problem area — takes most vertical space
                  Expanded(
                    child: Center(
                      child: svc.currentProblem == null
                          ? const SizedBox()
                          : ProblemDisplay(
                              problem: svc.currentProblem!,
                              inputBuffer: _inputBuffer,
                              showFeedback: svc.showFeedback,
                            ),
                    ),
                  ),

                  // Feedback bar
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: svc.showFeedback
                        ? FeedbackOverlay(
                            message: svc.feedbackMessage,
                            isCorrect: svc.isCorrect,
                          )
                        : const SizedBox(height: 48),
                  ),

                  // Numpad
                  NumpadWidget(onTap: _onNumpadTap),

                  SizedBox(height: size.height * 0.02),
                ],
              ),
            ),

            // End session hint (very subtle)
            Positioned(
              top: 16,
              right: 20,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _endSession,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'END',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textDim,
                        letterSpacing: 2,
                      ),
                    ),
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
    _bgController.dispose();
    widget.service.removeListener(_onServiceChange);
    super.dispose();
  }
}
