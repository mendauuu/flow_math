import 'package:flutter/material.dart';
import '../theme/palette.dart';

import '../models/math_problem.dart';

class ProblemDisplay extends StatelessWidget {
  final MathProblem problem;
  final String inputBuffer;
  final bool showFeedback;

  const ProblemDisplay({
    super.key,
    required this.problem,
    required this.inputBuffer,
    required this.showFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Operation label
        Text(
          problem.operationLabel,
          style: TextStyle(
            fontSize: 10,
            color: pal.textDim,
            letterSpacing: 3,
          ),
        ),
        SizedBox(height: 20),

        // The math problem
        AnimatedSwitcher(
          duration: Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, 0.1),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          // Long problems ("(12 + 15) × 9") shrink to stay on one line.
          child: FittedBox(
            key: ValueKey(problem.questionText),
            fit: BoxFit.scaleDown,
            child: Text(
              problem.questionText,
              maxLines: 1,
              softWrap: false,
              style: pal.problemText,
            ),
          ),
        ),

        SizedBox(height: 8),
        Container(
          width: 80,
          height: 1,
          color: pal.textDim.withValues(alpha: 0.2),
        ),
        SizedBox(height: 20),

        // Answer input display
        AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: inputBuffer.isEmpty
                    ? pal.textDim.withValues(alpha: 0.15)
                    : pal.accent.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Text(
            inputBuffer.isEmpty ? '?' : inputBuffer,
            style: pal.answerText.copyWith(
              color: inputBuffer.isEmpty
                  ? pal.textDim.withValues(alpha: 0.3)
                  : pal.accent,
            ),
          ),
        ),
      ],
    );
  }
}
