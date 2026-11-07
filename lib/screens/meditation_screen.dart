import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../widgets/themed.dart';
import 'package:flutter/services.dart';
import '../models/breath_pattern.dart';
import '../services/audio_service.dart';
import '../services/meditation_log.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/breath_orb.dart';
import '../widgets/sound_picker_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MeditationScreen
//  setup → settling (3 s "settle in") → running (guided breathing, pausable)
//  → done. One big breathing orb carries the whole session; everything else
//  stays quiet. Time comes from the wall clock, so locking the phone is fine
//  and a notification announces the end if the app isn't visible.
// ─────────────────────────────────────────────────────────────────────────────

enum _Stage { setup, settling, running, done }

class MeditationScreen extends StatefulWidget {
  final SettingsService settings;

  /// The ambient player from Home — keeps playing through the session.
  final AudioService audio;

  const MeditationScreen({
    super.key,
    required this.settings,
    required this.audio,
  });

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen>
    with SingleTickerProviderStateMixin {
  Palette get pal => context.palette;

  static const _settleMs = 3000;
  static const _prompts = [
    'Notice your breath',
    'Let your shoulders soften',
    'Thoughts can drift by',
    'Feel the ground beneath you',
    'Come back to the breath',
    'Nothing to do, nowhere to be',
  ];

  late final AnimationController _frame = AnimationController(
    vsync: this,
    duration: Duration(seconds: 1),
  )..repeat();
  final Stopwatch _clock = Stopwatch()..start();
  late final AppLifecycleListener _lifecycle;
  Timer? _ticker;

  _Stage _stage = _Stage.setup;
  bool _paused = false;
  bool _hidden = false;
  int _accumulatedMs = 0;
  DateTime? _segmentStart;
  DateTime? _settleStart;
  int _lastPhase = -1;
  BreathPattern _pattern = kBreathPatterns.first;
  int _totalMs = 10 * 60000;

  int _resultSeconds = 0;
  double _resultProgress = 0;
  bool _completed = false;

  SettingsService get s => widget.settings;
  double get _time => _clock.elapsedMilliseconds / 1000;
  bool get _inSession => _stage == _Stage.settling || _stage == _Stage.running;

  @override
  void initState() {
    super.initState();
    s.addListener(_onSettings);
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    _frame.dispose();
    s.removeListener(_onSettings);
    if (_inSession) NotificationService.cancelAlert(TimerAlert.meditation);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _haptic(Future<void> Function() feedback) {
    if (s.haptics) feedback();
  }

  // ── Timing ────────────────────────────────────────────────────────────────
  int get _elapsedMs {
    var ms = _accumulatedMs;
    if (_stage == _Stage.running && !_paused && _segmentStart != null) {
      ms += DateTime.now().difference(_segmentStart!).inMilliseconds;
    }
    return ms.clamp(0, _totalMs);
  }

  int get _settleElapsedMs => _settleStart == null
      ? 0
      : DateTime.now()
          .difference(_settleStart!)
          .inMilliseconds
          .clamp(0, _settleMs);

  /// Where we are in the breathing cycle (guided patterns only).
  ({BreathPhase phase, int number, double progress, int secondsLeft}) _phaseAt(
      int ms) {
    final phases = _pattern.phases;
    final cycles = ms ~/ _pattern.cycleMs;
    var t = ms % _pattern.cycleMs;
    for (var i = 0; i < phases.length; i++) {
      final d = phases[i].seconds * 1000;
      if (t < d || i == phases.length - 1) {
        return (
          phase: phases[i],
          number: cycles * phases.length + i,
          progress: (t / d).clamp(0.0, 1.0),
          secondsLeft: ((d - t) / 1000).ceil().clamp(1, 99),
        );
      }
      t -= d;
    }
    return (
      phase: phases.first,
      number: 0,
      progress: 0.0,
      secondsLeft: phases.first.seconds,
    );
  }

  /// 0 (empty) … 1 (full) — how big the orb is right now.
  double _breath() => switch (_stage) {
        _Stage.setup || _Stage.done => 0.45 + 0.25 * sin(_time * 2 * pi / 8),
        _Stage.settling => 0.4 * (1 - _settleElapsedMs / _settleMs),
        _Stage.running => _runningBreath(),
      };

  double _runningBreath() {
    final ms = _elapsedMs;
    if (!_pattern.guided) return 0.5 - 0.5 * cos(2 * pi * ms / 10000);
    final ph = _phaseAt(ms);
    final eased = 0.5 - 0.5 * cos(pi * ph.progress);
    return switch (ph.phase.kind) {
      BreathKind.inhale => eased,
      BreathKind.holdFull => 1.0,
      BreathKind.exhale => 1.0 - eased,
      BreathKind.holdEmpty => 0.0,
    };
  }

  /// Big guidance word(s) + a small line underneath, shown inside the orb.
  (String, String) _cue(int ms) {
    if (_stage == _Stage.settling) {
      final left = ((_settleMs - _settleElapsedMs) / 1000).ceil().clamp(1, 3);
      return ('Settle in', '$left');
    }
    if (_paused) return ('Paused', '');
    if (!_pattern.guided) {
      return (_prompts[(ms ~/ 20000) % _prompts.length], '');
    }
    final ph = _phaseAt(ms);
    return (ph.phase.label, '${ph.secondsLeft}');
  }

  // ── Session flow ──────────────────────────────────────────────────────────
  void _begin() {
    _haptic(HapticFeedback.mediumImpact);
    setState(() {
      _pattern = breathPatternById(s.medPattern);
      _totalMs = s.medMinutes * 60000;
      _accumulatedMs = 0;
      _segmentStart = null;
      _paused = false;
      _lastPhase = -1;
      _settleStart = DateTime.now();
      _stage = _Stage.settling;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(Duration(milliseconds: 200), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted) return;
    if (_stage == _Stage.settling) {
      if (_settleElapsedMs >= _settleMs) {
        setState(() {
          _stage = _Stage.running;
          _segmentStart = DateTime.now();
        });
        _haptic(HapticFeedback.lightImpact);
      }
      return;
    }
    if (_stage != _Stage.running || _paused) return;

    final ms = _elapsedMs;
    if (ms >= _totalMs) {
      _finish(completed: true);
      return;
    }
    // A soft tap at each change of breath, for eyes-closed practice.
    if (_pattern.guided && s.medCues) {
      final n = _phaseAt(ms).number;
      if (n != _lastPhase) {
        if (_lastPhase >= 0) _haptic(HapticFeedback.lightImpact);
        _lastPhase = n;
      }
    }
  }

  void _togglePause() {
    if (_stage != _Stage.running) return;
    _haptic(HapticFeedback.selectionClick);
    setState(() {
      if (_paused) {
        _segmentStart = DateTime.now();
        _paused = false;
      } else {
        _accumulatedMs = _elapsedMs; // read before flipping _paused
        _segmentStart = null;
        _paused = true;
      }
    });
  }

  Future<void> _finish({required bool completed}) async {
    if (!_inSession) return;
    final ms = _stage == _Stage.running ? _elapsedMs : 0;
    _ticker?.cancel();
    final seconds = completed ? _totalMs ~/ 1000 : ms ~/ 1000;
    setState(() {
      _stage = _Stage.done;
      _paused = false;
      _completed = completed;
      _resultSeconds = seconds;
      _resultProgress = completed ? 1.0 : ms / _totalMs;
    });

    if (completed && _hidden) {
      NotificationService.showAlert(TimerAlert.meditation,
          'Meditation complete 🍃', _doneBody((seconds / 60).round()));
    } else {
      NotificationService.cancelAlert(TimerAlert.meditation);
    }
    if (completed) {
      _haptic(HapticFeedback.heavyImpact);
      Future.delayed(Duration(milliseconds: 350), () {
        if (mounted) _haptic(HapticFeedback.heavyImpact);
      });
    }
    if (seconds >= 60) {
      await MeditationLog.add(
          seconds: seconds, pattern: _pattern.id, completed: completed);
      await NotificationService.sync(); // meditation keeps the streak alive
      if (mounted) setState(() {});
    }
  }

  static String _doneBody(int minutes) => minutes <= 1
      ? 'A quiet minute, just for you. Well done.'
      : 'You gave yourself $minutes calm minutes. Well done.';

  Future<void> _requestExit() async {
    if (_stage == _Stage.setup || _stage == _Stage.done) {
      Navigator.pop(context);
      return;
    }
    if (_stage == _Stage.settling) {
      _ticker?.cancel();
      setState(() => _stage = _Stage.setup);
      return;
    }

    final wasPaused = _paused;
    if (!wasPaused) _togglePause();
    final short = _elapsedMs < 60000;
    final end = await showThemedConfirm(
      context,
      title: 'End this session?',
      body: short
          ? 'Sessions under a minute aren\'t saved.'
          : 'Your calm minutes so far will be saved.',
      cancel: 'Keep going',
      action: 'End',
      tint: pal.calm,
    );
    if (!mounted) return;
    if (end) {
      _finish(completed: false);
    } else if (!wasPaused) {
      _togglePause();
    }
  }

  // ── App goes to background / comes back ───────────────────────────────────
  void _onHide() {
    _hidden = true;
    if (_paused) return;
    int? remaining;
    if (_stage == _Stage.running) {
      remaining = _totalMs - _elapsedMs;
    } else if (_stage == _Stage.settling) {
      remaining = _totalMs + (_settleMs - _settleElapsedMs);
    }
    if (remaining != null && remaining > 0) {
      NotificationService.scheduleAlert(
          TimerAlert.meditation,
          Duration(milliseconds: remaining),
          'Meditation complete 🍃',
          _doneBody(_totalMs ~/ 60000));
    }
  }

  void _onShow() {
    _hidden = false;
    NotificationService.cancelAlert(TimerAlert.meditation);
    _onTick();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = pal.calm;
    return PopScope(
      canPop: !_inSession,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        body: Stack(
          children: [
            AnimatedBackground(theme: s.bgTheme),
            // Dim a little more while meditating — quieter for the eyes.
            ThemedScrim(_inSession ? 0.6 : 0.45),
            SafeArea(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 500),
                      child: KeyedSubtree(
                        key: ValueKey(_inSession ? 'session' : _stage.name),
                        child: switch (_stage) {
                          _Stage.setup => _setupView(accent),
                          _Stage.done => _doneView(accent),
                          _ => _sessionView(accent),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return ThemedTopBar(
      title: 'MEDITATION',
      onBack: _requestExit,
      icon: _inSession ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
      trailing: SoundPickerWidget(
        audio: widget.audio,
        haptics: s.haptics,
        onChanged: s.setSoundMode,
      ),
    );
  }

  /// The orb with optional text in its centre, sized to [size].
  Widget _orb(
    Color accent, {
    required double size,
    required double progress,
    String label = '',
    String sub = '',
    bool bloom = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: BreathOrbPainter(
              breath: _breath(),
              progress: progress,
              time: _time,
              accent: accent,
              bloom: bloom,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 450),
                  child: Text(label,
                      key: ValueKey(label),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: pal.textBright,
                        letterSpacing: 1,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                      )),
                ),
                if (sub.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Text(sub,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        color: pal.textBright.withValues(alpha: 0.75),
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 10)
                        ],
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Setup ─────────────────────────────────────────────────────────────────
  Widget _setupView(Color accent) {
    final pattern = breathPatternById(s.medPattern);
    return Column(
      children: [
        SizedBox(height: 10),
        Text('Breathe.',
            style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w200,
                color: pal.textBright)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = min(box.maxWidth * 0.8, box.maxHeight - 16)
                  .clamp(120.0, 340.0);
              return Center(
                child: AnimatedBuilder(
                  animation: _frame,
                  builder: (_, __) => _orb(accent,
                      size: size,
                      progress: 0,
                      label: pattern.name,
                      sub: pattern.rhythm),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            children: [
              _durationRow(accent),
              SizedBox(height: 10),
              _patternRow(accent),
              SizedBox(height: 18),
              _primaryButton('BEGIN', accent, _begin),
            ],
          ),
        ),
      ],
    );
  }

  Widget _durationRow(Color accent) {
    const options = SettingsService.meditationLengths;
    return Row(
      children: [
        for (final m in options)
          Expanded(
            child: GestureDetector(
              onTap: () {
                _haptic(HapticFeedback.selectionClick);
                s.setMedMinutes(m);
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: m == options.last ? 0 : 8),
                padding: EdgeInsets.symmetric(vertical: 11),
                decoration: _chip(accent, s.medMinutes == m),
                child: Center(
                  child: Text('${m}m',
                      style: TextStyle(
                        fontSize: 13,
                        color: s.medMinutes == m ? accent : pal.textDim,
                        fontWeight: s.medMinutes == m
                            ? FontWeight.w600
                            : FontWeight.w400,
                      )),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _patternRow(Color accent) {
    return Row(
      children: [
        for (final p in kBreathPatterns)
          Expanded(
            child: GestureDetector(
              onTap: () {
                _haptic(HapticFeedback.selectionClick);
                s.setMedPattern(p.id);
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 180),
                margin: EdgeInsets.only(
                    right: p == kBreathPatterns.last ? 0 : 8),
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: _chip(accent, s.medPattern == p.id),
                child: Column(
                  children: [
                    Text(p.name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: s.medPattern == p.id
                                ? accent
                                : pal.textMid)),
                    SizedBox(height: 2),
                    Text(p.guided ? p.rhythm.replaceAll(' ', '') : 'free',
                        style: TextStyle(
                            fontSize: 10, color: pal.textDim)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Session ───────────────────────────────────────────────────────────────
  Widget _sessionView(Color accent) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = min(box.maxWidth * 0.94, box.maxHeight - 40)
                  .clamp(160.0, 420.0);
              return AnimatedBuilder(
                animation: _frame,
                builder: (context, _) {
                  final settling = _stage == _Stage.settling;
                  final ms = _elapsedMs;
                  final (label, sub) = _cue(ms);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_fmt(settling ? _totalMs : _totalMs - ms),
                          style: TextStyle(
                            fontSize: 15,
                            color: pal.textDim,
                            letterSpacing: 3,
                            fontFeatures: [FontFeature.tabularFigures()],
                          )),
                      SizedBox(height: 8),
                      _orb(accent,
                          size: size,
                          progress: settling ? 0 : ms / _totalMs,
                          label: label,
                          sub: sub),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              _pauseButton(accent),
              SizedBox(height: 2),
              TextButton(
                onPressed: _requestExit,
                child: Text('End',
                    style: TextStyle(
                        fontSize: 12,
                        color: pal.textDim,
                        letterSpacing: 2)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pauseButton(Color accent) {
    final enabled = _stage == _Stage.running;
    return Pressable(
      onTap: enabled ? _togglePause : null,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 300),
        opacity: enabled ? 1 : 0.4,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(min(pal.radius * 1.4, 30)),
            color: Color.alphaBlend(
                accent.withValues(alpha: _paused ? 0.30 : 0.18),
                pal.surface.withValues(alpha: 0.85)),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Icon(
            _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: accent,
            size: 28,
          ),
        ),
      ),
    );
  }

  // ── Done ──────────────────────────────────────────────────────────────────
  Widget _doneView(Color accent) {
    final minutes = (_resultSeconds / 60).round();
    final plural = minutes == 1 ? '' : 's';
    final saved = _resultSeconds >= 60;
    final body = _completed
        ? 'You gave yourself $minutes calm minute$plural.'
        : saved
            ? '$minutes mindful minute$plural — every one counts.'
            : 'Even a short pause helps.\nSessions under a minute aren\'t saved.';
    final streak = MeditationLog.dayStreak;
    final stats = '${MeditationLog.totalMinutes} mindful min  ·  '
        '${MeditationLog.sessions} session${MeditationLog.sessions == 1 ? '' : 's'}'
        '${streak >= 2 ? '  ·  🔥 $streak days' : ''}';

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = min(box.maxWidth * 0.7, box.maxHeight - 170)
                  .clamp(120.0, 280.0);
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _frame,
                        builder: (_, __) => _orb(accent,
                            size: size,
                            progress: _resultProgress,
                            label: _completed ? '✓' : '',
                            bloom: _completed),
                      ),
                      SizedBox(height: 20),
                      Text(_completed ? 'Well done.' : 'Nicely paused.',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w200,
                              color: pal.textBright)),
                      SizedBox(height: 8),
                      Text(body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              color: pal.textMid,
                              height: 1.5)),
                      SizedBox(height: 14),
                      if (MeditationLog.sessions > 0)
                        Text(stats,
                            style: TextStyle(
                                fontSize: 12, color: pal.textDim)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Row(
            children: [
              Expanded(
                child: _secondaryButton('AGAIN', () {
                  _haptic(HapticFeedback.selectionClick);
                  setState(() => _stage = _Stage.setup);
                }),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _primaryButton(
                    'DONE', accent, () => Navigator.pop(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────────────
  BoxDecoration _chip(Color accent, bool active) =>
      pal.chip(active, tint: accent);

  Widget _primaryButton(String text, Color accent, VoidCallback onTap) =>
      ThemedButton(label: text, tint: accent, onTap: onTap);

  Widget _secondaryButton(String text, VoidCallback onTap) =>
      ThemedButton(label: text, primary: false, onTap: onTap);

  static String _fmt(int ms) {
    final secs = (ms / 1000).ceil();
    return '${(secs ~/ 60).toString().padLeft(2, '0')}:'
        '${(secs % 60).toString().padLeft(2, '0')}';
  }
}
