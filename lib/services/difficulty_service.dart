/// Tracks answer history and adjusts difficulty to keep user in flow zone.
class DifficultyService {
  int _level = 3; // start at 3/10
  final List<bool> _recentResults = [];
  final List<int> _recentTimesMs = [];

  int get level => _level;

  void record({required bool correct, required int responseTimeMs}) {
    _recentResults.add(correct);
    _recentTimesMs.add(responseTimeMs);
    if (_recentResults.length > 5) {
      _recentResults.removeAt(0);
      _recentTimesMs.removeAt(0);
    }
    _adjust();
  }

  void resetToEasy() {
    _level = 1;
    _recentResults.clear();
    _recentTimesMs.clear();
  }

  void _adjust() {
    if (_recentResults.length < 3) return;

    final correctCount = _recentResults.where((r) => r).length;
    final avgTime = _recentTimesMs.reduce((a, b) => a + b) / _recentTimesMs.length;

    // Fast & accurate → harder
    if (correctCount >= 4 && avgTime < 4000) {
      _level = (_level + 1).clamp(1, 10);
    }
    // Slow or inaccurate → easier
    else if (correctCount <= 1 || avgTime > 12000) {
      _level = (_level - 1).clamp(1, 10);
    }
  }
}
