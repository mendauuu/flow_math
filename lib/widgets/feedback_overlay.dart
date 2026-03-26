import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class FeedbackOverlay extends StatelessWidget {
  final String message;
  final bool isCorrect;

  const FeedbackOverlay({
    super.key,
    required this.message,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    if (isCorrect && message.isEmpty) {
      // Silent correct — just a brief colour pulse, no text
      return Container(
        height: 48,
        width: double.infinity,
        color: AppColors.correct.withOpacity(0.06),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      color: isCorrect
          ? AppColors.correct.withOpacity(0.06)
          : AppColors.incorrect.withOpacity(0.05),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check : Icons.info_outline,
            size: 14,
            color: isCorrect ? AppColors.correct : AppColors.incorrect,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.feedbackText.copyWith(
                color: isCorrect
                    ? AppColors.correct.withOpacity(0.9)
                    : AppColors.textMid,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
