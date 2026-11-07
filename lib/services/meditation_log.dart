import 'package:hive_flutter/hive_flutter.dart';

/// History of meditation sessions, stored as plain maps in their own Hive box
/// (no type adapter needed):
///   {date: millisSinceEpoch, seconds: int, pattern: String, completed: bool}
class MeditationLog {
  static const boxName = 'meditations';
  static Box get _box => Hive.box(boxName);

  static Future<void> add({
    required int seconds,
    required String pattern,
    required bool completed,
  }) async {
    await _box.add({
      'date': DateTime.now().millisecondsSinceEpoch,
      'seconds': seconds,
      'pattern': pattern,
      'completed': completed,
    });
  }

  static Iterable<Map> get _entries => _box.values.whereType<Map>();

  static int get sessions => _entries.length;

  static int get totalMinutes =>
      _entries.fold<int>(0, (sum, e) {
        final s = e['seconds'];
        return sum + (s is int ? s : 0);
      }) ~/
      60;

  /// Calendar days (local midnight) with at least one session.
  static Set<DateTime> get days => _entries
      .map((e) => e['date'])
      .whereType<int>()
      .map((ms) {
        final d = DateTime.fromMillisecondsSinceEpoch(ms);
        return DateTime(d.year, d.month, d.day);
      })
      .toSet();

  /// Consecutive days meditated, counting today or (if not yet) yesterday.
  static int get dayStreak {
    final played = days;
    if (played.isEmpty) return 0;
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!played.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var n = 0;
    while (played.contains(day)) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  static Future<void> clear() => _box.clear();
}
