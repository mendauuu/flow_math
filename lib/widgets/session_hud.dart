import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';

class SessionHud extends StatelessWidget {
  final SessionService service;
  final SettingsService settings;
  const SessionHud({super.key, required this.service, required this.settings});

  @override
  Widget build(BuildContext context) {
    final m = service.sessionSeconds ~/ 60;
    final s = service.sessionSeconds % 60;
    final time =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
      child: Row(
        children: [
          // Clock
          Text(time, style: AppTextStyles.timerText),

          const SizedBox(width: 12),

          // Weakness drill indicator — shows when engine is re-drilling a weak type
          if (_showWeaknessTag())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gold.withOpacity(0.25)),
              ),
              child: Text(
                '🎯 ${_weakLabel()}',
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.gold,
                  letterSpacing: 1.2,
                ),
              ),
            ),

          const Spacer(),

          // Streak
          if (settings.showStreak && service.streak > 0) ...[
            const Icon(Icons.local_fire_department,
                size: 12, color: AppColors.gold),
            const SizedBox(width: 3),
            Text('${service.streak}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(width: 12),
          ],

          // Difficulty bar — now shows float level as partial fill
          _DifficultyBar(level: service.floatLevel),
        ],
      ),
    );
  }

  bool _showWeaknessTag() {
    final weaknesses = service.weaknesses;
    return weaknesses.values.any((w) => w > 0.40);
  }

  String _weakLabel() {
    final weaknesses = service.weaknesses;
    final top = weaknesses.entries
        .where((e) => e.value > 0.40)
        .fold<MapEntry<String, double>?>(
            null, (best, e) => best == null || e.value > best.value ? e : best);
    if (top == null) return '';
    return top.key.toUpperCase().replaceAll('_', ' ');
  }
}

// ── Smooth difficulty bar ─────────────────────────────────────────────────────
class _DifficultyBar extends StatelessWidget {
  final double level; // 1.0 – 10.0
  const _DifficultyBar({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(10, (i) {
        final fill =
            (level - i).clamp(0.0, 1.0); // partial fill for current pip
        return Container(
          width: 3.5,
          height: i < 4
              ? 7
              : i < 7
                  ? 9
                  : 11,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: fill > 0
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.primary.withOpacity(fill * 0.9),
                      AppColors.primary.withOpacity(fill * 0.5),
                    ],
                  )
                : null,
            color: fill == 0 ? Colors.white.withOpacity(0.08) : null,
          ),
        );
      }),
    );
  }
}
