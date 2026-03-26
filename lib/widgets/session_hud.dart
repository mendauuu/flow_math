import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../utils/app_theme.dart';

class SessionHud extends StatelessWidget {
  final SessionService service;
  const SessionHud({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final mins = service.sessionSeconds ~/ 60;
    final secs = service.sessionSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 72, 0),
      child: Row(
        children: [
          // Session clock
          Text(timeStr, style: AppTextStyles.timerText),

          const Spacer(),

          // Streak
          if (service.streak > 0)
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                    size: 12, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  '${service.streak}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),

          const SizedBox(width: 16),

          // Difficulty pip
          Row(
            children: List.generate(10, (i) {
              final active = i < service.difficultyLevel;
              return Container(
                width: 4,
                height: active ? 10 : 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withOpacity(0.7)
                      : AppColors.textDim.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
