// ─────────────────────────────────────────────────────────────────────────────
//  Pomodoro — focus rounds and breaks
//
//  The engine is pure Dart with an injectable clock, so it can be tested and
//  it catches up correctly after the phone has been locked for a while.
// ─────────────────────────────────────────────────────────────────────────────

class PomodoroPreset {
  final String id;
  final String name;
  final int focusMin;
  final int breakMin;
  final int longBreakMin;

  /// A long break after every this many rounds (0 = never).
  final int longEvery;
  final int defaultRounds;
  final String hint;

  const PomodoroPreset({
    required this.id,
    required this.name,
    required this.focusMin,
    required this.breakMin,
    required this.longBreakMin,
    required this.longEvery,
    required this.defaultRounds,
    required this.hint,
  });

  /// Single round, no breaks — for when starting is the hard part.
  bool get isTiny => breakMin == 0;

  String get rhythm => isTiny ? '$focusMin min' : '$focusMin · $breakMin';

  PomodoroPlan plan(int rounds) => PomodoroPlan(
        focusMs: focusMin * 60000,
        breakMs: breakMin * 60000,
        longBreakMs: longBreakMin * 60000,
        longEvery: longEvery,
        rounds: isTiny ? 1 : rounds.clamp(1, 12),
      );
}

const List<PomodoroPreset> kPomodoroPresets = [
  PomodoroPreset(
    id: 'tiny',
    name: 'Just start',
    focusMin: 5,
    breakMin: 0,
    longBreakMin: 0,
    longEvery: 0,
    defaultRounds: 1,
    hint: 'Only 5 minutes. You can stop after — most people keep going.',
  ),
  PomodoroPreset(
    id: 'quick',
    name: 'Quick',
    focusMin: 15,
    breakMin: 3,
    longBreakMin: 10,
    longEvery: 4,
    defaultRounds: 4,
    hint: 'Short rounds to build momentum.',
  ),
  PomodoroPreset(
    id: 'classic',
    name: 'Classic',
    focusMin: 25,
    breakMin: 5,
    longBreakMin: 15,
    longEvery: 4,
    defaultRounds: 4,
    hint: 'The classic Pomodoro rhythm.',
  ),
  PomodoroPreset(
    id: 'deep',
    name: 'Deep',
    focusMin: 50,
    breakMin: 10,
    longBreakMin: 20,
    longEvery: 3,
    defaultRounds: 3,
    hint: 'Long rounds for homework and coding — time to go deep.',
  ),
  PomodoroPreset(
    id: 'marathon',
    name: 'Marathon',
    focusMin: 90,
    breakMin: 20,
    longBreakMin: 30,
    longEvery: 2,
    defaultRounds: 2,
    hint: 'One big block of deep work, then a real rest.',
  ),
];

PomodoroPreset presetById(String id) => kPomodoroPresets
    .firstWhere((p) => p.id == id, orElse: () => kPomodoroPresets[2]);

class PomodoroPlan {
  final int focusMs;
  final int breakMs;
  final int longBreakMs;
  final int longEvery;
  final int rounds;

  const PomodoroPlan({
    required this.focusMs,
    required this.breakMs,
    required this.longBreakMs,
    required this.longEvery,
    required this.rounds,
  });

  /// Total planned time, breaks included (no break after the last round).
  int get totalMs {
    var ms = focusMs * rounds;
    for (var r = 1; r < rounds; r++) {
      ms += _isLongAfter(r) ? longBreakMs : breakMs;
    }
    return ms;
  }

  bool _isLongAfter(int round) =>
      longEvery > 0 && round % longEvery == 0 && longBreakMs > 0;

  /// The break that follows focus round [round], or null for none.
  PomoPhase? breakAfter(int round) {
    if (round >= rounds || breakMs <= 0) return null;
    return _isLongAfter(round) ? PomoPhase.longBreak : PomoPhase.shortBreak;
  }
}

enum PomoPhase { focus, shortBreak, longBreak }

enum PomoStage {
  idle,

  /// A phase is counting down (or paused).
  running,

  /// A phase ended and the next one waits for the user to start it.
  between,
  finished,
}

class PomodoroEngine {
  PomodoroEngine({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  PomodoroPlan plan = kPomodoroPresets[2].plan(4);
  PomoStage stage = PomoStage.idle;
  PomoPhase phase = PomoPhase.focus;

  /// Current (or next) focus round, 1-based.
  int round = 1;
  int completedRounds = 0;

  /// Focus time actually done, including a partial last round.
  int focusedMs = 0;

  bool autoContinue = false;
  bool paused = false;

  int _accumulatedMs = 0;
  DateTime? _segmentStart;

  /// Called when a phase runs to its end (or a round is ended early).
  void Function(PomoPhase phase, int round, int ms)? onPhaseComplete;

  /// Called whenever a new phase starts counting.
  void Function(PomoPhase phase, int round)? onPhaseStart;

  bool get active => stage == PomoStage.running || stage == PomoStage.between;
  bool get isBreak => phase != PomoPhase.focus;

  int get phaseMs => switch (phase) {
        PomoPhase.focus => plan.focusMs,
        PomoPhase.shortBreak => plan.breakMs,
        PomoPhase.longBreak => plan.longBreakMs,
      };

  int get elapsedMs {
    if (stage != PomoStage.running) return 0;
    var ms = _accumulatedMs;
    if (!paused && _segmentStart != null) {
      ms += _now().difference(_segmentStart!).inMilliseconds;
    }
    return ms.clamp(0, phaseMs);
  }

  int get remainingMs => phaseMs - elapsedMs;
  double get progress => phaseMs <= 0 ? 1 : elapsedMs / phaseMs;

  void start(PomodoroPlan p, {bool autoContinue = false}) {
    plan = p;
    this.autoContinue = autoContinue;
    round = 1;
    completedRounds = 0;
    focusedMs = 0;
    _begin(PomoPhase.focus, _now());
  }

  void _begin(PomoPhase p, DateTime at) {
    phase = p;
    stage = PomoStage.running;
    paused = false;
    _accumulatedMs = 0;
    _segmentStart = at;
    onPhaseStart?.call(p, round);
  }

  /// Moves through every phase that has ended — also several at once, when
  /// auto-continue is on and the app was asleep.
  void tick() {
    while (stage == PomoStage.running && !paused && elapsedMs >= phaseMs) {
      final endedAt =
          _segmentStart!.add(Duration(milliseconds: phaseMs - _accumulatedMs));
      _complete(phaseMs, endedAt);
    }
  }

  void _complete(int ms, DateTime at) {
    final ended = phase;
    if (ended == PomoPhase.focus) {
      focusedMs += ms;
      completedRounds++;
    }
    onPhaseComplete?.call(ended, round, ms);

    final PomoPhase? next;
    if (ended == PomoPhase.focus) {
      if (completedRounds >= plan.rounds) {
        next = null;
      } else {
        next = plan.breakAfter(round) ?? PomoPhase.focus;
      }
    } else {
      next = PomoPhase.focus;
    }

    if (next == null) {
      stage = PomoStage.finished;
      _segmentStart = null;
      return;
    }
    if (next == PomoPhase.focus) round++;
    if (autoContinue) {
      _begin(next, at);
    } else {
      phase = next;
      stage = PomoStage.between;
      paused = false;
      _accumulatedMs = 0;
      _segmentStart = null;
    }
  }

  /// Start the phase that is waiting (stage == between).
  void startNext() {
    if (stage == PomoStage.between) _begin(phase, _now());
  }

  void pause() {
    if (stage != PomoStage.running || paused) return;
    _accumulatedMs = elapsedMs;
    _segmentStart = null;
    paused = true;
  }

  void resume() {
    if (stage != PomoStage.running || !paused) return;
    _segmentStart = _now();
    paused = false;
  }

  /// Leave a break (running or waiting) and start the next focus round.
  void skipBreak() {
    if (!active || !isBreak) return;
    // During a break (running or waiting) [round] is still the round just
    // finished, so the next focus round is one more.
    round++;
    _begin(PomoPhase.focus, _now());
  }

  /// End the current focus round now and move on (to the break).
  void endRoundEarly() {
    if (stage != PomoStage.running || phase != PomoPhase.focus) return;
    final ms = elapsedMs;
    final wasAuto = autoContinue;
    autoContinue = true; // the user asked to move on right away
    _complete(ms, _now());
    autoContinue = wasAuto;
  }

  /// Stop the whole session. Returns the unfinished focus time (ms) of the
  /// current round, which is added to [focusedMs].
  int finish() {
    var partial = 0;
    if (stage == PomoStage.running && phase == PomoPhase.focus) {
      partial = elapsedMs;
      focusedMs += partial;
    }
    stage = PomoStage.finished;
    _segmentStart = null;
    paused = false;
    return partial;
  }
}
