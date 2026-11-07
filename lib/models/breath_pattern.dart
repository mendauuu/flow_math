/// Guided breathing rhythms for the meditation screen.
enum BreathKind { inhale, holdFull, exhale, holdEmpty }

class BreathPhase {
  final BreathKind kind;
  final int seconds;
  const BreathPhase(this.kind, this.seconds);

  String get label => switch (kind) {
        BreathKind.inhale => 'Breathe in',
        BreathKind.holdFull => 'Hold',
        BreathKind.exhale => 'Breathe out',
        BreathKind.holdEmpty => 'Hold',
      };
}

class BreathPattern {
  final String id;
  final String name;
  final String emoji;
  final String rhythm;
  final String tagline;

  /// Empty = unguided (timer and gentle prompts only).
  final List<BreathPhase> phases;

  const BreathPattern({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rhythm,
    required this.tagline,
    required this.phases,
  });

  bool get guided => phases.isNotEmpty;
  int get cycleMs => phases.fold(0, (sum, p) => sum + p.seconds * 1000);
}

const List<BreathPattern> kBreathPatterns = [
  BreathPattern(
    id: 'calm',
    name: 'Calm',
    emoji: '🌿',
    rhythm: '4 · 4 · 4 · 4',
    tagline: 'Box breathing to steady a busy mind',
    phases: [
      BreathPhase(BreathKind.inhale, 4),
      BreathPhase(BreathKind.holdFull, 4),
      BreathPhase(BreathKind.exhale, 4),
      BreathPhase(BreathKind.holdEmpty, 4),
    ],
  ),
  BreathPattern(
    id: 'relax',
    name: 'Relax',
    emoji: '🌙',
    rhythm: '4 · 7 · 8',
    tagline: 'A long, slow exhale to unwind',
    phases: [
      BreathPhase(BreathKind.inhale, 4),
      BreathPhase(BreathKind.holdFull, 7),
      BreathPhase(BreathKind.exhale, 8),
    ],
  ),
  BreathPattern(
    id: 'balance',
    name: 'Balance',
    emoji: '🌊',
    rhythm: '5 · 5',
    tagline: 'Even breaths in and out, like waves',
    phases: [
      BreathPhase(BreathKind.inhale, 5),
      BreathPhase(BreathKind.exhale, 5),
    ],
  ),
  BreathPattern(
    id: 'free',
    name: 'Free',
    emoji: '🕯️',
    rhythm: 'Unguided',
    tagline: 'Just sit, breathe naturally, let thoughts pass',
    phases: [],
  ),
];

bool isKnownBreathPattern(String id) => kBreathPatterns.any((p) => p.id == id);

BreathPattern breathPatternById(String id) => kBreathPatterns.firstWhere(
      (p) => p.id == id,
      orElse: () => kBreathPatterns.first,
    );
