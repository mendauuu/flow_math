import 'package:flutter/material.dart';
import '../models/math_problem.dart';
import '../utils/app_theme.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Operation label
        Text(
          _opLabel(problem.operation),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textDim,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 20),

        // The math problem
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            problem.questionText,
            key: ValueKey(problem.questionText),
            style: AppTextStyles.problemText,
          ),
        ),

        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 1,
          color: AppColors.textDim.withOpacity(0.2),
        ),
        const SizedBox(height: 20),

        // Answer input display
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: inputBuffer.isEmpty
                    ? AppColors.textDim.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          child: Text(
            inputBuffer.isEmpty ? '?' : inputBuffer,
            style: AppTextStyles.answerText.copyWith(
              color: inputBuffer.isEmpty
                  ? AppColors.textDim.withOpacity(0.3)
                  : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  String _opLabel(Operation op) => switch (op) {
    Operation.add => 'ADDITION',
    Operation.subtract => 'SUBTRACTION',
    Operation.multiply => 'MULTIPLICATION',
    Operation.divide => 'DIVISION',
  };
}
