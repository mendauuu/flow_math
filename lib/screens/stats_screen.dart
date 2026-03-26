import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/session_stats.dart';
import '../utils/app_theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<SessionStats>('sessions');
    final sessions = box.values.toList().reversed.toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.oceanGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.textDim, size: 20),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'YOUR HISTORY',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textDim,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (sessions.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No sessions yet.\nStart flowing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: Colors.white10,
                      height: 1,
                    ),
                    itemBuilder: (_, i) => _SessionTile(stats: sessions[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionStats stats;
  const _SessionTile({required this.stats});

  @override
  Widget build(BuildContext context) {
    final mins = stats.sessionDurationSeconds ~/ 60;
    final secs = stats.sessionDurationSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final dateStr =
        '${stats.date.day}/${stats.date.month}  ${stats.date.hour.toString().padLeft(2, '0')}:${stats.date.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          // Focus score circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                stats.focusScore.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDim,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$timeStr  ·  ${stats.totalProblems} problems  ·  ${stats.accuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '×${stats.maxStreak}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
