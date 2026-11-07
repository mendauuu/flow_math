import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/palette.dart';
import '../widgets/themed.dart';
import '../models/practice.dart';
import '../services/audio_service.dart';
import '../services/math_progress.dart';
import '../services/math_records.dart';
import '../services/notification_service.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../widgets/animated_background.dart';
import 'flow_screen.dart';

class ResultsScreen extends StatefulWidget {
  final SessionService service;
  final SettingsService settings;
  final AudioService audio;

  const ResultsScreen({
    super.key,
    required this.service,
    required this.settings,
    required this.audio,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Palette get pal => context.palette;

  bool _newBest = false;
  bool _firstDaily = false;
  bool _showMistakes = false;
  late final int _previousBest;
  late final MindLevel _levelBefore;
  late final MindLevel _levelAfter;

  SessionService get svc => widget.service;

  bool get _dailyComplete =>
      svc.practiceMode == PracticeMode.daily &&
      svc.queueLength > 0 &&
      svc.totalProblems >= svc.queueLength;

  @override
  void initState() {
    super.initState();
    _previousBest = MathRecords.bestSprint; // read before it is updated
    final xpBefore = MathProgress.totalXp;
    _levelBefore = MindLevels.of(xpBefore);
    _levelAfter = MindLevels.of(xpBefore + svc.xp);
    if (_levelAfter.level > _levelBefore.level && widget.settings.haptics) {
      HapticFeedback.heavyImpact();
    }
    _postSessionActions();
  }

  Future<void> _postSessionActions() async {
    if (svc.practiceMode == PracticeMode.sprint && svc.targetReached) {
      final best = await MathRecords.submitSprint(svc.correctAnswers);
      if (mounted && best) setState(() => _newBest = true);
    } else if (_dailyComplete) {
      final first = await MathRecords.submitDaily(
          svc.correctAnswers, svc.queueLength, svc.sessionSeconds);
      if (mounted && first) setState(() => _firstDaily = true);
    }
    // Once the session is in history, refresh streak / weekly reminders.
    // XP and answers feed the Mind level and the skill map.
    await MathProgress.addSession(xp: svc.xp, ops: svc.opTally);
    await svc.saved;
    await NotificationService.sync();
  }

  void _again() {
    final next = svc.restarted();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => FlowScreen(
            service: next, settings: widget.settings, audio: widget.audio),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (svc.practiceMode) {
      PracticeMode.flow => 'SESSION\nCOMPLETE',
      PracticeMode.sprint => 'SPRINT\nCOMPLETE',
      PracticeMode.daily =>
        _dailyComplete ? 'DAILY\nCHALLENGE' : 'DAILY\nPAUSED',
    };
    final chip = _chipText();

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(theme: widget.settings.bgTheme),
          ThemedScrim(0.55),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    children: [
                      SizedBox(height: 40),
                      Text(title,
                          style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w200,
                              color: pal.textBright,
                              height: 1.1,
                              letterSpacing: -0.5)),
                      if (chip != null) ...[
                        SizedBox(height: 14),
                        Align(alignment: Alignment.centerLeft, child: _chip(chip)),
                      ],
                      SizedBox(height: 26),
                      _hero(),
                      SizedBox(height: 16),
                      _statRow([
                        ('TIME', _fmt(svc.sessionSeconds)),
                        ('PROBLEMS', '${svc.totalProblems}'),
                      ]),
                      SizedBox(height: 12),
                      _statRow([
                        ('ACCURACY', '${svc.accuracy.toStringAsFixed(0)}%'),
                        ('MAX STREAK', '${svc.maxStreak}'),
                      ]),
                      SizedBox(height: 16),
                      _xpCard(),
                      if (svc.flowEntries > 0) ...[
                        SizedBox(height: 10),
                        Text(
                            '🌊 In flow ${svc.flowEntries}× · ${_fmt(svc.flowSeconds)} total',
                            style: TextStyle(fontSize: 12, color: pal.warm)),
                      ],
                      if (svc.mistakes.isNotEmpty) ...[
                        SizedBox(height: 24),
                        _mistakesSection(),
                      ],
                      SizedBox(height: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(28, 8, 28, 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: _button('DONE', false,
                            () => Navigator.pop(context)),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: _button('AGAIN', true, _again)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _chipText() {
    switch (svc.practiceMode) {
      case PracticeMode.flow:
        return svc.targetReached
            ? '🎯  ${svc.targetSeconds ~/ 60}-minute goal reached'
            : null;
      case PracticeMode.sprint:
        return _newBest ? '🏆  New personal best!' : null;
      case PracticeMode.daily:
        if (!_dailyComplete) return null;
        if (!_firstDaily) return 'Practice run — your first score today counts';
        final streak = MathRecords.dailyStreak;
        return streak >= 2
            ? '🔥  $streak-day daily streak'
            : "📅  Today's challenge done";
    }
  }

  Widget _hero() {
    final (label, value, sub) = switch (svc.practiceMode) {
      PracticeMode.flow =>
        ('FOCUS SCORE', svc.focusScore.toStringAsFixed(0), '/ 100'),
      PracticeMode.sprint => (
          'CORRECT IN ${PracticeRules.sprintSeconds}s',
          '${svc.correctAnswers}',
          _newBest
              ? 'Previous best: $_previousBest'
              : (_previousBest > 0 ? 'Best: $_previousBest' : ''),
        ),
      PracticeMode.daily => (
          "TODAY'S SCORE",
          '${svc.correctAnswers}',
          '/ ${svc.queueLength}',
        ),
    };
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 28),
      decoration: pal.card(scale: 1.1),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: pal.labelText),
        SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 76,
                fontWeight: FontWeight.w100,
                color: pal.accent,
                height: 1)),
        if (sub.isNotEmpty) ...[
          SizedBox(height: 4),
          Text(sub,
              style: TextStyle(fontSize: 15, color: pal.textDim)),
        ],
      ]),
    );
  }

  Widget _mistakesSection() {
    final list = svc.mistakes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showMistakes = !_showMistakes),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text('REVIEW MISTAKES  (${list.length})',
                    style: pal.labelText),
                Spacer(),
                Icon(
                    _showMistakes
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: pal.textDim,
                    size: 20),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: !_showMistakes
              ? SizedBox(width: double.infinity)
              : Column(
                  children: [
                    SizedBox(height: 8),
                    for (final m in list.take(30)) _mistakeTile(m),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _mistakeTile(Mistake m) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pal.panel(scale: 0.7),
      child: Row(
        children: [
          Expanded(
            child: Text(m.problem.questionText,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    color: pal.textBright)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('= ${m.problem.correctAnswer}',
                  style: TextStyle(
                      fontSize: 15,
                      color: pal.accent,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text(m.given == null ? 'skipped' : 'you: ${m.given}',
                  style: TextStyle(
                      fontSize: 11,
                      color: m.given == null
                          ? pal.textDim
                          : AppColors.incorrect.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: pal.chip(true, tint: pal.warm),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, color: pal.warm, letterSpacing: 0.5)),
      );

  Widget _statRow(List<(String, String)> pair) => Row(
        children: [
          Expanded(child: _tile(pair[0].$1, pair[0].$2)),
          SizedBox(width: 12),
          Expanded(child: _tile(pair[1].$1, pair[1].$2)),
        ],
      );

  Widget _tile(String label, String value) => Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: pal.panel(scale: 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: pal.labelText),
            SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: pal.textBright,
                    height: 1)),
          ],
        ),
      );

  Widget _button(String text, bool primary, VoidCallback onTap) =>
      ThemedButton(label: text, primary: primary, onTap: onTap);

  /// XP earned this session and the Mind level bar filling up.
  Widget _xpCard() {
    final before = _levelBefore;
    final after = _levelAfter;
    final up = after.level > before.level;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: pal.card(tint: pal.warm, active: up),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: pal.chip(true, tint: pal.warm, scale: 0.6),
            child: Text(after.emoji, style: TextStyle(fontSize: 24)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(up ? 'LEVEL UP!  ·  LEVEL ${after.level}' : 'LEVEL ${after.level}',
                    style: pal.labelText.copyWith(color: pal.warm)),
                SizedBox(height: 2),
                Text(after.title,
                    style: TextStyle(fontSize: 16, color: pal.textBright)),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    color: pal.surface.withValues(alpha: 0.7),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: up ? 0 : before.progress, end: after.progress),
                      duration: Duration(milliseconds: 1400),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: v.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: ColoredBox(color: pal.warm),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text('${after.xpToNext} XP to level ${after.level + 1}',
                    style: TextStyle(fontSize: 10, color: pal.textDim)),
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            children: [
              Text('+${svc.xp}',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      color: pal.warm)),
              Text('XP',
                  style: TextStyle(
                      fontSize: 9, color: pal.textDim, letterSpacing: 2)),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}
