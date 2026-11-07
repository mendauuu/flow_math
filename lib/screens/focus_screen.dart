import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pomodoro.dart';
import '../services/audio_service.dart';
import '../services/device_service.dart';
import '../services/focus_store.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/palette.dart';
import '../widgets/animated_background.dart';
import '../widgets/cozy_painters.dart';
import '../widgets/flip_clock.dart';
import '../widgets/nature_switch.dart';
import '../widgets/sound_picker_widget.dart';
import '../widgets/themed.dart';
import 'thoughts_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FocusScreen — a cozy Pomodoro for deep work (homework, coding) and for
//  beating procrastination.
//
//  setup     what you're working on, small steps, rhythm, timer style
//  focus     the timer style burns down / fills up; deep mode fades every-
//            thing else away; "now: step" keeps you on the next small thing;
//            check-ins catch daydreaming; park a thought clears your head
//  break     tea and a gentle suggestion (eyes, body, water)
//  between   when auto-continue is off: start the break / next round
//  summary   rounds, focused minutes, steps, parked thoughts
// ─────────────────────────────────────────────────────────────────────────────

enum _CheckIn { none, asking, drifted }

class FocusScreen extends StatefulWidget {
  final SettingsService settings;
  final AudioService audio;

  const FocusScreen({super.key, required this.settings, required this.audio});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {
  Palette get pal => context.palette;

  static const _maxSteps = 5;

  /// Controls hide this long after the last touch.
  static const _deepAfter = Duration(seconds: 4);
  static const _stepIdeas = [
    'Just open it',
    'Do Q1–Q3',
    'Write one messy line',
    'Fix one bug',
    'Read one page',
  ];
  static const _breakIdeas = [
    '20-20-20: look at something far away for 20 seconds 👀',
    'Stand up and stretch 🙆',
    'Drink some water 💧',
    'Roll your shoulders, unclench your jaw',
    'Shake out your hands and wrists',
    'Take three slow breaths 🌿',
    'Walk around the room 🚶',
  ];

  late final AnimationController _frame = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  final Stopwatch _clock = Stopwatch()..start();
  final Random _rng = Random();
  final PomodoroEngine _engine = PomodoroEngine();
  late final AppLifecycleListener _lifecycle;
  late final TextEditingController _task;
  final List<TextEditingController> _stepFields = [];
  Timer? _ticker;

  bool _hidden = false;
  bool _ended = false;
  DateTime _lastTouch = DateTime.now();
  bool _deep = false;
  DateTime _deepSince = DateTime.now();
  int _deepEntries = 0;

  // This session
  List<String> _steps = [];
  final Set<int> _doneSteps = {};
  _CheckIn _checkIn = _CheckIn.none;
  int _nextCheckInMs = 0;
  int _roundCheckIns = 0;
  int _roundDrifts = 0;
  int _checkIns = 0;
  int _drifts = 0;
  int _parked = 0;
  bool _finishedTask = false;

  SettingsService get s => widget.settings;
  double get _time => _clock.elapsedMilliseconds / 1000;
  String get _taskText =>
      _task.text.trim().isEmpty ? 'your task' : _task.text.trim();
  bool get _active => _engine.active;
  int? get _currentStep {
    for (var i = 0; i < _steps.length; i++) {
      if (!_doneSteps.contains(i)) return i;
    }
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _task = TextEditingController(text: s.focusTask);
    for (final step in s.focusSteps) {
      _stepFields.add(TextEditingController(text: step));
    }
    s.addListener(_refresh);
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    _engine.onPhaseComplete = _onPhaseComplete;
    _engine.onPhaseStart = _onPhaseStart;
    // Only this screen turns with the phone: sideways = flip-clock desk view.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    _frame.dispose();
    s.removeListener(_refresh);
    _task.dispose();
    for (final c in _stepFields) {
      c.dispose();
    }
    if (_active) NotificationService.cancelAlert(TimerAlert.focus);
    DeviceService.keepScreenOn(false);
    // The rest of the app stays upright.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _haptic(Future<void> Function() feedback) {
    if (s.haptics) feedback();
  }

  // ── Engine events ─────────────────────────────────────────────────────────
  void _onPhaseStart(PomoPhase phase, int round) {
    if (phase == PomoPhase.focus) {
      _checkIn = _CheckIn.none;
      _roundCheckIns = 0;
      _roundDrifts = 0;
      _nextCheckInMs = _scheduleCheckIn(0);
      _lastTouch = DateTime.now();
    }
    if (_hidden) _scheduleAlert();
  }

  void _onPhaseComplete(PomoPhase phase, int round, int ms) {
    if (phase == PomoPhase.focus) {
      _logRound(ms, completed: true);
      _haptic(HapticFeedback.heavyImpact);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _haptic(HapticFeedback.heavyImpact);
      });
    } else {
      _haptic(HapticFeedback.mediumImpact);
    }
    if (_hidden) {
      final (title, body) = _endMessage(phase, round);
      NotificationService.showAlert(TimerAlert.focus, title, body);
    }
  }

  /// What to say when [phase] of [round] ends.
  (String, String) _endMessage(PomoPhase phase, int round) {
    if (phase != PomoPhase.focus) {
      return ("Break's over ☕", 'Round ${round + 1} of "$_taskText" is ready.');
    }
    final plan = _engine.plan;
    final next = plan.breakAfter(round);
    if (round >= plan.rounds) {
      return ('Session complete 🕯️', 'Nice work on "$_taskText".');
    }
    if (next == null) {
      return ('Round $round done 🍅', 'On to round ${round + 1}.');
    }
    final mins =
        (next == PomoPhase.longBreak ? plan.longBreakMs : plan.breakMs) ~/
            60000;
    return ('Round $round done 🍅', 'Time for a $mins-minute break.');
  }

  void _logRound(int ms, {required bool completed}) {
    final seconds = ms ~/ 1000;
    if (seconds < 60) return;
    FocusLog.add(
      seconds: seconds,
      task: _taskText,
      completed: completed,
      checkIns: _roundCheckIns,
      drifts: _roundDrifts,
    ).then((_) => NotificationService.sync()); // focus keeps the streak alive
  }

  int _scheduleCheckIn(int fromMs) {
    final gap = (_engine.plan.focusMs / 3).clamp(120000.0, 600000.0);
    return fromMs + (gap * (0.75 + _rng.nextDouble() * 0.5)).round();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker =
        Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted) return;
    final before = (_engine.stage, _engine.phase, _engine.round);
    _engine.tick();
    if (_engine.stage == PomoStage.finished) {
      _endSession(celebrate: true);
      return;
    }
    var changed = before != (_engine.stage, _engine.phase, _engine.round);

    // Gentle check-in to catch daydreaming
    if (_engine.stage == PomoStage.running &&
        _engine.phase == PomoPhase.focus &&
        !_engine.paused &&
        s.focusCheckIns &&
        !_hidden &&
        _checkIn == _CheckIn.none) {
      final ms = _engine.elapsedMs;
      if (ms >= _nextCheckInMs && ms < _engine.phaseMs - 45000) {
        _haptic(HapticFeedback.lightImpact);
        _checkIn = _CheckIn.asking;
        _lastTouch = DateTime.now();
        changed = true;
      }
    }

    // Deep mode: after a quiet moment, fade everything but the timer.
    final deep = s.focusDeep &&
        _engine.stage == PomoStage.running &&
        _engine.phase == PomoPhase.focus &&
        !_engine.paused &&
        _checkIn == _CheckIn.none &&
        DateTime.now().difference(_lastTouch) > _deepAfter;
    if (deep != _deep) {
      _deep = deep;
      if (deep) {
        _deepSince = DateTime.now();
        _deepEntries++;
      }
      changed = true;
    }
    if (changed) setState(() {});
  }

  void _wake() {
    _lastTouch = DateTime.now();
    if (_deep) setState(() => _deep = false);
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _start() {
    FocusScope.of(context).unfocus();
    _steps = _stepFields
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    s.setFocusPlan(_task.text.trim(), _steps);
    _haptic(HapticFeedback.mediumImpact);
    setState(() {
      _doneSteps.clear();
      _checkIns = 0;
      _drifts = 0;
      _parked = 0;
      _finishedTask = false;
      _ended = false;
      _deep = false;
      _deepEntries = 0;
      _engine.start(s.focusPreset.plan(s.focusRounds),
          autoContinue: s.focusAuto);
    });
    _startTicker();
    DeviceService.keepScreenOn(s.focusAwake);
  }

  void _togglePause() {
    if (_engine.stage != PomoStage.running) return;
    _haptic(HapticFeedback.selectionClick);
    setState(() {
      if (_engine.paused) {
        _engine.resume();
        _lastTouch = DateTime.now();
        if (_hidden) _scheduleAlert();
      } else {
        _engine.pause();
        NotificationService.cancelAlert(TimerAlert.focus);
      }
    });
  }

  void _startNext() {
    _haptic(HapticFeedback.mediumImpact);
    setState(_engine.startNext);
  }

  void _skipBreak() {
    _haptic(HapticFeedback.selectionClick);
    NotificationService.cancelAlert(TimerAlert.focus);
    setState(_engine.skipBreak);
  }

  void _completeStep() {
    final i = _currentStep;
    if (i == null) return;
    _haptic(HapticFeedback.mediumImpact);
    setState(() => _doneSteps.add(i));
    if (_currentStep == null) {
      showThemedToast(context,
          'All steps done ✨ Keep going, or wrap up when you\'re ready.');
    }
  }

  void _finish({bool task = false}) {
    final partial = _engine.finish();
    if (partial > 0) _logRound(partial, completed: false);
    _finishedTask = task;
    _endSession(celebrate: task);
  }

  void _endSession({bool celebrate = false}) {
    if (_ended) return;
    _ended = true;
    _ticker?.cancel();
    DeviceService.keepScreenOn(false);
    if (!_hidden) NotificationService.cancelAlert(TimerAlert.focus);
    if (celebrate) {
      _haptic(HapticFeedback.heavyImpact);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _haptic(HapticFeedback.heavyImpact);
      });
    }
    setState(() {
      _deep = false;
      _checkIn = _CheckIn.none;
    });
  }

  void _newSession() {
    setState(() {
      _engine.stage = PomoStage.idle;
      if (_finishedTask) {
        _task.clear();
        for (final c in _stepFields) {
          c.dispose();
        }
        _stepFields.clear();
      } else {
        // Keep the steps that weren't done yet.
        final open = [
          for (var i = 0; i < _steps.length; i++)
            if (!_doneSteps.contains(i)) _steps[i],
        ];
        for (final c in _stepFields) {
          c.dispose();
        }
        _stepFields
          ..clear()
          ..addAll(open.map((t) => TextEditingController(text: t)));
      }
    });
  }

  void _answerCheckIn(bool stillHere) {
    _haptic(HapticFeedback.selectionClick);
    setState(() {
      _checkIns++;
      _roundCheckIns++;
      _lastTouch = DateTime.now();
      if (stillHere) {
        _checkIn = _CheckIn.none;
        _nextCheckInMs = _scheduleCheckIn(_engine.elapsedMs);
      } else {
        _drifts++;
        _roundDrifts++;
        _checkIn = _CheckIn.drifted;
      }
    });
  }

  void _backToIt() {
    _haptic(HapticFeedback.lightImpact);
    setState(() {
      _checkIn = _CheckIn.none;
      _lastTouch = DateTime.now();
      _nextCheckInMs = _scheduleCheckIn(_engine.elapsedMs);
    });
  }

  Future<void> _requestExit() async {
    if (!_active) {
      Navigator.pop(context);
      return;
    }
    final wasRunning = _engine.stage == PomoStage.running && !_engine.paused;
    if (wasRunning) _togglePause();
    final stop = await showThemedConfirm(
      context,
      title: 'Stop this session?',
      body: 'Your focused time so far is saved.',
      cancel: 'Keep going',
      action: 'Stop',
      tint: pal.warm,
    );
    if (!mounted) return;
    if (stop) {
      _finish();
    } else if (wasRunning) {
      _togglePause();
    }
  }

  Future<void> _wrapUpMenu() async {
    _haptic(HapticFeedback.selectionClick);
    final focusRunning =
        _engine.stage == PomoStage.running && _engine.phase == PomoPhase.focus;
    final hasNext = _engine.round < _engine.plan.rounds;
    final choice = await showModalBottomSheet<String>(
      context: context,
      // Sized to its content, and scrolls with very large text.
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 14),
              Text('Wrap up?',
                  style: TextStyle(
                      fontSize: 17,
                      color: pal.textBright,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              _sheetOption(ctx, 'done', '🎉', 'My task is done',
                  'Celebrate and end the session'),
              if (focusRunning && hasNext)
                _sheetOption(ctx, 'early', '☕', 'End this round early',
                    'Go straight to the break'),
              _sheetOption(ctx, 'stop', '⏹', 'Stop for now',
                  'Your focused time is saved'),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'done':
        _finish(task: true);
      case 'early':
        setState(_engine.endRoundEarly);
        if (_engine.stage == PomoStage.finished) _endSession(celebrate: true);
      case 'stop':
        _finish();
    }
  }

  Future<void> _parkThought() async {
    _haptic(HapticFeedback.selectionClick);
    _lastTouch = DateTime.now();
    final ctrl = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            22, 14, 22, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 16),
            Text('Park a thought 💭',
                style: TextStyle(
                    fontSize: 17,
                    color: pal.textBright,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
                'Write it down so your mind can let it go. It will wait for you.',
                style: TextStyle(fontSize: 12, color: pal.textDim)),
            const SizedBox(height: 14),
            _field(ctrl,
                hint: 'e.g. Reply to Sam, look up that function…',
                icon: Icons.cloud_outlined,
                autofocus: true,
                onSubmitted: (v) => Navigator.pop(ctx, v)),
            const SizedBox(height: 14),
            ThemedButton(
                label: 'PARK IT',
                tint: pal.warm,
                onTap: () => Navigator.pop(ctx, ctrl.text)),
          ],
        ),
      ),
    );
    // Dispose after the sheet's closing animation has finished.
    Future.delayed(const Duration(milliseconds: 600), ctrl.dispose);
    if (text == null || text.trim().isEmpty) return;
    await ThoughtStore.add(text);
    if (!mounted) return;
    setState(() => _parked++);
    showThemedToast(context, 'Parked. Back to "$_taskText" 🕯️');
  }

  Future<void> _openThoughts() async {
    _haptic(HapticFeedback.selectionClick);
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => ThoughtsScreen(settings: s),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
    _refresh();
  }

  // ── Background / foreground ───────────────────────────────────────────────
  void _onHide() {
    _hidden = true;
    _scheduleAlert();
  }

  void _scheduleAlert() {
    if (_engine.stage != PomoStage.running || _engine.paused) return;
    final (title, body) = _endMessage(_engine.phase, _engine.round);
    NotificationService.scheduleAlert(TimerAlert.focus,
        Duration(milliseconds: _engine.remainingMs), title, body);
  }

  void _onShow() {
    _hidden = false;
    _lastTouch = DateTime.now();
    NotificationService.cancelAlert(TimerAlert.focus);
    if (_active) _onTick();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final stage = _engine.stage;
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final view = switch (stage) {
      PomoStage.idle => 'setup',
      PomoStage.finished => 'summary',
      PomoStage.between => 'between-${_engine.phase.name}-${_engine.round}',
      PomoStage.running => _engine.isBreak ? 'break' : 'focus',
    };
    return PopScope(
      canPop: !_active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _wake(),
          child: Stack(
            children: [
              AnimatedBackground(theme: s.bgTheme),
              ThemedScrim(_deep ? 0.84 : (_active ? 0.62 : 0.5)),
              // Warm light rising from the bottom, like a desk lamp
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.35),
                      radius: 0.9,
                      colors: [
                        pal.warm.withValues(alpha: _deep ? 0.05 : 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _fade(_topBar()),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        child: KeyedSubtree(
                          key: ValueKey(view),
                          child: switch (stage) {
                            PomoStage.running when landscape => _engine.isBreak
                                ? _breakLandscape()
                                : _focusLandscape(),
                            PomoStage.running =>
                              _engine.isBreak ? _breakView() : _focusView(),
                            PomoStage.idle => _narrow(landscape, _setupView()),
                            PomoStage.finished =>
                              _narrow(landscape, _summaryView()),
                            PomoStage.between =>
                              _narrow(landscape, _betweenView()),
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
      ),
    );
  }

  /// Sideways, keep forms and summaries at a comfortable reading width.
  Widget _narrow(bool landscape, Widget child) => landscape
      ? Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        )
      : child;

  /// Folds away in deep mode, giving its room to the flip clock.
  Widget _collapse(Widget child) => AnimatedSize(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        child: _deep ? const SizedBox(width: double.infinity) : _fade(child),
      );

  /// Fades away in deep mode (and can't be tapped then).
  Widget _fade(Widget child) => IgnorePointer(
        ignoring: _deep,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 900),
          opacity: _deep ? 0 : 1,
          child: child,
        ),
      );

  Widget _topBar() {
    final label = switch (_engine.stage) {
      PomoStage.idle => 'FOCUS',
      PomoStage.finished => 'FOCUS · DONE',
      _ => _engine.isBreak
          ? (_engine.phase == PomoPhase.longBreak ? 'LONG BREAK' : 'BREAK')
          : 'FOCUS · ROUND ${_engine.round} OF ${_engine.plan.rounds}',
    };
    return ThemedTopBar(
      title: label,
      onBack: _requestExit,
      icon: _active ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
      trailing: SoundPickerWidget(
        audio: widget.audio,
        haptics: s.haptics,
        onChanged: s.setSoundMode,
      ),
    );
  }

  // ── Setup ─────────────────────────────────────────────────────────────────
  Widget _setupView() {
    final preset = s.focusPreset;
    final open = ThoughtStore.openCount;
    final todayRounds = FocusLog.todayRounds;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: _frame,
                    builder: (_, __) =>
                        _visual(s.focusVisual, height: 110, progress: 0.3),
                  ),
                ),
                const SizedBox(height: 10),
                Text('What are you\nworking on?',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w200,
                        color: pal.textBright,
                        height: 1.15)),
                if (todayRounds > 0 || FocusLog.todayMinutes > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                      'Today: 🍅 $todayRounds round${todayRounds == 1 ? '' : 's'} · '
                      '${FocusLog.todayMinutes} min focused',
                      style: TextStyle(fontSize: 12, color: pal.warm)),
                ],
                const SizedBox(height: 14),
                _field(_task,
                    hint: 'e.g. Math homework — chapter 4',
                    icon: Icons.edit_note_rounded),
                const SizedBox(height: 22),
                _label('STEPS'),
                Text('Break it into small pieces. Make the first one easy.',
                    style: TextStyle(fontSize: 11, color: pal.textDim)),
                const SizedBox(height: 10),
                for (var i = 0; i < _stepFields.length; i++) ...[
                  _stepRow(i),
                  const SizedBox(height: 8),
                ],
                if (_stepFields.length < _maxSteps) _addStepButton(),
                if (_stepFields.isEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final idea in _stepIdeas)
                        Pressable(
                          onTap: () => _addStep(idea),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: pal.chip(false, tint: pal.warm),
                            child: Text(idea,
                                style: TextStyle(
                                    fontSize: 11, color: pal.textMid)),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _label('RHYTHM'),
                _presetChips(),
                const SizedBox(height: 8),
                Text(preset.hint,
                    style: TextStyle(fontSize: 11, color: pal.textDim)),
                if (!preset.isTiny) ...[
                  const SizedBox(height: 14),
                  _roundsStepper(),
                ],
                const SizedBox(height: 6),
                Text(_planSummary(),
                    style: TextStyle(fontSize: 11, color: pal.textMid)),
                const SizedBox(height: 24),
                _label('TIMER STYLE'),
                _visualPicker(),
                if (MediaQuery.sizeOf(context).height >
                    MediaQuery.sizeOf(context).width) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.screen_rotation_rounded,
                          size: 15, color: pal.warm),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Turn your phone sideways while focusing for a '
                            'flip-clock desk view.',
                            style: TextStyle(fontSize: 11, color: pal.textDim)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _label('HELPERS'),
                _helpersPanel(),
                if (open > 0) ...[
                  const SizedBox(height: 12),
                  _thoughtsLink(open),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: ThemedButton(
            label: preset.isTiny ? 'JUST START' : 'START FOCUS',
            icon: Icons.play_arrow_rounded,
            tint: pal.warm,
            onTap: _start,
          ),
        ),
      ],
    );
  }

  void _addStep([String text = '']) {
    if (_stepFields.length >= _maxSteps) return;
    _haptic(HapticFeedback.selectionClick);
    setState(() => _stepFields.add(TextEditingController(text: text)));
  }

  Widget _stepRow(int i) {
    return Row(
      children: [
        Expanded(
          child: _field(_stepFields[i],
              hint: i == 0 ? 'A tiny first step' : 'Next step',
              icon: Icons.radio_button_unchecked_rounded,
              dense: true),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            _haptic(HapticFeedback.selectionClick);
            setState(() => _stepFields.removeAt(i).dispose());
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.close_rounded, size: 18, color: pal.textDim),
          ),
        ),
      ],
    );
  }

  Widget _addStepButton() {
    return Pressable(
      onTap: _addStep,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: pal.panel(scale: 0.8),
        child: Row(
          children: [
            Icon(Icons.add_rounded, size: 18, color: pal.warm),
            const SizedBox(width: 10),
            Text(_stepFields.isEmpty ? 'Add a first step' : 'Add a step',
                style: TextStyle(fontSize: 13, color: pal.textMid)),
          ],
        ),
      ),
    );
  }

  Widget _presetChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in kPomodoroPresets)
          Pressable(
            onTap: () {
              _haptic(HapticFeedback.selectionClick);
              s.setFocusPreset(p.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: pal.chip(s.focusPreset.id == p.id, tint: pal.warm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.name,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: s.focusPreset.id == p.id
                              ? pal.warm
                              : pal.textMid)),
                  const SizedBox(height: 2),
                  Text(p.rhythm,
                      style: TextStyle(fontSize: 10, color: pal.textDim)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _roundsStepper() {
    Widget button(IconData icon, VoidCallback? onTap) => Pressable(
          onTap: onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: onTap == null ? 0.35 : 1,
            child: Container(
              width: 36,
              height: 36,
              decoration: pal.chip(false, tint: pal.warm, scale: 0.5),
              child: Icon(icon, size: 18, color: pal.textMid),
            ),
          ),
        );
    final n = s.focusRounds;
    return Row(
      children: [
        Text('Rounds', style: TextStyle(fontSize: 13, color: pal.textMid)),
        const Spacer(),
        button(
            Icons.remove_rounded, n > 1 ? () => s.setFocusRounds(n - 1) : null),
        SizedBox(
          width: 44,
          child: Center(
            child: Text('$n',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: pal.textBright)),
          ),
        ),
        button(Icons.add_rounded, n < 8 ? () => s.setFocusRounds(n + 1) : null),
      ],
    );
  }

  String _planSummary() {
    final plan = s.focusPreset.plan(s.focusRounds);
    final mins = plan.totalMs ~/ 60000;
    final length =
        mins >= 60 ? '${mins ~/ 60} h ${mins % 60} min' : '$mins min';
    final end = TimeOfDay.fromDateTime(
            DateTime.now().add(Duration(milliseconds: plan.totalMs)))
        .format(context);
    final rounds = plan.rounds == 1
        ? '1 round'
        : '${plan.rounds} rounds of ${s.focusPreset.focusMin} min';
    return '$rounds · $length in all · done around $end';
  }

  Widget _visualPicker() {
    return AnimatedBuilder(
      animation: _frame,
      builder: (_, __) => Row(
        children: [
          for (final v in kFocusVisuals)
            Expanded(
              child: Pressable(
                onTap: () {
                  _haptic(HapticFeedback.selectionClick);
                  s.setFocusVisual(v.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin:
                      EdgeInsets.only(right: v == kFocusVisuals.last ? 0 : 8),
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                  decoration: pal.chip(s.focusVisual == v.id, tint: pal.warm),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 46,
                        child: Center(
                          child: _visual(v.id, height: 46, progress: 0.4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: s.focusVisual == v.id
                                  ? pal.warm
                                  : pal.textDim)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _helpersPanel() {
    Widget row(IconData icon, String label, String sub, bool value,
            ValueChanged<bool> onChanged) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: pal.textDim, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              color: pal.textMid,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 1),
                      Text(sub,
                          style: TextStyle(fontSize: 10.5, color: pal.textDim)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                NatureSwitch(
                    value: value, onChanged: onChanged, color: pal.warm),
              ],
            ),
          ),
        );
    final divider = Divider(height: 1, thickness: 1, color: pal.line);
    return Container(
      decoration: pal.panel(),
      child: Column(
        children: [
          row(
              Icons.blur_on_rounded,
              'Deep mode',
              'Buttons hide a few seconds after you touch — only the timer stays',
              s.focusDeep,
              s.setFocusDeep),
          divider,
          row(Icons.light_mode_outlined, 'Keep screen on',
              'Use your phone as a desk timer', s.focusAwake, s.setFocusAwake),
          divider,
          row(
              Icons.self_improvement_rounded,
              'Gentle check-ins',
              'A soft "still with it?" to catch daydreaming',
              s.focusCheckIns,
              s.setFocusCheckIns),
          divider,
          row(
              Icons.autorenew_rounded,
              'Auto-continue',
              'Start breaks and next rounds by themselves',
              s.focusAuto,
              s.setFocusAuto),
        ],
      ),
    );
  }

  Widget _thoughtsLink(int open) {
    return Pressable(
      onTap: _openThoughts,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: pal.panel(),
        child: Row(
          children: [
            const Text('💭', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  '$open parked thought${open == 1 ? '' : 's'} waiting for you',
                  style: TextStyle(fontSize: 13, color: pal.textMid)),
            ),
            Icon(Icons.chevron_right_rounded, color: pal.textDim, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Focus ─────────────────────────────────────────────────────────────────
  Widget _focusView() {
    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _frame,
            builder: (context, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _collapse(_roundDots()),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 900),
                  opacity: _deep ? 0.6 : 1,
                  child: Text(_fmt(_engine.remainingMs),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w200,
                        color: pal.textBright,
                        letterSpacing: 2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                ),
                _collapse(_taskHeader()),
                const SizedBox(height: 14),
                // The drawing takes whatever room is left (never overflows).
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final visual = focusVisualById(s.focusVisual);
                      var h = min(box.maxHeight, 330.0);
                      if (h * visual.aspect > box.maxWidth * 0.8) {
                        h = box.maxWidth * 0.8 / visual.aspect;
                      }
                      return _visual(s.focusVisual,
                          height: max(h, 0),
                          progress: _engine.progress,
                          lit: !_engine.paused);
                    },
                  ),
                ),
                SizedBox(height: 20, child: _statusHint()),
              ],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(sizeFactor: anim, child: child),
          ),
          child: _checkIn == _CheckIn.none
              ? const SizedBox(width: double.infinity)
              : KeyedSubtree(key: ValueKey(_checkIn), child: _checkInCard()),
        ),
        _collapse(Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          child: _controls(),
        )),
      ],
    );
  }

  /// Sideways: the timer style on the left, a big flip clock on the right —
  /// a desk clock. In deep mode only the drawing and the clock remain.
  Widget _focusLandscape() {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _frame,
          builder: (context, _) => Row(
            children: [
              Expanded(
                flex: 5,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final visual = focusVisualById(s.focusVisual);
                    var h = min(box.maxHeight * 0.88, 380.0);
                    if (h * visual.aspect > box.maxWidth * 0.9) {
                      h = box.maxWidth * 0.9 / visual.aspect;
                    }
                    return Center(
                      child: _visual(s.focusVisual,
                          height: max(h, 0),
                          progress: _engine.progress,
                          lit: !_engine.paused),
                    );
                  },
                ),
              ),
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _collapse(Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _roundDots(),
                      )),
                      Flexible(child: _flipClock(_engine.remainingMs, 170)),
                      _collapse(Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            _taskHeader(),
                            const SizedBox(height: 10),
                            _controls(),
                          ],
                        ),
                      )),
                      SizedBox(height: 20, child: _statusHint()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_checkIn != _CheckIn.none)
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _checkInCard(),
            ),
          ),
      ],
    );
  }

  /// A flip clock as big as the space allows (up to [maxHeight]).
  Widget _flipClock(int ms, double maxHeight) {
    final text = _fmt(ms);
    return LayoutBuilder(
      builder: (context, box) {
        final perUnit = FlipClock.widthFor(text, 1);
        final h = min(min(box.maxHeight, box.maxWidth / perUnit), maxHeight);
        return Center(
          child: FlipClock(
            text: text,
            height: max(h, 0),
            dim: _deep || _engine.paused,
          ),
        );
      },
    );
  }

  /// Park · Pause · Wrap up. The side buttons shrink to fit narrow spaces.
  Widget _controls() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: _sideButton(
                Icons.cloud_outlined, 'Park a thought', _parkThought),
          ),
          _pauseButton(),
          Flexible(
            child: _sideButton(Icons.flag_outlined, 'Wrap up', _wrapUpMenu),
          ),
        ],
      );

  Widget _statusHint() => Center(
        child: _engine.paused
            ? Text('Paused — take your time',
                style: TextStyle(fontSize: 12, color: pal.textDim))
            : AnimatedOpacity(
                duration: const Duration(milliseconds: 900),
                opacity: _deep &&
                        _deepEntries <= 1 &&
                        DateTime.now().difference(_deepSince) <
                            const Duration(seconds: 6)
                    ? 0.5
                    : 0,
                child: Text('deep focus · tap to show controls',
                    style: TextStyle(
                        fontSize: 11, color: pal.textDim, letterSpacing: 1)),
              ),
      );

  Widget _taskHeader() {
    final step = _currentStep;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(_taskText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w300,
                  color: pal.textMid)),
          if (_steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (step != null)
              Pressable(
                onTap: _completeStep,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pal.chip(true, tint: pal.warm, scale: 0.6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_box_outline_blank_rounded,
                          size: 17, color: pal.warm),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('Now: ${_steps[step]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 13, color: pal.textBright)),
                      ),
                      const SizedBox(width: 8),
                      Text('${_doneSteps.length + 1}/${_steps.length}',
                          style: TextStyle(fontSize: 11, color: pal.textDim)),
                    ],
                  ),
                ),
              )
            else
              Text('✓ All steps done',
                  style: TextStyle(fontSize: 13, color: pal.warm)),
          ],
        ],
      ),
    );
  }

  /// One mark per round: done, current, upcoming — in the theme's shape.
  Widget _roundDots() {
    final rounds = _engine.plan.rounds;
    if (rounds <= 1) return const SizedBox(height: 8);
    final shape = BorderRadius.circular((pal.radius / 3).clamp(1.5, 5.0));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= rounds; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: shape,
              color: i <= _engine.completedRounds
                  ? pal.warm
                  : pal.surface.withValues(alpha: 0.6),
              border: Border.all(
                color: i == _engine.round && i > _engine.completedRounds
                    ? pal.warm
                    : pal.line,
                width: i == _engine.round ? 1.5 : 1,
              ),
            ),
          ),
      ],
    );
  }

  Widget _checkInCard() {
    final asking = _checkIn == _CheckIn.asking;
    final step = _currentStep;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(pal.warm.withValues(alpha: 0.08), pal.dialog),
        borderRadius: pal.corners(),
        border: Border.all(color: pal.warm.withValues(alpha: 0.35)),
      ),
      child: asking
          ? Column(
              children: [
                Text('Still with it?',
                    style: TextStyle(
                        fontSize: 16,
                        color: pal.textBright,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(_taskText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: pal.textDim)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ThemedButton(
                          label: 'I drifted',
                          primary: false,
                          height: 46,
                          onTap: () => _answerCheckIn(false)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ThemedButton(
                          label: "I'm here",
                          tint: pal.warm,
                          height: 46,
                          onTap: () => _answerCheckIn(true)),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Text("That's okay — minds wander. 🌿",
                    style: TextStyle(fontSize: 15, color: pal.textBright)),
                const SizedBox(height: 6),
                Text(
                    'Take one slow breath. Then just: '
                    '${step != null ? _steps[step] : _taskText}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: pal.textMid, height: 1.4)),
                const SizedBox(height: 14),
                ThemedButton(
                    label: 'Back to it',
                    tint: pal.warm,
                    height: 46,
                    onTap: _backToIt),
              ],
            ),
    );
  }

  Widget _pauseButton() {
    final paused = _engine.paused;
    return Pressable(
      onTap: _togglePause,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          // Shape follows the theme: round for soft styles, squarer for crisp.
          borderRadius: BorderRadius.circular(min(pal.radius * 1.4, 32)),
          color: Color.alphaBlend(
              pal.warm.withValues(alpha: paused ? 0.30 : 0.18),
              pal.surface.withValues(alpha: 0.85)),
          border: Border.all(color: pal.warm.withValues(alpha: 0.5)),
        ),
        child: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: pal.warm, size: 30),
      ),
    );
  }

  Widget _sideButton(IconData icon, String label, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(min(pal.radius, 22)),
                color: pal.surface.withValues(alpha: 0.65),
                border:
                    Border.all(color: pal.textBright.withValues(alpha: 0.12)),
              ),
              child: Icon(icon, size: 20, color: pal.textMid),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: pal.textDim)),
          ],
        ),
      ),
    );
  }

  // ── Break ─────────────────────────────────────────────────────────────────
  /// Sideways break: tea on the left, the break counting down on the right.
  Widget _breakLandscape() {
    final long = _engine.phase == PomoPhase.longBreak;
    return AnimatedBuilder(
      animation: _frame,
      builder: (context, _) {
        final idea = _breakIdeas[
            (_engine.elapsedMs ~/ 30000 + _engine.round) % _breakIdeas.length];
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = min(
                      min(box.maxHeight * 0.85, box.maxWidth * 0.85), 280.0);
                  return Center(
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: CustomPaint(
                          painter: TeaPainter(time: _time, glow: pal.warm)),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(long ? 'LONG BREAK' : 'BREAK',
                        style: pal.labelText.copyWith(color: pal.warm)),
                    const SizedBox(height: 8),
                    Flexible(child: _flipClock(_engine.remainingMs, 120)),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: Text(idea,
                          key: ValueKey(idea),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: pal.textBright)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        'Next: round ${_engine.round + 1} of ${_engine.plan.rounds} · '
                        '${_engine.plan.focusMs ~/ 60000} min',
                        style: TextStyle(fontSize: 12, color: pal.textDim)),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Row(
                        children: [
                          Expanded(
                            child: ThemedButton(
                                label: 'WRAP UP',
                                primary: false,
                                height: 46,
                                onTap: _wrapUpMenu),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ThemedButton(
                                label: 'SKIP BREAK',
                                tint: pal.warm,
                                height: 46,
                                onTap: _skipBreak),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _breakView() {
    final long = _engine.phase == PomoPhase.longBreak;
    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _frame,
            builder: (context, _) {
              final idea = _breakIdeas[
                  (_engine.elapsedMs ~/ 30000 + _engine.round) %
                      _breakIdeas.length];
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(long ? 'LONG BREAK' : 'BREAK',
                      style: pal.labelText.copyWith(color: pal.warm)),
                  const SizedBox(height: 6),
                  Text(_fmt(_engine.remainingMs),
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w200,
                        color: pal.textBright,
                        letterSpacing: 2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CustomPaint(
                        painter: TeaPainter(time: _time, glow: pal.warm)),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: Padding(
                      key: ValueKey(idea),
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(idea,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w300,
                              color: pal.textBright)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _roundDots(),
                  const SizedBox(height: 8),
                  Text(
                      'Next: round ${_engine.round + 1} of ${_engine.plan.rounds} · '
                      '${_engine.plan.focusMs ~/ 60000} min',
                      style: TextStyle(fontSize: 12, color: pal.textDim)),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Row(
            children: [
              Expanded(
                child: ThemedButton(
                    label: 'WRAP UP',
                    primary: false,
                    height: 50,
                    onTap: _wrapUpMenu),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ThemedButton(
                    label: 'SKIP BREAK',
                    tint: pal.warm,
                    height: 50,
                    onTap: _skipBreak),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Between phases (auto-continue off) ───────────────────────────────────
  Widget _betweenView() {
    final nextIsBreak = _engine.isBreak;
    final plan = _engine.plan;
    final breakMin = (_engine.phase == PomoPhase.longBreak
            ? plan.longBreakMs
            : plan.breakMs) ~/
        60000;
    final title =
        nextIsBreak ? 'Round ${_engine.round} done 🍅' : "Break's over";
    final body = nextIsBreak
        ? 'Take a $breakMin-minute ${_engine.phase == PomoPhase.longBreak ? 'long ' : ''}break — you earned it.'
        : 'Ready for round ${_engine.round} of ${plan.rounds}?';
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedBuilder(
                animation: _frame,
                builder: (_, __) => Column(
                  children: [
                    nextIsBreak
                        ? _visual(s.focusVisual, height: 170, progress: 1)
                        : SizedBox(
                            width: 180,
                            height: 180,
                            child: CustomPaint(
                                painter:
                                    TeaPainter(time: _time, glow: pal.warm)),
                          ),
                    const SizedBox(height: 18),
                    Text(title,
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w200,
                            color: pal.textBright)),
                    const SizedBox(height: 8),
                    Text(body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, color: pal.textMid, height: 1.5)),
                    const SizedBox(height: 14),
                    _roundDots(),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            children: [
              ThemedButton(
                label: nextIsBreak
                    ? 'START BREAK'
                    : 'START ROUND ${_engine.round}',
                icon: nextIsBreak
                    ? Icons.coffee_rounded
                    : Icons.play_arrow_rounded,
                tint: pal.warm,
                onTap: _startNext,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (nextIsBreak) ...[
                    Expanded(
                      child: ThemedButton(
                          label: 'SKIP BREAK',
                          primary: false,
                          height: 48,
                          onTap: _skipBreak),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ThemedButton(
                        label: 'WRAP UP',
                        primary: false,
                        height: 48,
                        onTap: _wrapUpMenu),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  Widget _summaryView() {
    final plan = _engine.plan;
    final minutes = (_engine.focusedMs / 60000).round();
    final allRounds = _engine.completedRounds >= plan.rounds;
    final title = _finishedTask
        ? 'Task done! 🎉'
        : allRounds
            ? 'Session complete.'
            : 'Good effort.';
    final body = _finishedTask
        ? 'You finished "$_taskText".\nRemember this feeling.'
        : allRounds
            ? '$minutes focused minutes on "$_taskText".\nThat\'s real deep work.'
            : minutes >= 1
                ? '$minutes minute${minutes == 1 ? '' : 's'} of focus still counts.\n'
                    'Next time, try an even tinier first step.'
                : 'Even sitting down to try matters.\n'
                    'Next time, try an even tinier first step.';
    final open = ThoughtStore.openCount;
    final onTask = _checkIns - _drifts;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _frame,
                  builder: (_, __) => _visual(s.focusVisual,
                      height: 150,
                      progress:
                          allRounds || _finishedTask ? 1 : _engine.progress),
                ),
                const SizedBox(height: 16),
                Text(title,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        color: pal.textBright)),
                const SizedBox(height: 8),
                Text(body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: pal.textMid, height: 1.5)),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                        child: StatTile('ROUNDS',
                            '${_engine.completedRounds}/${plan.rounds}')),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile('FOCUSED', '${minutes}m')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: StatTile(
                            'STEPS',
                            _steps.isEmpty
                                ? '—'
                                : '${_doneSteps.length}/${_steps.length}')),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile('PARKED', '$_parked')),
                  ],
                ),
                const SizedBox(height: 14),
                if (_checkIns > 0)
                  Text('On task at $onTask of $_checkIns check-ins',
                      style: TextStyle(fontSize: 12, color: pal.textMid)),
                const SizedBox(height: 4),
                Text(
                    'Today: 🍅 ${FocusLog.todayRounds} rounds · '
                    '${FocusLog.todayMinutes} min focused',
                    style: TextStyle(fontSize: 12, color: pal.warm)),
                if (open > 0) ...[
                  const SizedBox(height: 14),
                  _thoughtsLink(open),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Row(
            children: [
              Expanded(
                child: ThemedButton(
                    label: 'DONE',
                    primary: false,
                    onTap: () => Navigator.pop(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ThemedButton(
                    label: _finishedTask ? 'NEW TASK' : 'NEW SESSION',
                    tint: pal.warm,
                    onTap: _newSession),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────────────
  Widget _visual(String id,
      {required double height, required double progress, bool lit = true}) {
    final v = focusVisualById(id);
    return SizedBox(
      width: height * v.aspect,
      height: height,
      child: CustomPaint(
        painter: focusVisualPainter(id,
            progress: progress, time: _time, color: pal.warm, lit: lit),
      ),
    );
  }

  Widget _field(
    TextEditingController c, {
    required String hint,
    required IconData icon,
    bool autofocus = false,
    bool dense = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      maxLength: 80,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      onSubmitted: onSubmitted,
      cursorColor: pal.warm,
      style: TextStyle(color: pal.textBright, fontSize: dense ? 14 : 15),
      decoration: InputDecoration(
        counterText: '',
        isDense: dense,
        hintText: hint,
        hintStyle: TextStyle(color: pal.textDim, fontSize: dense ? 13 : 14),
        prefixIcon: Icon(icon, color: pal.textDim, size: dense ? 18 : 20),
        filled: true,
        fillColor: pal.surface.withValues(alpha: 0.6),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 12 : 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: pal.corners(0.8),
          borderSide: BorderSide(color: pal.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: pal.corners(0.8),
          borderSide: BorderSide(color: pal.warm.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _sheetHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: pal.textBright.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _sheetOption(
      BuildContext ctx, String id, String emoji, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: () => Navigator.pop(ctx, id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pal.panel(scale: 0.8),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            color: pal.textBright,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(fontSize: 11, color: pal.textDim)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: pal.label),
      );

  static String _fmt(int ms) {
    final secs = (ms / 1000).ceil();
    return '${(secs ~/ 60).toString().padLeft(2, '0')}:'
        '${(secs % 60).toString().padLeft(2, '0')}';
  }
}
