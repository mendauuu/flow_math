import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/session_stats.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import 'analyze_screen.dart';

class StatsScreen extends StatelessWidget {
  final SettingsService settings;
  const StatsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<SessionStats>('sessions');
    final sessions = box.values.toList().reversed.toList();

    // Summary aggregates
    final totalSessions = sessions.length;
    final totalTime = sessions.fold(0, (s, e) => s + e.sessionDurationSeconds);
    final avgFocus = sessions.isEmpty
        ? 0.0
        : sessions.fold(0.0, (s, e) => s + e.focusScore) / sessions.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.oceanGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textMid, size: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('HISTORY',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textDim,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, a, __) => const AnalyzeScreen(),
                            transitionsBuilder: (_, a, __, child) =>
                                FadeTransition(opacity: a, child: child),
                            transitionDuration:
                                const Duration(milliseconds: 400),
                          )),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.25)),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.insights_rounded,
                                  color: AppColors.primary, size: 13),
                              SizedBox(width: 5),
                              Text('ANALYZE',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.primary,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Summary bar ───────────────────────────────────────────────
              if (sessions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _summaryChip('SESSIONS', '$totalSessions'),
                      const SizedBox(width: 10),
                      _summaryChip('TOTAL TIME', _fmtTime(totalTime)),
                      const SizedBox(width: 10),
                      _summaryChip(
                          'AVG FOCUS', '${avgFocus.toStringAsFixed(0)}'),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // ── List ──────────────────────────────────────────────────────
              if (sessions.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No sessions yet.\nStep into the forest.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textDim, fontSize: 16, height: 1.7),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withOpacity(0.06), height: 1),
                    itemBuilder: (_, i) => _SessionTile(stats: sessions[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textBright)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textDim,
                      letterSpacing: 1.5)),
            ],
          ),
        ),
      );

  String _fmtTime(int secs) {
    final m = secs ~/ 60;
    return m < 60 ? '${m}m' : '${m ~/ 60}h ${m % 60}m';
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

    final d = stats.date;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final score = stats.focusScore;
    final scoreColor = score >= 70
        ? AppColors.correct
        : score >= 40
            ? AppColors.primary
            : AppColors.textDim;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          // Focus score ring
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: scoreColor.withOpacity(0.35), width: 1.5),
            ),
            child: Center(
              child: Text(score.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scoreColor)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDim,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(
                    '$timeStr  ·  ${stats.totalProblems} problems  ·  ${stats.accuracy.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMid)),
              ],
            ),
          ),
          // Streak badge
          if (stats.maxStreak >= 3)
            Row(children: [
              const Icon(Icons.local_fire_department,
                  size: 12, color: AppColors.gold),
              const SizedBox(width: 2),
              Text('${stats.maxStreak}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600)),
            ]),
        ],
      ),
    );
  }
}
