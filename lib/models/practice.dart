import 'math_problem.dart';

/// How a math session is played.
enum PracticeMode {
  flow('Flow', '🌊', 'Adaptive practice that meets you at your level'),
  sprint('Sprint', '⚡', '60 seconds. As many as you can.'),
  daily('Daily', '📅', '15 problems, new every day');

  const PracticeMode(this.title, this.emoji, this.description);
  final String title;
  final String emoji;
  final String description;

  static PracticeMode byName(String? name) => PracticeMode.values
      .firstWhere((m) => m.name == name, orElse: () => PracticeMode.flow);
}

/// A group of related operations the player can choose to focus on.
class MathTopic {
  final String id;
  final String name;
  final String symbol;
  final List<Operation> ops;
  const MathTopic(this.id, this.name, this.symbol, this.ops);
}

const List<MathTopic> kMathTopics = [
  MathTopic('addsub', 'Add & subtract', '±',
      [Operation.add, Operation.subtract, Operation.missingAdd]),
  MathTopic('muldiv', 'Times & divide', '×÷',
      [Operation.multiply, Operation.divide, Operation.missingMul]),
  MathTopic('powers', 'Squares & roots', 'x²',
      [Operation.squareOf, Operation.sqrtOf]),
  MathTopic('percent', 'Percentages', '%', [Operation.percentOf]),
  MathTopic('steps', 'Multi-step', '( )', [Operation.doubleStep]),
];

/// Operations for the chosen topic ids (null = everything).
Set<Operation>? opsForTopics(Iterable<String> ids) {
  final chosen = kMathTopics.where((t) => ids.contains(t.id));
  if (chosen.isEmpty) return null;
  return {for (final t in chosen) ...t.ops};
}

/// Answers for one operation type during a session (for the skill map).
class OpTally {
  int attempts = 0;
  int correct = 0;
  int totalMs = 0;

  void add({required bool right, required int ms}) {
    attempts++;
    if (right) correct++;
    totalMs += ms;
  }
}

class PracticeRules {
  static const sprintSeconds = 60;
  static const dailyCount = 15;
}
