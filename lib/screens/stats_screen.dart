import 'package:flutter/material.dart';
import '../theme/palette.dart';
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
    final pal = context.palette;
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
        decoration: BoxDecoration(gradient: pal.backdrop),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ───────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: pal.textBright.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: pal.textMid, size: 16),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text('HISTORY',
                        style: TextStyle(
                            fontSize: 11,
                            color: pal.textDim,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600)),
                    Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, a, __) => AnalyzeScreen(),
                            transitionsBuilder: (_, a, __, child) =>
                                FadeTransition(opacity: a, child: child),
                            transitionDuration:
                                Duration(milliseconds: 400),
                          )),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: pal.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: pal.accent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insights_rounded,
                                  color: pal.accent, size: 13),
                              SizedBox(width: 5),
                              Text('ANALYZE',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: pal.accent,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // ── Summary bar ───────────────────────────────────────────────
              if (sessions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _summaryChip(pal, 'SESSIONS', '$totalSessions'),
                      SizedBox(width: 10),
                      _summaryChip(pal, 'TOTAL TIME', _fmtTime(totalTime)),
                      SizedBox(width: 10),
                      _summaryChip(pal,
                          'AVG FOCUS', avgFocus.toStringAsFixed(0)),
                    ],
                  ),
                ),

              SizedBox(height: 20),

              // ── List ──────────────────────────────────────────────────────
              if (sessions.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No sessions yet.\nStep into the forest.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: pal.textDim, fontSize: 16, height: 1.7),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => Divider(
                        color: pal.textBright.withValues(alpha: 0.06), height: 1),
                    itemBuilder: (_, i) => _SessionTile(stats: sessions[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(Palette pal, String label, String value) => Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: pal.textBright.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.textBright.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: pal.textBright)),
              SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 8,
                      color: pal.textDim,
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
    final pal = context.palette;
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
            ? pal.accent
            : pal.textDim;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          // Focus score ring
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: scoreColor.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Center(
              child: Text(score.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scoreColor)),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: TextStyle(
                        fontSize: 11,
                        color: pal.textDim,
                        letterSpacing: 1)),
                SizedBox(height: 4),
                Text(
                    '$timeStr  ·  ${stats.totalProblems} problems  ·  ${stats.accuracy.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 13, color: pal.textMid)),
              ],
            ),
          ),
          // Streak badge
          if (stats.maxStreak >= 3)
            Row(children: [
              Icon(Icons.local_fire_department,
                  size: 12, color: pal.warm),
              SizedBox(width: 2),
              Text('${stats.maxStreak}',
                  style: TextStyle(
                      fontSize: 12,
                      color: pal.warm,
                      fontWeight: FontWeight.w600)),
            ]),
        ],
      ),
    );
  }
}
