import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/math_problem.dart';
import '../models/practice.dart';
import '../models/session_stats.dart';
import 'difficulty_service.dart';

enum SessionMode { idle, antiScroll, focus }

/// A problem answered wrongly or skipped — shown in the results review.
class Mistake {
  final MathProblem problem;

  /// What the player typed; null when the problem was skipped.
  final int? given;
  const Mistake(this.problem, this.given);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reward event — drives UI celebrations
// ─────────────────────────────────────────────────────────────────────────────
enum RewardEvent {
  none,
  correct, // plain correct
  streakThree, // 3-in-a-row
  streakFive, // 5-in-a-row — triggers level ramp
  streakTen, // 10-in-a-row — major celebration
  streakTwenty, // legendary
  personalBest, // new max streak
  speedBonus, // answered in < 1.5 s
  levelUp, // difficulty just increased
  levelDown, // difficulty decreased (subtle, no fanfare)
}

// ─────────────────────────────────────────────────────────────────────────────
//  SessionService
// ─────────────────────────────────────────────────────────────────────────────
class SessionService extends ChangeNotifier {
  // ── Core state ─────────────────────────────────────────────────────────────
  SessionMode mode = SessionMode.idle;
  MathProblem? currentProblem;
  bool isCorrect = false;
  bool showFeedback = false;
  String feedbackMessage = '';
  RewardEvent lastReward = RewardEvent.none;

  // ── Counters ──────────────────────────────────────────────────────────────
  int streak = 0;
  int maxStreak = 0;
  int totalProblems = 0;
  int correctAnswers = 0;
  int _sessionSecs = 0;
  double _totalMs = 0;

  // ── Flow engine ───────────────────────────────────────────────────────────
  final FlowEngine _flow = FlowEngine();
  int get difficultyLevel => _flow.level;
  double get floatLevel => _flow.floatLevel;
  Map<String, double> get weaknesses => _flow.weakness.all;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _sessionTimer;
  Timer? _problemTimer;
  int problemElapsedMs = 0;
  int get sessionSeconds => _sessionSecs;
  DateTime? _problemStart;

  // ── Session length target (0 = unlimited) ─────────────────────────────────
  int targetSeconds = 0;
  bool get hasTarget => targetSeconds > 0;
  bool get targetReached => hasTarget && _sessionSecs >= targetSeconds;

  /// Completes once the finished session has been written to history.
  Future<void> saved = Future.value();

  // ── Practice configuration ────────────────────────────────────────────────
  PracticeMode practiceMode = PracticeMode.flow;
  Set<Operation>? _allowed;
  double _startLevel = 3;
  int _targetMinutes = 0;

  /// Fixed problem list (Daily challenge); null for generated sessions.
  List<MathProblem>? _queue;
  int get queueLength => _queue?.length ?? 0;

  /// Wrong or skipped problems, for the review on the results screen.
  final List<Mistake> mistakes = [];

  // ── XP & the flow meter ───────────────────────────────────────────────────
  /// XP earned this session.
  int xp = 0;

  /// XP from the last answer (shown as a little "+18 XP").
  int lastXpGain = 0;

  /// 0–1. Fast correct answers fill it; when full you're "in flow".
  double flowMeter = 0;
  bool inFlow = false;

  /// How often flow was reached, and seconds spent in it.
  int flowEntries = 0;
  int flowSeconds = 0;
  int _flowEndsAt = 0;
  static const flowDuration = 20;

  /// Answers per operation type, for the skill map.
  final Map<String, OpTally> opTally = {};

  /// True once the session should end: time is up or the Daily set is done.
  bool get isOver =>
      targetReached || (_queue != null && totalProblems >= _queue!.length);

  // ─────────────────────────────────────────────────────────────────────────
  //  Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// [startLevel] applies to Flow and Sprint (Anti-Scroll always starts easy).
  /// [targetMinutes] ends a Flow session automatically; 0 means no limit.
  /// [allowed] restricts the operation types (topic practice).
  void startSession(
    SessionMode m, {
    double startLevel = 3,
    int targetMinutes = 0,
    PracticeMode practice = PracticeMode.flow,
    Set<Operation>? allowed,
  }) {
    mode = m;
    practiceMode = practice;
    _allowed = practice == PracticeMode.daily ? null : allowed;
    _startLevel = startLevel;
    _targetMinutes = targetMinutes;
    mistakes.clear();

    switch (practice) {
      case PracticeMode.flow:
        targetSeconds = targetMinutes * 60;
        _queue = null;
      case PracticeMode.sprint:
        targetSeconds = PracticeRules.sprintSeconds;
        _queue = null;
      case PracticeMode.daily:
        targetSeconds = 0;
        _queue = ProblemGenerator.dailySet(DateTime.now(),
            count: PracticeRules.dailyCount);
    }

    if (m == SessionMode.antiScroll) {
      _flow.resetToEasy();
    } else {
      _flow.startAt(startLevel);
    }
    _resetCounters();
    _startSessionTimer();
    _nextProblem();
    notifyListeners();
  }

  /// A fresh, already-started session with the same settings ("Again").
  SessionService restarted() => SessionService()
    ..startSession(
      mode == SessionMode.idle ? SessionMode.focus : mode,
      startLevel: _startLevel,
      targetMinutes: _targetMinutes,
      practice: practiceMode,
      allowed: _allowed,
    );

  /// Give up on the current problem: reveal the answer and move on.
  void skip() {
    final p = currentProblem;
    if (p == null || showFeedback || mode == SessionMode.idle) return;

    final elapsed = DateTime.now().difference(_problemStart!).inMilliseconds;
    _totalMs += elapsed;
    totalProblems++;
    _flow.record(correct: false, responseTimeMs: elapsed, typeKey: p.typeKey);

    streak = 0;
    isCorrect = false;
    lastReward = RewardEvent.none;
    mistakes.add(Mistake(p, null));
    (opTally[p.typeKey] ??= OpTally()).add(right: false, ms: elapsed);
    lastXpGain = 0;
    if (!inFlow) flowMeter = max(0, flowMeter - 0.2);
    feedbackMessage = 'Skipped — the answer is ${p.correctAnswer}';
    if (p.hint != null) feedbackMessage += '\n💡 ${p.hint}';
    showFeedback = true;
    notifyListeners();
    _scheduleNext(practiceMode == PracticeMode.sprint ? 700 : 1800);
  }

  void endSession() {
    _sessionTimer?.cancel();
    _problemTimer?.cancel();
    saved = _saveStats();
    mode = SessionMode.idle;
    notifyListeners();
  }

  void submitAnswer(int answer) {
    if (currentProblem == null || showFeedback) return;

    final elapsed = DateTime.now().difference(_problemStart!).inMilliseconds;
    _totalMs += elapsed;
    totalProblems++;

    final correct = answer == currentProblem!.correctAnswer;
    final prevLevel = _flow.level;
    (opTally[currentProblem!.typeKey] ??= OpTally())
        .add(right: correct, ms: elapsed);

    _flow.record(
      correct: correct,
      responseTimeMs: elapsed,
      typeKey: currentProblem!.typeKey,
    );

    // Anti-scroll ramp
    if (mode == SessionMode.antiScroll) {
      _flow.antiScrollRamp(totalProblems);
    }

    // ── Detect reward event ────────────────────────────────────────────────
    lastReward = _detectReward(correct, elapsed, prevLevel);

    if (correct) {
      correctAnswers++;
      streak++;
      if (streak > maxStreak) maxStreak = streak;
      isCorrect = true;
      feedbackMessage = ''; // no text on correct — just reward event
      _earn(currentProblem!, elapsed);
    } else {
      streak = 0;
      isCorrect = false;
      lastXpGain = 0;
      if (!inFlow) flowMeter = max(0, flowMeter - 0.3);
      mistakes.add(Mistake(currentProblem!, answer));
      feedbackMessage = ExplanationEngine.explain(currentProblem!, answer);
      // Append hint if available
      if (currentProblem!.hint != null) {
        feedbackMessage += '\n💡 ${currentProblem!.hint}';
      }
    }

    showFeedback = true;
    notifyListeners();

    // Sprint keeps the pace quick; other modes give time to read feedback.
    final int delay;
    if (practiceMode == PracticeMode.sprint) {
      delay = correct ? 250 : 900;
    } else {
      delay = correct
          ? (lastReward.index >= RewardEvent.streakThree.index ? 900 : 500)
          : 2200;
    }
    _scheduleNext(delay);
  }

  void _scheduleNext(int delayMs) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      // Session ended while feedback was showing — don't restart timers.
      if (mode == SessionMode.idle) return;
      showFeedback = false;
      lastReward = RewardEvent.none;
      _nextProblem();
      notifyListeners();
    });
  }

  // ── Reward detection ──────────────────────────────────────────────────────
  RewardEvent _detectReward(bool correct, int elapsedMs, int prevLevel) {
    if (!correct) return RewardEvent.none;

    final newStreak = streak + 1; // +1 because we haven't incremented yet
    final levelRose = _flow.level > prevLevel;

    if (newStreak > maxStreak && newStreak >= 5) {
      return RewardEvent.personalBest;
    }
    if (newStreak >= 20) return RewardEvent.streakTwenty;
    if (newStreak >= 10) return RewardEvent.streakTen;
    if (newStreak >= 5) return RewardEvent.streakFive;
    if (newStreak >= 3) return RewardEvent.streakThree;
    if (elapsedMs < 1500) return RewardEvent.speedBonus;
    if (levelRose) return RewardEvent.levelUp;
    return RewardEvent.correct;
  }

  // ── Public reward display helpers ─────────────────────────────────────────
  String get rewardEmoji => switch (lastReward) {
        RewardEvent.none => '',
        RewardEvent.correct => '',
        RewardEvent.streakThree => '💫',
        RewardEvent.streakFive => '✨',
        RewardEvent.streakTen => '⚡',
        RewardEvent.streakTwenty => '🔥',
        RewardEvent.personalBest => '🏆',
        RewardEvent.speedBonus => '⚡ FAST',
        RewardEvent.levelUp => '↑',
        RewardEvent.levelDown => '',
      };

  String get streakMessage {
    if (streak >= 20) return '🔥  UNSTOPPABLE';
    if (streak >= 10) return '⚡  ON FIRE';
    if (streak >= 5) return '✨  FLOWING';
    if (streak >= 3) return '💫  $streak in a row';
    return '';
  }

  // ── Computed stats ────────────────────────────────────────────────────────
  double get accuracy =>
      totalProblems == 0 ? 0 : correctAnswers / totalProblems * 100;

  double get focusScore {
    if (totalProblems == 0) return 0;
    final a = accuracy / 100;
    final ms = _totalMs / totalProblems;
    final spd = (5000 / ms).clamp(0.0, 1.0);
    final st = (maxStreak / 20).clamp(0.0, 1.0);
    return ((a * 0.5 + spd * 0.3 + st * 0.2) * 100).clamp(0, 100);
  }

  // ── Private ───────────────────────────────────────────────────────────────
  void _nextProblem() {
    final queue = _queue;
    if (queue != null) {
      if (totalProblems >= queue.length) return; // set finished
      currentProblem = queue[totalProblems];
    } else {
      currentProblem = ProblemGenerator.generate(
        _flow.level,
        weakTypeKey: _flow.weakness.weakestType,
        allowed: _allowed,
      );
    }
    _problemStart = DateTime.now();
    problemElapsedMs = 0;
    _startProblemTimer();
    notifyListeners();
  }

  void _startSessionTimer() {
    _sessionSecs = 0;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSecs++;
      _tickFlow();
      notifyListeners();
    });
  }

  void _startProblemTimer() {
    _problemTimer?.cancel();
    _problemTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_problemStart != null) {
        problemElapsedMs =
            DateTime.now().difference(_problemStart!).inMilliseconds;
        notifyListeners();
      }
    });
  }

  /// XP for a correct answer: harder, longer streaks and faster answers earn
  /// more; everything counts double while in flow. Also fills the meter.
  void _earn(MathProblem p, int elapsedMs) {
    var gain = 6 +
        p.difficultyLevel * 2 +
        min<int>(streak, 10) +
        (elapsedMs < 2500 ? 6 : (elapsedMs < 5000 ? 3 : 0));
    if (inFlow) gain *= 2;
    xp += gain;
    lastXpGain = gain;
    if (!inFlow) {
      flowMeter = min(1, flowMeter + 0.12 + (elapsedMs < 3000 ? 0.06 : 0));
      if (flowMeter >= 1) {
        inFlow = true;
        flowEntries++;
        _flowEndsAt = _sessionSecs + flowDuration;
      }
    }
  }

  /// Once a second: flow runs down its 20 s; otherwise the meter cools.
  void _tickFlow() {
    if (inFlow) {
      flowSeconds++;
      flowMeter = ((_flowEndsAt - _sessionSecs) / flowDuration).clamp(0.0, 1.0);
      if (_sessionSecs >= _flowEndsAt) {
        inFlow = false;
        flowMeter = 0.35; // a head start for the next run
      }
    } else if (flowMeter > 0 && !showFeedback) {
      flowMeter = max(0, flowMeter - 0.008);
    }
  }

  void _resetCounters() {
    xp = lastXpGain = flowEntries = flowSeconds = _flowEndsAt = 0;
    flowMeter = 0;
    inFlow = false;
    opTally.clear();
    streak = maxStreak = totalProblems = correctAnswers = 0;
    _totalMs = 0.0;
    _sessionSecs = 0;
    lastReward = RewardEvent.none;
  }

  Future<void> _saveStats() async {
    if (totalProblems == 0) return;
    final box = Hive.box<SessionStats>('sessions');
    await box.add(SessionStats(
      date: DateTime.now(),
      totalProblems: totalProblems,
      correctAnswers: correctAnswers,
      maxStreak: maxStreak,
      avgResponseTimeMs: _totalMs / totalProblems,
      sessionDurationSeconds: _sessionSecs,
      maxDifficultyReached: _flow.level,
    ));
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _problemTimer?.cancel();
    super.dispose();
  }
}
