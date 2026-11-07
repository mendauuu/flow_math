import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../widgets/themed.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/practice.dart';
import '../services/audio_service.dart';
import '../services/math_progress.dart';
import '../services/math_records.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/skill_radar.dart';
import '../widgets/sound_picker_widget.dart';
import 'flow_screen.dart';

/// Choose how to practise math: Flow, Sprint or the Daily challenge,
/// and which topics to train.
class PracticeScreen extends StatefulWidget {
  final SettingsService settings;
  final AudioService audio;

  const PracticeScreen({
    super.key,
    required this.settings,
    required this.audio,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  Palette get pal => context.palette;

  // Records (best sprint, today's daily) live in the prefs box — rebuild
  // whenever it changes so the badges are fresh after a session.
  final ValueListenable<Box> _prefs = Hive.box('prefs').listenable();

  SettingsService get s => widget.settings;

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_refresh);
  }

  @override
  void dispose() {
    _prefs.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _tick() {
    if (s.haptics) HapticFeedback.selectionClick();
  }

  void _start() {
    if (s.haptics) HapticFeedback.mediumImpact();
    final svc = SessionService()
      ..startSession(
        SessionMode.focus,
        startLevel: s.startLevel.toDouble(),
        targetMinutes: s.sessionTarget,
        practice: s.practiceMode,
        allowed: opsForTopics(s.practiceTopics),
      );
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) =>
            FlowScreen(service: svc, settings: s, audio: widget.audio),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = s.practiceMode;
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(theme: s.bgTheme),
          ThemedScrim(0.5),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                    children: [
                      Text('Train your\nmind.',
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w200,
                              color: pal.textBright,
                              height: 1.12)),
                      SizedBox(height: 8),
                      Text('Pick how you want to play today.',
                          style: TextStyle(fontSize: 13, color: pal.textDim)),
                      SizedBox(height: 20),
                      _levelCard(),
                      SizedBox(height: 22),
                      for (final m in PracticeMode.values) ...[
                        _modeCard(m),
                        SizedBox(height: 10),
                      ],
                      SizedBox(height: 16),
                      _label('SKILL MAP'),
                      _skillMap(),
                      SizedBox(height: 22),
                      if (mode == PracticeMode.daily)
                        _dailyNote()
                      else ...[
                        _label('TOPICS'),
                        _topicChips(),
                        SizedBox(height: 10),
                        Text(
                          s.practiceTopics.isEmpty
                              ? 'A mix of everything, unlocked as you level up.'
                              : 'Only the topics you picked.',
                          style: TextStyle(fontSize: 11, color: pal.textDim),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
                  child: _startButton(mode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return ThemedTopBar(
      title: 'FLOW STATE',
      onBack: () => Navigator.pop(context),
      trailing: SoundPickerWidget(
        audio: widget.audio,
        haptics: s.haptics,
        onChanged: s.setSoundMode,
      ),
    );
  }

  /// Mind level: title, progress to the next level and today's XP.
  Widget _levelCard() {
    final l = MathProgress.level;
    final today = MathProgress.todayXp;
    final next = MindLevels.nextTitle(l.level);
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: pal.card(tint: pal.warm),
      child: Row(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: pal.chip(true, tint: pal.warm, scale: 0.6),
            child: Text(l.emoji, style: TextStyle(fontSize: 26)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('LEVEL ${l.level}',
                        style: pal.labelText.copyWith(color: pal.warm)),
                    SizedBox(width: 8),
                    // Shortens itself on narrow phones instead of overflowing.
                    Expanded(
                      child: Text(today > 0 ? '+$today XP today' : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 10, color: pal.textDim)),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(l.title,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: pal.textBright)),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    color: pal.surface.withValues(alpha: 0.7),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: l.progress),
                      duration: Duration(milliseconds: 900),
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
                SizedBox(height: 5),
                Text(
                    next == null
                        ? '${l.xpToNext} XP to level ${l.level + 1}'
                        : '${l.xpToNext} XP to level ${l.level + 1} · '
                            '${next.$2} at level ${next.$1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: pal.textDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _shortTopic = {
    'addsub': 'Add / sub',
    'muldiv': 'Times / div',
    'powers': 'Powers',
    'percent': 'Percent',
    'steps': 'Multi-step',
  };

  /// How each topic is going, and the one most worth practising.
  Widget _skillMap() {
    final skills = MathProgress.skills;
    final total = skills.fold<int>(0, (sum, k) => sum + k.attempts);
    final weakest = MathProgress.weakest;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: pal.panel(),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: SkillRadar(
              values: [for (final k in skills) k.mastery],
              labels: [
                for (final k in skills)
                  '${_shortTopic[k.topic.id] ?? k.topic.name}\n'
                      '${(k.mastery * 100).round()}%',
              ],
            ),
          ),
          SizedBox(height: 8),
          if (total == 0)
            Text('Play a few rounds and your skill map will grow here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: pal.textDim))
          else if (weakest == null)
            Text('A few more answers and we\'ll spot your weak spot.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: pal.textDim))
          else
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: 'Needs love: ',
                          style: TextStyle(color: pal.textDim)),
                      TextSpan(
                          text: weakest.topic.name,
                          style: TextStyle(
                              color: pal.textBright,
                              fontWeight: FontWeight.w600)),
                    ]),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Pressable(
                  onTap: () => _practiseTopic(weakest.topic),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pal.chip(true),
                    child: Text('PRACTISE IT',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: pal.accent,
                            letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _practiseTopic(MathTopic topic) {
    _tick();
    s.setPracticeMode(PracticeMode.flow);
    s.setOnlyTopic(topic.id);
    showThemedToast(
        context, 'Flow set to ${topic.name} — tap Start when ready');
  }

  Widget _modeCard(PracticeMode m) {
    final active = s.practiceMode == m;
    final today = MathRecords.today;
    final badge = switch (m) {
      PracticeMode.flow =>
        s.sessionTarget == 0 ? 'No limit' : '${s.sessionTarget} min',
      PracticeMode.sprint => MathRecords.bestSprint > 0
          ? 'Best ${MathRecords.bestSprint}'
          : 'No record',
      PracticeMode.daily =>
        today != null ? '✓ ${today.correct}/${today.total}' : 'New today',
    };
    return Pressable(
      onTap: () {
        _tick();
        s.setPracticeMode(m);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 260),
        padding: EdgeInsets.all(14),
        decoration: active ? pal.card(active: true) : pal.panel(),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 260),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: pal.chip(active, scale: 0.6),
              child: Text(m.emoji, style: TextStyle(fontSize: 21)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title.toUpperCase(),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: active ? pal.accent : pal.textMid)),
                  SizedBox(height: 3),
                  Text(m.description,
                      style: TextStyle(fontSize: 12, color: pal.textDim)),
                ],
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: pal.panel(scale: 0.5),
              child: Text(badge,
                  style: TextStyle(fontSize: 10, color: pal.textMid)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topicChips() {
    final all = s.practiceTopics.isEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _topicChip('∞', 'Everything', all, () {
          _tick();
          s.clearPracticeTopics();
        }),
        for (final t in kMathTopics)
          _topicChip(t.symbol, t.name, !all && s.practiceTopics.contains(t.id),
              () {
            _tick();
            s.togglePracticeTopic(t.id);
          }),
      ],
    );
  }

  Widget _topicChip(
      String symbol, String label, bool active, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: pal.chip(active),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(minWidth: 28),
              height: 26,
              padding: EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.textBright.withValues(alpha: active ? 0.10 : 0.05),
                borderRadius: pal.corners(0.4),
              ),
              child: Text(symbol,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? pal.accent : pal.textMid)),
            ),
            SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? pal.accent : pal.textDim,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _dailyNote() {
    final today = MathRecords.today;
    final streak = MathRecords.dailyStreak;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: pal.card(tint: pal.warm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Everyone gets the same 15 problems today, from easy to tricky. '
              'Your first try is the one that counts.',
              style: TextStyle(fontSize: 13, color: pal.textMid, height: 1.5)),
          if (today != null) ...[
            SizedBox(height: 10),
            Text(
                'Today: ${today.correct}/${today.total} in ${_fmt(today.seconds)} — '
                'come back tomorrow for a new set.',
                style: TextStyle(fontSize: 12, color: pal.warm)),
          ],
          if (streak >= 2) ...[
            SizedBox(height: 8),
            Text('🔥 $streak-day daily streak',
                style: TextStyle(
                    fontSize: 12,
                    color: pal.warm,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _startButton(PracticeMode mode) {
    final label = switch (mode) {
      PracticeMode.flow => 'START FLOW',
      PracticeMode.sprint => 'START SPRINT',
      PracticeMode.daily => MathRecords.today == null
          ? "START TODAY'S CHALLENGE"
          : 'PRACTISE AGAIN',
    };
    return ThemedButton(label: label, onTap: _start);
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                color: pal.textDim,
                letterSpacing: 3,
                fontWeight: FontWeight.w600)),
      );

  static String _fmt(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
