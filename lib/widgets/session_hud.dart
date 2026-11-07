import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/palette.dart';

import '../models/practice.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';

class SessionHud extends StatelessWidget {
  final SessionService service;
  final SettingsService settings;
  const SessionHud({super.key, required this.service, required this.settings});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final sprint = service.practiceMode == PracticeMode.sprint;
    final daily = service.practiceMode == PracticeMode.daily;
    final left = max(0, service.targetSeconds - service.sessionSeconds);
    final dim = pal.timerText
        .copyWith(color: pal.textDim.withValues(alpha: 0.55));

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 8, 0),
      child: Row(
        children: [
          if (sprint) ...[
            // Sprint: countdown, turning gold for the last 10 seconds
            Text(_fmt(left),
                style: left <= 10
                    ? pal.timerText.copyWith(
                        color: pal.warm, fontWeight: FontWeight.w700)
                    : pal.timerText),
            Text('  ✓ ${service.correctAnswers}', style: dim),
          ] else ...[
            // Clock (with the session-length goal, if one is set)
            Text(_fmt(service.sessionSeconds), style: pal.timerText),
            if (service.hasTarget)
              Text(' / ${_fmt(service.targetSeconds)}', style: dim),
            if (daily)
              Text(
                  '  ·  ${min(service.totalProblems + 1, service.queueLength)}'
                  ' / ${service.queueLength}',
                  style: dim),
          ],

          SizedBox(width: 12),

          // Weakness drill indicator — shows when engine is re-drilling a weak
          // type. Takes the free space and shortens itself if it's tight.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _showWeaknessTag()
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: pal.chip(true, tint: pal.warm, scale: 0.35),
                      child: Text(
                        '🎯 ${_weakLabel()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8,
                          color: pal.warm,
                          letterSpacing: 1.2,
                        ),
                      ),
                    )
                  : SizedBox(),
            ),
          ),

          // Streak
          if (settings.showStreak && service.streak > 0) ...[
            Icon(Icons.local_fire_department,
                size: 12, color: pal.warm),
            SizedBox(width: 3),
            Text('${service.streak}',
                style: TextStyle(
                    fontSize: 12,
                    color: pal.warm,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            SizedBox(width: 12),
          ],

          // Difficulty bar — now shows float level as partial fill
          _DifficultyBar(level: service.floatLevel),
        ],
      ),
    );
  }

  static String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    final pal = context.palette;
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
          margin: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: fill > 0
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      pal.accent.withValues(alpha: fill * 0.9),
                      pal.accent.withValues(alpha: fill * 0.5),
                    ],
                  )
                : null,
            color: fill == 0 ? pal.textBright.withValues(alpha: 0.08) : null,
          ),
        );
      }),
    );
  }
}
