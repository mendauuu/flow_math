import 'package:hive_flutter/hive_flutter.dart';
import '../models/practice.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Mind level (XP) and the skill map for Flow State math.
// ─────────────────────────────────────────────────────────────────────────────

class MindLevel {
  final int level;
  final int xpIntoLevel;
  final int xpForNext;
  final String title;
  final String emoji;

  const MindLevel({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNext,
    required this.title,
    required this.emoji,
  });

  double get progress => xpForNext <= 0 ? 1 : xpIntoLevel / xpForNext;
  int get xpToNext => xpForNext - xpIntoLevel;
}

class MindLevels {
  /// Titles grow like the scenes: from a seedling to a galaxy.
  static const _titles = [
    (1, 'Seedling', '🌱'),
    (3, 'Sprout', '🌿'),
    (5, 'Sapling', '🪴'),
    (8, 'Young tree', '🌳'),
    (12, 'Old oak', '🌲'),
    (16, 'Forest', '🏞️'),
    (20, 'Mountain', '🏔️'),
    (25, 'Night sky', '🌌'),
    (30, 'Galaxy', '✨'),
  ];

  /// Total XP needed to reach [level] (level 1 starts at 0).
  static int xpToReach(int level) => 75 * (level - 1) * level;

  static (String, String) titleFor(int level) {
    var t = _titles.first;
    for (final x in _titles) {
      if (level >= x.$1) t = x;
    }
    return (t.$2, t.$3);
  }

  /// The next level that brings a new title, if any.
  static (int, String)? nextTitle(int level) {
    for (final x in _titles) {
      if (x.$1 > level) return (x.$1, x.$2);
    }
    return null;
  }

  static MindLevel of(int xp) {
    var level = 1;
    while (xpToReach(level + 1) <= xp) {
      level++;
    }
    final base = xpToReach(level);
    final (title, emoji) = titleFor(level);
    return MindLevel(
      level: level,
      xpIntoLevel: xp - base,
      xpForNext: xpToReach(level + 1) - base,
      title: title,
      emoji: emoji,
    );
  }
}

/// How well one topic is going, from all past answers.
class TopicSkill {
  final MathTopic topic;
  final int attempts;
  final int correct;
  final int totalMs;

  const TopicSkill(this.topic, this.attempts, this.correct, this.totalMs);

  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  /// 0–1: accuracy and speed, trusted more as answers add up.
  double get mastery {
    if (attempts == 0) return 0;
    final avgMs = totalMs / attempts;
    final speed = ((9000 - avgMs) / 7000).clamp(0.0, 1.0);
    final confidence = (attempts / 30).clamp(0.0, 1.0);
    return ((0.7 * accuracy + 0.3 * speed) * confidence).clamp(0.0, 1.0);
  }
}

class MathProgress {
  static Box get _prefs => Hive.box('prefs');
  static const _kXp = 'mathXp';
  static const _kOps = 'mathOps';
  static const _kXpDay = 'mathXpDay';
  static const _kXpToday = 'mathXpToday';

  static int get totalXp {
    final v = _prefs.get(_kXp);
    return v is int ? v : 0;
  }

  static MindLevel get level => MindLevels.of(totalXp);

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static int get todayXp {
    if (_prefs.get(_kXpDay) != _dayKey(DateTime.now())) return 0;
    final v = _prefs.get(_kXpToday);
    return v is int ? v : 0;
  }

  /// Adds a finished session's XP and answers.
  static Future<void> addSession({
    required int xp,
    required Map<String, OpTally> ops,
  }) async {
    await _prefs.put(_kXp, totalXp + xp);
    final today = todayXp;
    await _prefs.put(_kXpDay, _dayKey(DateTime.now()));
    await _prefs.put(_kXpToday, today + xp);

    final all = _opsMap();
    for (final e in ops.entries) {
      final cur = all[e.key] ?? {'a': 0, 'c': 0, 'ms': 0};
      all[e.key] = {
        'a': (cur['a'] ?? 0) + e.value.attempts,
        'c': (cur['c'] ?? 0) + e.value.correct,
        'ms': (cur['ms'] ?? 0) + e.value.totalMs,
      };
    }
    await _prefs.put(_kOps, all);
  }

  static Map<String, Map<String, int>> _opsMap() {
    final raw = _prefs.get(_kOps);
    final out = <String, Map<String, int>>{};
    if (raw is! Map) return out;
    for (final e in raw.entries) {
      final v = e.value;
      if (e.key is! String || v is! Map) continue;
      int n(String k) => v[k] is int ? v[k] as int : 0;
      out[e.key as String] = {'a': n('a'), 'c': n('c'), 'ms': n('ms')};
    }
    return out;
  }

  /// One entry per topic, in the order of [kMathTopics].
  static List<TopicSkill> get skills {
    final ops = _opsMap();
    return [
      for (final t in kMathTopics)
        () {
          var a = 0, c = 0, ms = 0;
          for (final op in t.ops) {
            final s = ops[op.name];
            if (s == null) continue;
            a += s['a']!;
            c += s['c']!;
            ms += s['ms']!;
          }
          return TopicSkill(t, a, c, ms);
        }(),
    ];
  }

  static int get totalAnswers =>
      skills.fold(0, (sum, s) => sum + s.attempts);

  /// The topic most worth practising, once there's enough to judge.
  static TopicSkill? get weakest {
    final played = skills.where((s) => s.attempts >= 8).toList();
    if (played.isEmpty) return null;
    played.sort((a, b) => a.mastery.compareTo(b.mastery));
    return played.first;
  }
}
