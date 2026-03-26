import '../models/math_problem.dart';

class AdaptiveEngine {
  // Track recent performance window
  final List<bool> _recentResults = [];
  final List<int> _recentTimes = []; // ms
  static const int _windowSize = 5;

  // Thresholds
  static const int _fastThresholdMs = 4000;
  static const int _slowThresholdMs = 12000;
  static const double _upgradeAccuracy = 0.8;
  static const double _downgradeAccuracy = 0.5;

  Difficulty currentDifficulty;

  AdaptiveEngine({this.currentDifficulty = Difficulty.beginner});

  void record(bool correct, int timeTakenMs) {
    _recentResults.add(correct);
    _recentTimes.add(timeTakenMs);
    if (_recentResults.length > _windowSize) {
      _recentResults.removeAt(0);
      _recentTimes.removeAt(0);
    }
    _adjust();
  }

  void _adjust() {
    if (_recentResults.length < 3) return;

    final accuracy = _recentResults.where((r) => r).length / _recentResults.length;
    final avgTime = _recentTimes.reduce((a, b) => a + b) / _recentTimes.length;

    final shouldUpgrade = accuracy >= _upgradeAccuracy && avgTime <= _fastThresholdMs;
    final shouldDowngrade = accuracy <= _downgradeAccuracy || avgTime >= _slowThresholdMs;

    if (shouldUpgrade) {
      if (currentDifficulty == Difficulty.beginner) {
        currentDifficulty = Difficulty.intermediate;
        _recentResults.clear();
        _recentTimes.clear();
      } else if (currentDifficulty == Difficulty.intermediate) {
        currentDifficulty = Difficulty.advanced;
        _recentResults.clear();
        _recentTimes.clear();
      }
    } else if (shouldDowngrade) {
      if (currentDifficulty == Difficulty.advanced) {
        currentDifficulty = Difficulty.intermediate;
        _recentResults.clear();
        _recentTimes.clear();
      } else if (currentDifficulty == Difficulty.intermediate) {
        currentDifficulty = Difficulty.beginner;
        _recentResults.clear();
        _recentTimes.clear();
      }
    }
  }

  String get difficultyLabel {
    switch (currentDifficulty) {
      case Difficulty.beginner:
        return 'gentle';
      case Difficulty.intermediate:
        return 'flowing';
      case Difficulty.advanced:
        return 'deep';
    }
  }
}
