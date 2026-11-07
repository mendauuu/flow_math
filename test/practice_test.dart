import 'package:flow_math/models/math_problem.dart';
import 'package:flow_math/models/practice.dart';
import 'package:flow_math/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProblemGenerator', () {
    test('topic filter only produces chosen operations at every level', () {
      final allowed = opsForTopics(['muldiv'])!;
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 200; i++) {
          final p = ProblemGenerator.generate(level, allowed: allowed);
          expect(allowed, contains(p.operation));
        }
      }
    });

    test('topics not yet unlocked at a low level are still used', () {
      final allowed = opsForTopics(['powers'])!;
      final p = ProblemGenerator.generate(1, allowed: allowed);
      expect(allowed, contains(p.operation));
    });

    test('no topics means everything', () {
      expect(opsForTopics(const []), isNull);
    });

    test('daily set is identical all day and differs between days', () {
      final day = DateTime(2026, 11, 7);
      final a = ProblemGenerator.dailySet(day, count: 15);
      final b = ProblemGenerator.dailySet(DateTime(2026, 11, 7, 18, 30), count: 15);
      final other = ProblemGenerator.dailySet(DateTime(2026, 11, 8), count: 15);
      String sig(List<MathProblem> l) =>
          l.map((p) => '${p.questionText}=${p.correctAnswer}').join('|');
      expect(a.length, 15);
      expect(sig(a), sig(b));
      expect(sig(a), isNot(sig(other)));
    });

    test('every generated answer is a non-negative whole number', () {
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 300; i++) {
          expect(ProblemGenerator.generate(level).correctAnswer,
              greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('SessionService', () {
    testWidgets('daily challenge ends after exactly 15 problems', (tester) async {
      final svc = SessionService()
        ..startSession(SessionMode.focus, practice: PracticeMode.daily);
      expect(svc.queueLength, PracticeRules.dailyCount);
      for (var i = 0; i < PracticeRules.dailyCount; i++) {
        expect(svc.isOver, isFalse);
        svc.submitAnswer(svc.currentProblem!.correctAnswer);
        await tester.pump(const Duration(seconds: 3));
      }
      expect(svc.isOver, isTrue);
      expect(svc.correctAnswers, PracticeRules.dailyCount);
      expect(svc.mistakes, isEmpty);
      svc.dispose();
    });

    testWidgets('sprint is over after 60 seconds', (tester) async {
      final svc = SessionService()
        ..startSession(SessionMode.focus, practice: PracticeMode.sprint);
      await tester.pump(const Duration(seconds: 59));
      expect(svc.isOver, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(svc.isOver, isTrue);
      svc.dispose();
    });

    testWidgets('skip and wrong answers are kept for review', (tester) async {
      final svc = SessionService()
        ..startSession(SessionMode.focus, allowed: opsForTopics(['addsub']));
      final skipped = svc.currentProblem!;
      svc.skip();
      expect(svc.showFeedback, isTrue);
      expect(svc.feedbackMessage, contains('${skipped.correctAnswer}'));
      await tester.pump(const Duration(seconds: 2));

      final p = svc.currentProblem!;
      svc.submitAnswer(p.correctAnswer + 1);
      await tester.pump(const Duration(seconds: 3));

      expect(svc.mistakes.length, 2);
      expect(svc.mistakes.first.given, isNull);
      expect(svc.mistakes.last.given, p.correctAnswer + 1);
      expect(svc.streak, 0);
      svc.dispose();
    });

    testWidgets('restarted keeps the same mode', (tester) async {
      final svc = SessionService()
        ..startSession(SessionMode.focus, practice: PracticeMode.sprint);
      final again = svc.restarted();
      expect(again.practiceMode, PracticeMode.sprint);
      expect(again.targetSeconds, PracticeRules.sprintSeconds);
      svc.dispose();
      again.dispose();
    });
  });
}
