import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
//  WeaknessTracker — spaced repetition per operation type
//
//  Each operation type has an "error weight" that rises on wrong answers
//  and decays on correct ones. The highest-weight types get re-drilled.
// ─────────────────────────────────────────────────────────────────────────────
class WeaknessTracker {
  // typeKey → error weight (0.0 – 1.0)
  final Map<String, double> _weights = {};

  void recordResult(String typeKey, bool correct) {
    final cur = _weights[typeKey] ?? 0.0;
    if (correct) {
      // Correct: decay weight toward 0
      _weights[typeKey] = (cur * 0.75).clamp(0.0, 1.0);
    } else {
      // Wrong: boost weight toward 1
      _weights[typeKey] = (cur + 0.30).clamp(0.0, 1.0);
    }
  }

  /// Returns the type key with the highest error weight, or null if all clean.
  String? get weakestType {
    if (_weights.isEmpty) return null;
    final heaviest = _weights.entries
        .where((e) => e.value > 0.25)
        .fold<MapEntry<String, double>?>(
            null, (best, e) => best == null || e.value > best.value ? e : best);
    return heaviest?.key;
  }

  double weightOf(String key) => _weights[key] ?? 0.0;

  Map<String, double> get all => Map.unmodifiable(_weights);

  void reset() => _weights.clear();
}

// ─────────────────────────────────────────────────────────────────────────────
//  FlowEngine — replaces the old DifficultyService
//
//  Uses a proper "flow corridor" algorithm:
//    - Target accuracy band:    70% – 85%   (not too easy, not crushing)
//    - Target response window:  2s  – 8s    (fast enough to feel alive)
//    - Adjusts SMOOTHLY (fractional steps) instead of integer jumps
//    - Separate "momentum" prevents wild swings
//    - Detects "hot streaks" and micro-challenges the user right then
// ─────────────────────────────────────────────────────────────────────────────
class FlowEngine {
  // ── Flow corridor targets ─────────────────────────────────────────────────
  static const _targetAccuracyLo = 0.68; // below → too hard, ease back
  static const _targetAccuracyHi = 0.88; // above → too easy, push up
  static const _targetSpeedLo = 2200; // ms — faster than this = bored
  static const _targetSpeedHi = 9000; // ms — slower than this = struggling

  // ── State ─────────────────────────────────────────────────────────────────
  double _level = 3.0; // float 1.0 – 10.0
  double _momentum = 0.0; // positive = accelerating up, negative = easing back

  final List<bool> _recentCorrect = [];
  final List<int> _recentMs = [];

  final WeaknessTracker weakness = WeaknessTracker();

  // ── Streak hooks (for psychological reward) ───────────────────────────────
  int _consecutiveCorrect = 0;
  int _consecutiveWrong = 0;

  int get level => _level.round().clamp(1, 10);

  // ── Record one answer ────────────────────────────────────────────────────
  void record({
    required bool correct,
    required int responseTimeMs,
    required String typeKey,
  }) {
    // Weakness tracker
    weakness.recordResult(typeKey, correct);

    // Streak counters
    if (correct) {
      _consecutiveCorrect++;
      _consecutiveWrong = 0;
    } else {
      _consecutiveWrong++;
      _consecutiveCorrect = 0;
    }

    // Rolling window (last 8 answers)
    _recentCorrect.add(correct);
    _recentMs.add(responseTimeMs);
    if (_recentCorrect.length > 8) {
      _recentCorrect.removeAt(0);
      _recentMs.removeAt(0);
    }

    _adjustLevel();
  }

  // ── Core flow adjustment ─────────────────────────────────────────────────
  void _adjustLevel() {
    if (_recentCorrect.length < 4) return; // wait for data

    final acc = _recentCorrect.where((b) => b).length / _recentCorrect.length;
    final avgMs = _recentMs.reduce((a, b) => a + b) / _recentMs.length;

    // Direction signal: +1 = push harder, -1 = ease back, 0 = hold
    double signal = 0;

    if (acc > _targetAccuracyHi && avgMs < _targetSpeedHi) {
      signal = 1.0; // crushing it — go harder
    } else if (acc < _targetAccuracyLo || avgMs > _targetSpeedHi) {
      signal = -1.0; // struggling — give relief
    } else if (acc > 0.78 && avgMs < _targetSpeedLo) {
      signal = 0.5; // fast AND accurate — small nudge
    }

    // Hot-streak boost: 5+ correct in a row = sudden micro-challenge
    if (_consecutiveCorrect >= 5) {
      signal = max(signal, 1.5);
    }

    // Struggle guard: 3+ wrong in a row = immediate relief
    if (_consecutiveWrong >= 3) {
      signal = min(signal, -1.5);
    }

    // Momentum smoothing (prevents whiplash)
    _momentum = (_momentum * 0.6 + signal * 0.4);

    // Apply — small fractional steps feel smooth
    final step = _momentum * 0.35;
    _level = (_level + step).clamp(1.0, 10.0);
  }

  // ── Anti-Scroll mode ramp ────────────────────────────────────────────────
  /// Starts at floor=1, ramps gently over [problems] problems.
  void antiScrollRamp(int problemsAnswered) {
    // Ramp from 1 → 4 over first 15 problems then hand off to flow engine
    if (problemsAnswered < 15) {
      final floor = 1.0 + (problemsAnswered / 15) * 3.0;
      if (_level < floor) _level = floor;
    }
  }

  void resetToEasy() {
    _level = 1.5;
    _momentum = 0.0;
    _consecutiveCorrect = 0;
    _consecutiveWrong = 0;
    _recentCorrect.clear();
    _recentMs.clear();
    weakness.reset();
  }

  // ── Diagnostics (used by analyze screen) ─────────────────────────────────
  double get floatLevel => _level;
  double get momentum => _momentum;
  int get hotStreak => _consecutiveCorrect;
}
