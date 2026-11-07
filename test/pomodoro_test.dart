import 'package:flow_math/models/pomodoro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  PomodoroEngine engine() => PomodoroEngine(clock: () => now);
  void wait(int minutes) => now = now.add(Duration(minutes: minutes));

  setUp(() => now = DateTime(2026, 11, 7, 9));

  test('classic: focus and short breaks, finishing after the last round', () {
    final e = engine()..start(presetById('classic').plan(4));
    final seen = <String>[];
    e.onPhaseComplete = (p, r, _) => seen.add('${p.name}$r');

    for (var i = 0; i < 7; i++) {
      wait(i.isEven ? 25 : 5);
      e.tick();
      if (e.stage == PomoStage.between) e.startNext();
    }
    expect(seen, [
      'focus1', 'shortBreak1', 'focus2', 'shortBreak2', //
      'focus3', 'shortBreak3', 'focus4',
    ]);
    expect(e.stage, PomoStage.finished);
    expect(e.completedRounds, 4);
    expect(e.focusedMs, 4 * 25 * 60000);
  });

  test('long break comes after every Nth round', () {
    final plan = presetById('classic').plan(6);
    expect(plan.breakAfter(3), PomoPhase.shortBreak);
    expect(plan.breakAfter(4), PomoPhase.longBreak);
    expect(plan.breakAfter(6), isNull); // nothing after the last round
    expect(plan.totalMs, (6 * 25 + 4 * 5 + 15) * 60000);
  });

  test('auto-continue catches up after the phone slept', () {
    final e = engine()
      ..start(presetById('classic').plan(4), autoContinue: true);
    wait(25 + 5 + 10); // round 1, a break, and 10 min into round 2
    e.tick();
    expect(e.stage, PomoStage.running);
    expect(e.phase, PomoPhase.focus);
    expect(e.round, 2);
    expect(e.remainingMs, 15 * 60000);
  });

  test('without auto-continue the next phase waits for the user', () {
    final e = engine()..start(presetById('classic').plan(4));
    wait(40);
    e.tick();
    expect(e.stage, PomoStage.between);
    expect(e.phase, PomoPhase.shortBreak);
    expect(e.round, 1);
    e.startNext();
    wait(2);
    expect(e.remainingMs, 3 * 60000);
  });

  test('pause stops the clock', () {
    final e = engine()..start(presetById('classic').plan(2));
    wait(10);
    e.pause();
    wait(60);
    e.tick();
    expect(e.elapsedMs, 10 * 60000);
    e.resume();
    wait(5);
    expect(e.elapsedMs, 15 * 60000);
  });

  test('skip break and end a round early', () {
    final e = engine()..start(presetById('classic').plan(3));
    wait(10);
    e.endRoundEarly();
    expect(e.phase, PomoPhase.shortBreak);
    expect(e.stage, PomoStage.running);
    expect(e.focusedMs, 10 * 60000);
    e.skipBreak();
    expect(e.phase, PomoPhase.focus);
    expect(e.round, 2);
  });

  test('skipping a break that is waiting moves on to the next round', () {
    final e = engine()..start(presetById('classic').plan(4));
    wait(25);
    e.tick();
    expect(e.stage, PomoStage.between);
    expect(e.phase, PomoPhase.shortBreak);
    e.skipBreak();
    expect(e.stage, PomoStage.running);
    expect(e.phase, PomoPhase.focus);
    expect(e.round, 2);
  });

  test('"just start" is a single 5-minute round', () {
    final e = engine()..start(presetById('tiny').plan(4));
    expect(e.plan.rounds, 1);
    wait(5);
    e.tick();
    expect(e.stage, PomoStage.finished);
  });

  test('finishing early keeps the partial focus time', () {
    final e = engine()..start(presetById('deep').plan(3));
    wait(12);
    expect(e.finish(), 12 * 60000);
    expect(e.focusedMs, 12 * 60000);
    expect(e.stage, PomoStage.finished);
  });
}
