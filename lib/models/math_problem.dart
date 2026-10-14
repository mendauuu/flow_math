import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
//  Problem types — expanded
// ─────────────────────────────────────────────────────────────────────────────
enum Operation {
  add,
  subtract,
  multiply,
  divide,
  missingAdd, // _  + 4 = 11   (solve for ?)
  missingMul, // 3  × _ = 21
  doubleStep, // (a + b) × c   (shown as "a + b × c = ?")
  percentOf, // 20% of 80
  squareOf, // 7² = ?
  sqrtOf, // √49 = ?
}

// ─────────────────────────────────────────────────────────────────────────────
//  MathProblem — richer, carries hints
// ─────────────────────────────────────────────────────────────────────────────
class MathProblem {
  final int a;
  final int b;
  final int? c; // third operand for double-step
  final Operation operation;
  final int correctAnswer;
  final int difficultyLevel;
  final String? hint; // short hint shown AFTER wrong answer
  final String typeKey; // for spaced-repetition weakness tracking

  const MathProblem({
    required this.a,
    required this.b,
    this.c,
    required this.operation,
    required this.correctAnswer,
    required this.difficultyLevel,
    this.hint,
    required this.typeKey,
  });

  // ── Display ──────────────────────────────────────────────────────────────
  String get questionText {
    return switch (operation) {
      Operation.add => '$a  +  $b',
      Operation.subtract => '$a  −  $b',
      Operation.multiply => '$a  ×  $b',
      Operation.divide => '$a  ÷  $b',
      Operation.missingAdd => '?  +  $b  =  ${a + b}',
      Operation.missingMul => '$a  ×  ?  =  ${a * b}',
      Operation.doubleStep => '($a + $b)  ×  ${c ?? 1}',
      Operation.percentOf => '$a%  of  $b',
      Operation.squareOf => '$a²',
      Operation.sqrtOf => '√$a',
    };
  }

  String get operationLabel => switch (operation) {
        Operation.add => 'ADDITION',
        Operation.subtract => 'SUBTRACTION',
        Operation.multiply => 'MULTIPLICATION',
        Operation.divide => 'DIVISION',
        Operation.missingAdd => 'MISSING NUMBER',
        Operation.missingMul => 'MISSING NUMBER',
        Operation.doubleStep => 'MULTI-STEP',
        Operation.percentOf => 'PERCENTAGE',
        Operation.squareOf => 'SQUARES',
        Operation.sqrtOf => 'SQUARE ROOT',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  ProblemGenerator — smarter, parameterised per difficulty band
// ─────────────────────────────────────────────────────────────────────────────
class ProblemGenerator {
  static final _rng = Random();

  /// Generate a problem at [difficulty] (1–10), optionally biasing toward
  /// a specific [weakTypeKey] (spaced-repetition re-exposure).
  static MathProblem generate(int difficulty, {String? weakTypeKey}) {
    difficulty = difficulty.clamp(1, 10);

    // If we have a weak type key, 40% chance to drill it
    if (weakTypeKey != null && _rng.nextDouble() < 0.40) {
      final op = _opFromKey(weakTypeKey);
      if (op != null) return _build(op, difficulty);
    }

    final op = _pickOp(difficulty);
    return _build(op, difficulty);
  }

  static Operation _pickOp(int d) {
    // Each band unlocks more operation types
    final pool = <Operation>[];

    // Always available
    pool.addAll([Operation.add, Operation.add, Operation.subtract]);

    if (d >= 2) pool.add(Operation.multiply);
    if (d >= 3) pool.addAll([Operation.multiply, Operation.missingAdd]);
    if (d >= 4) pool.add(Operation.divide);
    if (d >= 5) pool.addAll([Operation.missingMul, Operation.squareOf]);
    if (d >= 6) pool.add(Operation.percentOf);
    if (d >= 7) pool.addAll([Operation.doubleStep, Operation.sqrtOf]);
    if (d >= 8) pool.addAll([Operation.doubleStep, Operation.doubleStep]);

    return pool[_rng.nextInt(pool.length)];
  }

  static Operation? _opFromKey(String key) {
    for (final op in Operation.values) {
      if (op.name == key) return op;
    }
    return null;
  }

  static MathProblem _build(Operation op, int d) {
    switch (op) {
      case Operation.add:
        return _add(d);
      case Operation.subtract:
        return _sub(d);
      case Operation.multiply:
        return _mul(d);
      case Operation.divide:
        return _div(d);
      case Operation.missingAdd:
        return _missingAdd(d);
      case Operation.missingMul:
        return _missingMul(d);
      case Operation.doubleStep:
        return _doubleStep(d);
      case Operation.percentOf:
        return _percent(d);
      case Operation.squareOf:
        return _square(d);
      case Operation.sqrtOf:
        return _sqrt(d);
    }
  }

  // ── Individual builders ───────────────────────────────────────────────────

  static MathProblem _add(int d) {
    final max = _scale(d, lo: 5, hi: 999);
    final a = _rng.nextInt(max) + 1;
    final b = _rng.nextInt(max) + 1;
    return MathProblem(
      a: a,
      b: b,
      operation: Operation.add,
      correctAnswer: a + b,
      difficultyLevel: d,
      hint: (a % 10) + (b % 10) >= 10
          ? 'Carry the 1 from the units column.'
          : null,
      typeKey: Operation.add.name,
    );
  }

  static MathProblem _sub(int d) {
    final max = _scale(d, lo: 5, hi: 999);
    final b = _rng.nextInt(max) + 1;
    final a = b + _rng.nextInt(max) + 1;
    return MathProblem(
      a: a,
      b: b,
      operation: Operation.subtract,
      correctAnswer: a - b,
      difficultyLevel: d,
      hint: a % 10 < b % 10 ? 'You need to borrow from the tens column.' : null,
      typeKey: Operation.subtract.name,
    );
  }

  static MathProblem _mul(int d) {
    final maxA = _scale(d, lo: 2, hi: 25);
    final maxB = _scale(d, lo: 2, hi: 12);
    final a = _rng.nextInt(maxA) + 2;
    final b = _rng.nextInt(maxB) + 2;
    return MathProblem(
      a: a,
      b: b,
      operation: Operation.multiply,
      correctAnswer: a * b,
      difficultyLevel: d,
      hint: 'Try: $a × ${b - 1} = ${a * (b - 1)}, then add $a.',
      typeKey: Operation.multiply.name,
    );
  }

  static MathProblem _div(int d) {
    final maxB = _scale(d, lo: 2, hi: 12);
    final maxAns = _scale(d, lo: 2, hi: 25);
    final b = _rng.nextInt(maxB) + 2;
    final answer = _rng.nextInt(maxAns) + 2;
    final a = answer * b;
    return MathProblem(
      a: a,
      b: b,
      operation: Operation.divide,
      correctAnswer: answer,
      difficultyLevel: d,
      hint: 'Ask: $b × ? = $a',
      typeKey: Operation.divide.name,
    );
  }

  static MathProblem _missingAdd(int d) {
    final max = _scale(d, lo: 5, hi: 200);
    final missing = _rng.nextInt(max) + 1;
    final b = _rng.nextInt(max) + 1;
    // shows: ? + b = missing+b
    return MathProblem(
      a: missing,
      b: b,
      operation: Operation.missingAdd,
      correctAnswer: missing,
      difficultyLevel: d,
      hint: 'Subtract $b from ${missing + b}.',
      typeKey: Operation.missingAdd.name,
    );
  }

  static MathProblem _missingMul(int d) {
    final maxA = _scale(d, lo: 2, hi: 12);
    final maxAns = _scale(d, lo: 2, hi: 12);
    final a = _rng.nextInt(maxA) + 2;
    final answer = _rng.nextInt(maxAns) + 2;
    // shows: a × ? = a*answer
    return MathProblem(
      a: a,
      b: answer,
      operation: Operation.missingMul,
      correctAnswer: answer,
      difficultyLevel: d,
      hint: 'Divide ${a * answer} by $a.',
      typeKey: Operation.missingMul.name,
    );
  }

  static MathProblem _doubleStep(int d) {
    final maxAB = _scale(d, lo: 2, hi: 15);
    final maxC = _scale(d, lo: 2, hi: 9);
    final a = _rng.nextInt(maxAB) + 1;
    final b = _rng.nextInt(maxAB) + 1;
    final c = _rng.nextInt(maxC) + 2;
    return MathProblem(
      a: a,
      b: b,
      c: c,
      operation: Operation.doubleStep,
      correctAnswer: (a + b) * c,
      difficultyLevel: d,
      hint: 'Step 1: $a + $b = ${a + b}.  Step 2: ${a + b} × $c.',
      typeKey: Operation.doubleStep.name,
    );
  }

  static MathProblem _percent(int d) {
    // Nice percentages: 10, 20, 25, 50, 75
    const pcts = [10, 20, 25, 50, 75];
    final pct = pcts[_rng.nextInt(pcts.length)];
    // Base number divisible by 4 (so answers are integers)
    final maxBase = _scale(d, lo: 20, hi: 200);
    final base = ((_rng.nextInt(maxBase ~/ 4) + 1) * 4);
    final answer = (base * pct / 100).round();
    return MathProblem(
      a: pct,
      b: base,
      operation: Operation.percentOf,
      correctAnswer: answer,
      difficultyLevel: d,
      hint: pct == 10
          ? 'Divide by 10: ${base} ÷ 10.'
          : pct == 25
              ? 'Divide by 4: ${base} ÷ 4.'
              : pct == 50
                  ? 'Divide by 2: ${base} ÷ 2.'
                  : '$pct% = $pct ÷ 100 × $base.',
      typeKey: Operation.percentOf.name,
    );
  }

  static MathProblem _square(int d) {
    final maxBase = _scale(d, lo: 2, hi: 20);
    final a = _rng.nextInt(maxBase) + 2;
    return MathProblem(
      a: a,
      b: a,
      operation: Operation.squareOf,
      correctAnswer: a * a,
      difficultyLevel: d,
      hint: '$a² = $a × $a = ${a * a}.',
      typeKey: Operation.squareOf.name,
    );
  }

  static MathProblem _sqrt(int d) {
    final maxRoot = _scale(d, lo: 2, hi: 15);
    final root = _rng.nextInt(maxRoot) + 2;
    return MathProblem(
      a: root * root,
      b: root,
      operation: Operation.sqrtOf,
      correctAnswer: root,
      difficultyLevel: d,
      hint: 'What number × itself = ${root * root}?',
      typeKey: Operation.sqrtOf.name,
    );
  }

  // ── Scaling helper ────────────────────────────────────────────────────────
  /// Linearly interpolate between [lo] and [hi] across difficulty 1–10.
  static int _scale(int d, {required int lo, required int hi}) {
    return (lo + (hi - lo) * (d - 1) / 9).round().clamp(lo, hi);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ExplanationEngine — rich, specific, educational
// ─────────────────────────────────────────────────────────────────────────────
class ExplanationEngine {
  static String explain(MathProblem p, int wrong) {
    final right = p.correctAnswer;
    final off = (wrong - right).abs();

    switch (p.operation) {
      case Operation.add:
        if (off == 1) return 'Almost! Off by 1. Check the units column.';
        if (wrong == p.a - p.b)
          return 'You subtracted — this is addition. ${p.a} + ${p.b} = $right';
        if (wrong == right - 10 || wrong == right + 10)
          return 'Carry/borrow error. ${p.a} + ${p.b} = $right';
        return '${p.a} + ${p.b} = $right';

      case Operation.subtract:
        if (wrong == p.b - p.a)
          return 'You reversed the order. ${p.a} − ${p.b} = $right';
        if (off == 1) return 'Almost! Off by 1 — check the borrowing.';
        return '${p.a} − ${p.b} = $right';

      case Operation.multiply:
        if (wrong == p.a + p.b)
          return 'You added instead of multiplying. ${p.a} × ${p.b} = $right';
        if (wrong == p.a * (p.b - 1))
          return 'Off by one group — forgot to add the last ${p.a}.';
        return '${p.a} × ${p.b} = $right  (${p.a} groups of ${p.b})';

      case Operation.divide:
        if (wrong == p.a * p.b)
          return 'You multiplied instead of dividing. ${p.a} ÷ ${p.b} = $right';
        return 'Ask: ${p.b} × ? = ${p.a}.  Answer: $right';

      case Operation.missingAdd:
        return 'Subtract ${p.b} from ${p.a + p.b}: ${p.a + p.b} − ${p.b} = $right';

      case Operation.missingMul:
        return 'Divide ${p.a * p.b} by ${p.a}: ${p.a * p.b} ÷ ${p.a} = $right';

      case Operation.doubleStep:
        final step1 = p.a + p.b;
        final c = p.c ?? 1;
        return 'First: ${p.a} + ${p.b} = $step1.  Then: $step1 × $c = $right';

      case Operation.percentOf:
        return '${p.a}% of ${p.b} = ${p.b} × ${p.a}/100 = $right';

      case Operation.squareOf:
        return '${p.a}² = ${p.a} × ${p.a} = $right';

      case Operation.sqrtOf:
        return '${p.correctAnswer} × ${p.correctAnswer} = ${p.a}, so √${p.a} = $right';
    }
  }
}
