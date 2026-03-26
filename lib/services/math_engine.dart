import 'dart:math';
import '../models/math_problem.dart';

class MathEngine {
  static final Random _rng = Random();

  static MathProblem generate(Difficulty difficulty) {
    final op = _pickOperation(difficulty);
    return _build(op, difficulty);
  }

  static Operation _pickOperation(Difficulty difficulty) {
    final ops = Operation.values;
    if (difficulty == Difficulty.beginner) {
      return ops[_rng.nextInt(2)]; // only + and -
    }
    return ops[_rng.nextInt(ops.length)];
  }

  static MathProblem _build(Operation op, Difficulty difficulty) {
    int a, b, answer;
    String expression;

    switch (difficulty) {
      case Difficulty.beginner:
        a = _rng.nextInt(10) + 1;
        b = _rng.nextInt(10) + 1;
        break;
      case Difficulty.intermediate:
        a = _rng.nextInt(90) + 10;
        b = _rng.nextInt(50) + 5;
        break;
      case Difficulty.advanced:
        a = _rng.nextInt(900) + 100;
        b = _rng.nextInt(100) + 10;
        break;
    }

    switch (op) {
      case Operation.addition:
        answer = a + b;
        expression = '$a + $b';
        break;
      case Operation.subtraction:
        if (b > a) {
          final tmp = a;
          a = b;
          b = tmp;
        }
        answer = a - b;
        expression = '$a − $b';
        break;
      case Operation.multiplication:
        // Keep multiplication manageable
        if (difficulty == Difficulty.intermediate) {
          a = _rng.nextInt(20) + 2;
          b = _rng.nextInt(12) + 2;
        } else if (difficulty == Difficulty.advanced) {
          a = _rng.nextInt(50) + 10;
          b = _rng.nextInt(20) + 2;
        }
        answer = a * b;
        expression = '$a × $b';
        break;
      case Operation.division:
        // Generate clean division
        b = _rng.nextInt(difficulty == Difficulty.beginner ? 5 : 12) + 2;
        final quotient = _rng.nextInt(difficulty == Difficulty.beginner ? 5 : 20) + 1;
        a = b * quotient;
        answer = quotient;
        expression = '$a ÷ $b';
        break;
    }

    return MathProblem(
      a: a,
      b: b,
      operation: op,
      answer: answer,
      expression: expression,
    );
  }

  /// Rule-based explanation for wrong answers
  static String explain(MathProblem problem, int userAnswer) {
    final diff = (userAnswer - problem.answer).abs();

    switch (problem.operation) {
      case Operation.addition:
        if (diff == 10 || diff == 100) {
          return 'Check your carrying — looks like you missed a digit.';
        }
        if (userAnswer < problem.answer) {
          return 'Your sum is a bit low. Try adding again step by step.';
        }
        return 'Your sum is a bit high. Double-check each digit.';

      case Operation.subtraction:
        if (diff == 10 || diff == 100) {
          return 'Borrowing might have slipped. Recheck the tens column.';
        }
        return 'Try subtracting from right to left, one digit at a time.';

      case Operation.multiplication:
        if (userAnswer == problem.a + problem.b) {
          return 'That\'s addition, not multiplication. Multiply instead.';
        }
        if (diff <= problem.b) {
          return 'Close! You may have miscounted one group.';
        }
        return 'Break it down: ${problem.a} groups of ${problem.b}.';

      case Operation.division:
        if (userAnswer == problem.a * problem.b) {
          return 'That\'s multiplication — you want the opposite here.';
        }
        return '${problem.a} ÷ ${problem.b}: how many times does ${problem.b} fit into ${problem.a}?';
    }
  }
}
