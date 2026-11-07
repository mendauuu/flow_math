import 'dart:io';

import 'package:flow_math/models/practice.dart';
import 'package:flow_math/services/math_progress.dart';
import 'package:flow_math/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('Mind levels', () {
    test('XP curve and level boundaries', () {
      expect(MindLevels.xpToReach(1), 0);
      expect(MindLevels.xpToReach(2), 150);
      expect(MindLevels.of(0).level, 1);
      expect(MindLevels.of(149).level, 1);
      expect(MindLevels.of(150).level, 2);
      final l = MindLevels.of(200);
      expect(l.xpIntoLevel, 50);
      expect(l.xpForNext, 300); // 450 - 150
      expect(l.progress, closeTo(50 / 300, 1e-9));
    });

    test('titles grow from seedling to galaxy', () {
      expect(MindLevels.titleFor(1).$1, 'Seedling');
      expect(MindLevels.titleFor(4).$1, 'Sprout');
      expect(MindLevels.titleFor(30).$1, 'Galaxy');
      expect(MindLevels.titleFor(99).$1, 'Galaxy');
      expect(MindLevels.nextTitle(4), (5, 'Sapling'));
      expect(MindLevels.nextTitle(30), isNull);
    });
  });

  test('mastery rewards accuracy, speed and practice', () {
    final t = kMathTopics.first;
    final few = TopicSkill(t, 3, 3, 3 * 2000);
    final many = TopicSkill(t, 40, 40, 40 * 2000);
    final sloppy = TopicSkill(t, 40, 20, 40 * 2000);
    final slow = TopicSkill(t, 40, 40, 40 * 9000);
    expect(many.mastery, closeTo(1, 1e-9));
    expect(few.mastery, lessThan(many.mastery));
    expect(sloppy.mastery, lessThan(many.mastery));
    expect(slow.mastery, lessThan(many.mastery));
    expect(TopicSkill(t, 0, 0, 0).mastery, 0);
  });

  test('sessions add up into XP, today and the skill map', () async {
    final dir = await Directory.systemTemp.createTemp('flow_math_progress');
    Hive.init(dir.path);
    await Hive.openBox('prefs');

    final add = OpTally()
      ..add(right: true, ms: 2000)
      ..add(right: false, ms: 4000);
    await MathProgress.addSession(xp: 120, ops: {'add': add});
    await MathProgress.addSession(
        xp: 80, ops: {'percentOf': OpTally()..add(right: true, ms: 3000)});

    expect(MathProgress.totalXp, 200);
    expect(MathProgress.todayXp, 200);
    final skills = MathProgress.skills;
    expect(skills.first.topic.id, 'addsub');
    expect(skills.first.attempts, 2);
    expect(skills.first.correct, 1);
    expect(skills.firstWhere((s) => s.topic.id == 'percent').attempts, 1);
    expect(MathProgress.weakest, isNull); // not enough answers yet

    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('Flow meter', () {
    testWidgets('fast correct answers fill the meter and enter flow',
        (tester) async {
      final svc = SessionService()..startSession(SessionMode.focus);
      var guard = 0;
      while (!svc.inFlow && guard++ < 20) {
        svc.submitAnswer(svc.currentProblem!.correctAnswer);
        await tester.pump(const Duration(milliseconds: 950));
      }
      expect(svc.inFlow, isTrue);
      expect(svc.flowEntries, 1);
      expect(svc.xp, greaterThan(0));

      // XP counts double while in flow.
      final before = svc.xp;
      svc.submitAnswer(svc.currentProblem!.correctAnswer);
      expect(svc.lastXpGain, greaterThanOrEqualTo(2 * 8));
      expect(svc.xp, before + svc.lastXpGain);
      await tester.pump(const Duration(seconds: 1));

      // Flow lasts 20 seconds, then cools down.
      await tester.pump(const Duration(seconds: 21));
      expect(svc.inFlow, isFalse);
      expect(svc.flowSeconds, greaterThanOrEqualTo(19));
      svc.dispose();
    });

    testWidgets('wrong answers earn nothing and cool the meter',
        (tester) async {
      final svc = SessionService()..startSession(SessionMode.focus);
      svc.submitAnswer(svc.currentProblem!.correctAnswer);
      await tester.pump(const Duration(seconds: 1));
      final meter = svc.flowMeter;
      final xp = svc.xp;
      svc.submitAnswer(svc.currentProblem!.correctAnswer + 1);
      expect(svc.lastXpGain, 0);
      expect(svc.xp, xp);
      expect(svc.flowMeter, lessThan(meter));
      expect(svc.opTally.values.fold<int>(0, (s, t) => s + t.attempts), 2);
      await tester.pump(const Duration(seconds: 3));
      svc.dispose();
    });
  });
}
