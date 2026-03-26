import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/math_problem.dart';
import '../models/session_stats.dart';
import 'difficulty_service.dart';

enum SessionMode { idle, antiScroll, focus }

class SessionService extends ChangeNotifier {
  // ── State ────────────────────────────────────────────────────────────────
  SessionMode mode = SessionMode.idle;
  MathProblem? currentProblem;
  bool isCorrect = false;
  bool showFeedback = false;
  String feedbackMessage = '';

  int streak = 0;
  int maxStreak = 0;
  int totalProblems = 0;
  int correctAnswers = 0;
  int _sessionSeconds = 0;
  double _totalResponseMs = 0;

  final DifficultyService _difficulty = DifficultyService();
  int get difficultyLevel => _difficulty.level;

  // Timers
  Timer? _sessionTimer;
  Timer? _problemTimer;
  int problemElapsedMs = 0;
  int get sessionSeconds => _sessionSeconds;

  DateTime? _problemStart;

  // ── Public API ───────────────────────────────────────────────────────────

  void startSession(SessionMode m) {
    mode = m;
    if (m == SessionMode.antiScroll) _difficulty.resetToEasy();
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
    _totalResponseMs += elapsed;
    totalProblems++;

    final correct = answer == currentProblem!.correctAnswer;

    _difficulty.record(correct: correct, responseTimeMs: elapsed);

    if (correct) {
      correctAnswers++;
      streak++;
      if (streak > maxStreak) maxStreak = streak;
      isCorrect = true;
      feedbackMessage = _streakMessage();
    } else {
      streak = 0;
      isCorrect = false;
      feedbackMessage = ExplanationEngine.explain(currentProblem!, answer);
    }

    showFeedback = true;
    notifyListeners();

    // Brief feedback pause then continue flow
    Future.delayed(Duration(milliseconds: correct ? 600 : 1800), () {
      showFeedback = false;
      _nextProblem();
      notifyListeners();
    });
  }

  double get accuracy =>
      totalProblems == 0 ? 0 : correctAnswers / totalProblems * 100;

  double get focusScore {
    if (totalProblems == 0) return 0;
    final a = accuracy / 100;
    final avgMs = totalProblems == 0 ? 5000 : _totalResponseMs / totalProblems;
    final s = (5000 / avgMs).clamp(0, 1);
    final st = (maxStreak / 20).clamp(0, 1);
    return ((a * 0.5 + s * 0.3 + st * 0.2) * 100).clamp(0, 100);
  }

  // ── Private ──────────────────────────────────────────────────────────────

  void _nextProblem() {
    currentProblem = MathGenerator.generate(_difficulty.level);
    _problemStart = DateTime.now();
    problemElapsedMs = 0;
    _startProblemTimer();
    notifyListeners();
  }

  void _startSessionTimer() {
    _sessionSeconds = 0;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
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
    streak = 0;
    maxStreak = 0;
    totalProblems = 0;
    correctAnswers = 0;
    _totalResponseMs = 0;
    _sessionSeconds = 0;
  }

  Future<void> _saveStats() async {
    final box = Hive.box<SessionStats>('sessions');
    final stats = SessionStats(
      date: DateTime.now(),
      totalProblems: totalProblems,
      correctAnswers: correctAnswers,
      maxStreak: maxStreak,
      avgResponseTimeMs:
          totalProblems == 0 ? 0 : _totalResponseMs / totalProblems,
      sessionDurationSeconds: _sessionSeconds,
      maxDifficultyReached: _difficulty.level,
    );
    await box.add(stats);
  }

  String _streakMessage() {
    if (streak >= 20) return '🔥 UNSTOPPABLE';
    if (streak >= 10) return '⚡ ON FIRE';
    if (streak >= 5) return '✨ FLOWING';
    if (streak >= 3) return '💫 Nice streak!';
    return '';
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _problemTimer?.cancel();
    super.dispose();
  }
}
