import 'dart:math';

enum Operation { add, subtract, multiply, divide }

class MathProblem {
  final int a;
  final int b;
  final Operation operation;
  final int correctAnswer;
  final int difficultyLevel;

  const MathProblem({
    required this.a,
    required this.b,
    required this.operation,
    required this.correctAnswer,
    required this.difficultyLevel,
  });

  String get questionText {
    final symbol = switch (operation) {
      Operation.add => '+',
      Operation.subtract => '−',
      Operation.multiply => '×',
      Operation.divide => '÷',
    };
    return '$a  $symbol  $b';
  }
}

class MathGenerator {
  static final _rng = Random();

  static MathProblem generate(int difficulty) {
    difficulty = difficulty.clamp(1, 10);
    final ops = _opsForDifficulty(difficulty);
    final op = ops[_rng.nextInt(ops.length)];
    return _buildProblem(op, difficulty);
  }

  static List<Operation> _opsForDifficulty(int d) {
    if (d <= 2) return [Operation.add, Operation.subtract];
    if (d <= 4) return [Operation.add, Operation.subtract, Operation.multiply];
    return Operation.values;
  }

  static MathProblem _buildProblem(Operation op, int d) {
    int a, b, answer;
    switch (op) {
      case Operation.add:
        final m = _maxForDiff(d, 100);
        a = _rng.nextInt(m) + 1;
        b = _rng.nextInt(m) + 1;
        answer = a + b;
      case Operation.subtract:
        final m = _maxForDiff(d, 100);
        a = _rng.nextInt(m) + 1;
        b = _rng.nextInt(a) + 1;
        answer = a - b;
      case Operation.multiply:
        a = _rng.nextInt(_maxForDiff(d, 20)) + 1;
        b = _rng.nextInt(_maxForDiff(d, 12)) + 1;
        answer = a * b;
      case Operation.divide:
        b = _rng.nextInt(_maxForDiff(d, 12)) + 1;
        answer = _rng.nextInt(_maxForDiff(d, 20)) + 1;
        a = answer * b;
    }
    return MathProblem(a: a, b: b, operation: op, correctAnswer: answer, difficultyLevel: d);
  }

  static int _maxForDiff(int d, int ceiling) =>
      ((d / 10) * ceiling).round().clamp(1, ceiling);
}

class ExplanationEngine {
  static String explain(MathProblem p, int wrongAnswer) {
    final correct = p.correctAnswer;
    switch (p.operation) {
      case Operation.add:
        final diff = (wrongAnswer - correct).abs();
        if (diff == 1) return "Almost! Off by 1 — check your units digit.";
        final carry = (p.a % 10) + (p.b % 10);
        if (carry >= 10 && wrongAnswer == correct - 10) {
          return "Don't forget to carry the 1 when digits sum ≥ 10.";
        }
        return "${p.a} + ${p.b} = $correct";
      case Operation.subtract:
        if (wrongAnswer == p.b - p.a) return "You subtracted in reverse. Answer: $correct";
        return "Check your borrowing. ${p.a} − ${p.b} = $correct";
      case Operation.multiply:
        if (wrongAnswer == p.a + p.b) return "You added instead of multiplied. Answer: $correct";
        return "${p.a} × ${p.b} = $correct";
      case Operation.divide:
        return "${p.a} ÷ ${p.b} = $correct";
    }
  }
}
