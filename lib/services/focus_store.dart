import 'package:hive_flutter/hive_flutter.dart';

/// Focus (anti-procrastination) sessions, stored as plain maps:
///   {date, seconds, task, completed, checkIns, drifts}
class FocusLog {
  static const boxName = 'focus';
  static Box get _box => Hive.box(boxName);

  static Future<void> add({
    required int seconds,
    required String task,
    required bool completed,
    required int checkIns,
    required int drifts,
  }) async {
    await _box.add({
      'date': DateTime.now().millisecondsSinceEpoch,
      'seconds': seconds,
      'task': task,
      'completed': completed,
      'checkIns': checkIns,
      'drifts': drifts,
    });
  }

  static Iterable<Map> get _entries => _box.values.whereType<Map>();

  static int get sessions => _entries.length;

  static int _seconds(Iterable<Map> entries) => entries.fold<int>(0, (sum, e) {
        final s = e['seconds'];
        return sum + (s is int ? s : 0);
      });

  static int get totalMinutes => _seconds(_entries) ~/ 60;

  static int get minutesThisWeek {
    final since =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    return _seconds(_entries.where((e) {
          final d = e['date'];
          return d is int && d >= since;
        })) ~/
        60;
  }

  static Iterable<Map> get _today {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return _entries.where((e) {
      final d = e['date'];
      return d is int && d >= start;
    });
  }

  /// Full focus rounds finished today.
  static int get todayRounds =>
      _today.where((e) => e['completed'] == true).length;

  static int get todayMinutes => _seconds(_today) ~/ 60;

  static Set<DateTime> get days => _entries
      .map((e) => e['date'])
      .whereType<int>()
      .map((ms) {
        final d = DateTime.fromMillisecondsSinceEpoch(ms);
        return DateTime(d.year, d.month, d.day);
      })
      .toSet();

  static Future<void> clear() => _box.clear();
}

/// A distracting thought "parked" during focus, to deal with later.
class ParkedThought {
  final dynamic key;
  final String text;
  final DateTime date;
  final bool done;
  const ParkedThought(this.key, this.text, this.date, this.done);
}

/// The thought parking lot: {text, date, done}.
class ThoughtStore {
  static const boxName = 'thoughts';
  static Box get _box => Hive.box(boxName);

  static Future<void> add(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _box.add({
      'text': t,
      'date': DateTime.now().millisecondsSinceEpoch,
      'done': false,
    });
  }

  /// Newest first.
  static List<ParkedThought> get all {
    final list = <ParkedThought>[];
    for (final key in _box.keys) {
      final v = _box.get(key);
      if (v is! Map) continue;
      final text = v['text'];
      final date = v['date'];
      if (text is! String || date is! int) continue;
      list.add(ParkedThought(key, text,
          DateTime.fromMillisecondsSinceEpoch(date), v['done'] == true));
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static int get openCount => all.where((t) => !t.done).length;

  static Future<void> setDone(dynamic key, bool done) async {
    final v = _box.get(key);
    if (v is! Map) return;
    await _box.put(key, {...v, 'done': done});
  }

  static Future<void> delete(dynamic key) => _box.delete(key);

  static Future<void> clearDone() async {
    final keys = all.where((t) => t.done).map((t) => t.key).toList();
    await _box.deleteAll(keys);
  }
}
