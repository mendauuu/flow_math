import 'package:hive_flutter/hive_flutter.dart';

/// Personal bests and Daily-challenge results, kept in the 'prefs' box.
class MathRecords {
  static Box get _prefs => Hive.box('prefs');
  static const _kBestSprint = 'bestSprint';

  // ── Sprint ────────────────────────────────────────────────────────────────
  static int get bestSprint {
    final v = _prefs.get(_kBestSprint);
    return v is int ? v : 0;
  }

  /// Saves [correct] if it beats the record. Returns true for a new best.
  static Future<bool> submitSprint(int correct) async {
    if (correct <= bestSprint || correct == 0) return false;
    await _prefs.put(_kBestSprint, correct);
    return true;
  }

  // ── Daily challenge ───────────────────────────────────────────────────────
  static String _key(DateTime d) =>
      'daily:${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static ({int correct, int total, int seconds})? dailyResult(DateTime day) {
    final v = _prefs.get(_key(day));
    if (v is! Map) return null;
    final c = v['correct'], t = v['total'], s = v['seconds'];
    if (c is! int || t is! int || s is! int) return null;
    return (correct: c, total: t, seconds: s);
  }

  static ({int correct, int total, int seconds})? get today =>
      dailyResult(DateTime.now());

  /// Only the first full attempt each day counts. Returns true if recorded.
  static Future<bool> submitDaily(int correct, int total, int seconds) async {
    final key = _key(DateTime.now());
    if (_prefs.containsKey(key)) return false;
    await _prefs.put(key, {'correct': correct, 'total': total, 'seconds': seconds});
    return true;
  }

  /// Days in a row with a Daily challenge, counting today or yesterday.
  static int get dailyStreak {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (dailyResult(day) == null) day = DateTime(day.year, day.month, day.day - 1);
    var n = 0;
    while (dailyResult(day) != null) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }
}
