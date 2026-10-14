import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/math_problem.dart';
import '../models/session_stats.dart';
import 'difficulty_service.dart';

enum SessionMode { idle, antiScroll, focus }

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
  int _prevLevel = 3;

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

  // ─────────────────────────────────────────────────────────────────────────
  //  Public API
  // ─────────────────────────────────────────────────────────────────────────

  void startSession(SessionMode m) {
    mode = m;
    if (m == SessionMode.antiScroll) _flow.resetToEasy();
    _resetCounters();
    _startSessionTimer();
    _nextProblem();
    notifyListeners();
  }

  void endSession() {
    _sessionTimer?.cancel();
    _problemTimer?.cancel();
    _saveStats();
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
    } else {
      streak = 0;
      isCorrect = false;
      feedbackMessage = ExplanationEngine.explain(currentProblem!, answer);
      // Append hint if available
      if (currentProblem!.hint != null) {
        feedbackMessage += '\n💡 ${currentProblem!.hint}';
      }
    }

    showFeedback = true;
    notifyListeners();

    final delay = correct
        ? (lastReward.index >= RewardEvent.streakThree.index ? 900 : 500)
        : 2200;

    Future.delayed(Duration(milliseconds: delay), () {
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

    if (newStreak > maxStreak && newStreak >= 5)
      return RewardEvent.personalBest;
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
    if (streak >= 3) return '💫  ${streak} in a row';
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
    final weak = _flow.weakness.weakestType;
    currentProblem = ProblemGenerator.generate(
      _flow.level,
      weakTypeKey: weak,
    );
    _problemStart = DateTime.now();
    problemElapsedMs = 0;
    _prevLevel = _flow.level;
    _startProblemTimer();
    notifyListeners();
  }

  void _startSessionTimer() {
    _sessionSecs = 0;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSecs++;
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

  void _resetCounters() {
    streak = maxStreak = totalProblems = correctAnswers = 0;
    _totalMs = 0.0;
    _sessionSecs = 0;
    lastReward = RewardEvent.none;
  }

  static bool shouldShowPaywall() {
    final box = Hive.box<SessionStats>('sessions');
    final prefs = Hive.box('prefs');
    final isPro = prefs.get('isPro', defaultValue: false) as bool;
    if (isPro) return false;
    final shown = prefs.get('paywallShown', defaultValue: false) as bool;
    if (shown) return false;
    return box.length >=
        4; // shown after completing session 5 (0-indexed: length 4 = 5th)
  }

  static Future<void> markPaywallShown() async {
    await Hive.box('prefs').put('paywallShown', true);
  }

  static Future<void> markPro() async {
    await Hive.box('prefs').put('isPro', true);
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
