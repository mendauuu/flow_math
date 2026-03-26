import 'package:hive/hive.dart';

part 'session_stats.g.dart';

@HiveType(typeId: 0)
class SessionStats extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  int totalProblems;

  @HiveField(2)
  int correctAnswers;

  @HiveField(3)
  int maxStreak;

  @HiveField(4)
  double avgResponseTimeMs;

  @HiveField(5)
  int sessionDurationSeconds;

  @HiveField(6)
  int maxDifficultyReached;

  SessionStats({
    required this.date,
    required this.totalProblems,
    required this.correctAnswers,
    required this.maxStreak,
    required this.avgResponseTimeMs,
    required this.sessionDurationSeconds,
    required this.maxDifficultyReached,
  });

  double get accuracy =>
      totalProblems == 0 ? 0 : correctAnswers / totalProblems * 100;

  /// Focus Score: weighted combination of speed, accuracy, consistency
  double get focusScore {
    if (totalProblems == 0) return 0;
    final accuracyFactor = accuracy / 100; // 0–1
    final speedFactor =
        (avgResponseTimeMs <= 0) ? 0 : (5000 / avgResponseTimeMs).clamp(0, 1);
    final streakFactor = (maxStreak / 20).clamp(0, 1);
    return ((accuracyFactor * 0.5 + speedFactor * 0.3 + streakFactor * 0.2) *
            100)
        .clamp(0, 100);
  }
}

// ── Hand-written adapter (avoids build_runner requirement) ──────────────────

class SessionStatsAdapter extends TypeAdapter<SessionStats> {
  @override
  final int typeId = 0;

  @override
  SessionStats read(BinaryReader reader) {
    return SessionStats(
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      totalProblems: reader.readInt(),
      correctAnswers: reader.readInt(),
      maxStreak: reader.readInt(),
      avgResponseTimeMs: reader.readDouble(),
      sessionDurationSeconds: reader.readInt(),
      maxDifficultyReached: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, SessionStats obj) {
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.totalProblems);
    writer.writeInt(obj.correctAnswers);
    writer.writeInt(obj.maxStreak);
    writer.writeDouble(obj.avgResponseTimeMs);
    writer.writeInt(obj.sessionDurationSeconds);
    writer.writeInt(obj.maxDifficultyReached);
  }
}
