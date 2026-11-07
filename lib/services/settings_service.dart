import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/breath_pattern.dart' show isKnownBreathPattern;
import '../models/pomodoro.dart';
import '../models/practice.dart';
import '../widgets/cozy_painters.dart' show focusVisualById;
import '../widgets/animated_background.dart' show isKnownBackground;
import 'audio_service.dart';
import 'notification_service.dart';

/// The app-wide settings (loaded in main, shared by every screen).
final SettingsService appSettings = SettingsService();

/// All user preferences, persisted in the 'prefs' Hive box.
class SettingsService extends ChangeNotifier {
  /// Session length choices in minutes (0 = unlimited).
  static const sessionTargets = [0, 5, 10, 15, 20, 30];

  /// Meditation length choices in minutes.
  static const meditationLengths = [3, 5, 10, 15, 20, 30];


  // ── Defaults ──────────────────────────────────────────────────────────────
  static const _defSound = SoundMode.forest;
  static const _defVolume = 0.72;
  static const _defTarget = 10;
  static const _defTheme = 'forest';
  static const _defLevel = 3;
  static const _defHour = 19;
  static const _defMinute = 0;

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _kSound = 'soundMode';
  static const _kVolume = 'volume';
  static const _kHaptics = 'haptics';
  static const _kShowStreak = 'showStreak';
  static const _kAutoSubmit = 'autoSubmit';
  static const _kTarget = 'sessionTarget';
  static const _kTheme = 'bgTheme';
  static const _kLevel = 'startDifficulty'; // first written by onboarding
  static const _kMedMinutes = 'medMinutes';
  static const _kMedPattern = 'medPattern';
  static const _kMedCues = 'medCues';
  static const _kPracticeMode = 'practiceMode';
  static const _kPracticeTopics = 'practiceTopics';
  static const _kFocusPreset = 'focusPreset';
  static const _kFocusRounds = 'focusRounds';
  static const _kFocusVisual = 'focusVisual';
  static const _kFocusDeep = 'focusDeep';
  static const _kFocusAwake = 'focusAwake';
  static const _kFocusAuto = 'focusAuto';
  static const _kFocusSteps = 'focusSteps';
  static const _kFocusCheckIns = 'focusCheckIns';
  static const _kFocusTask = 'focusTask';
  static const _kUiFollows = 'uiFollowsBackground';
  static const _kUiStyle = 'uiStyle';

  Box get _box => Hive.box('prefs');

  SoundMode _soundMode = _defSound;
  double _volume = _defVolume;
  bool _haptics = true;
  bool _showStreak = true;
  bool _autoSubmit = false;
  int _sessionTarget = _defTarget;
  String _bgTheme = _defTheme;
  int _startLevel = _defLevel;
  bool _remindDaily = false;
  int _remindHour = _defHour;
  int _remindMinute = _defMinute;
  bool _remindStreak = false;
  bool _remindWeekly = false;
  int _medMinutes = 10;
  String _medPattern = 'calm';
  bool _medCues = true;
  PracticeMode _practiceMode = PracticeMode.flow;
  Set<String> _practiceTopics = {};
  String _focusPreset = 'classic';
  int _focusRounds = 4;
  String _focusVisual = 'candle';
  bool _focusDeep = true;
  bool _focusAwake = true;
  bool _focusAuto = false;
  List<String> _focusSteps = [];
  bool _focusCheckIns = true;
  String _focusTask = '';
  bool _uiFollows = true;
  String _uiStyle = _defTheme;

  /// Id of the palette the interface uses right now. The app's theme
  /// listens to this, so buttons and colours change the moment it does.
  final ValueNotifier<String> styleId = ValueNotifier(_defTheme);

  SoundMode get soundMode => _soundMode;
  double get volume => _volume;
  bool get haptics => _haptics;
  bool get showStreak => _showStreak;
  bool get autoSubmit => _autoSubmit;
  int get sessionTarget => _sessionTarget;
  String get bgTheme => _bgTheme;
  int get startLevel => _startLevel;
  bool get remindDaily => _remindDaily;
  int get remindHour => _remindHour;
  int get remindMinute => _remindMinute;
  bool get remindStreak => _remindStreak;
  bool get remindWeekly => _remindWeekly;
  int get medMinutes => _medMinutes;
  String get medPattern => _medPattern;

  /// Gentle vibration at each breath change during meditation.
  bool get medCues => _medCues;

  PracticeMode get practiceMode => _practiceMode;

  /// Chosen math topic ids; empty = all topics.
  Set<String> get practiceTopics => Set.unmodifiable(_practiceTopics);

  PomodoroPreset get focusPreset => presetById(_focusPreset);
  int get focusRounds => _focusRounds;
  String get focusVisual => _focusVisual;

  /// Fade everything but the timer while focusing.
  bool get focusDeep => _focusDeep;

  /// Keep the screen awake during a focus session (desk-timer mode).
  bool get focusAwake => _focusAwake;

  /// Start breaks and next rounds automatically.
  bool get focusAuto => _focusAuto;
  List<String> get focusSteps => List.unmodifiable(_focusSteps);
  bool get focusCheckIns => _focusCheckIns;
  String get focusTask => _focusTask;

  /// True: buttons, colours and shapes follow the background scene.
  bool get uiFollowsBackground => _uiFollows;

  /// The style picked by hand (used when [uiFollowsBackground] is off).
  String get uiStyle => _uiStyle;

  String get activeStyle => _uiFollows ? _bgTheme : _uiStyle;

  void _syncStyle() => styleId.value = activeStyle;

  String get sessionTargetLabel =>
      _sessionTarget == 0 ? 'Unlimited' : '$_sessionTarget min';

  // ── Loading ───────────────────────────────────────────────────────────────
  Future<void> init() async => load();

  /// Reads everything from the (already open) prefs box.
  void load() {
    final b = _box;

    final idx = b.get(_kSound);
    _soundMode = idx is int && idx >= 0 && idx < SoundMode.values.length
        ? SoundMode.values[idx]
        : _defSound;

    final vol = b.get(_kVolume);
    _volume = vol is num ? vol.toDouble().clamp(0.0, 1.0) : _defVolume;

    _haptics = _bool(_kHaptics, true);
    _showStreak = _bool(_kShowStreak, true);
    _autoSubmit = _bool(_kAutoSubmit, false);

    final target = b.get(_kTarget);
    _sessionTarget = target is int && target >= 0 ? target : _defTarget;

    final theme = b.get(_kTheme);
    _bgTheme = theme is String && isKnownBackground(theme) ? theme : _defTheme;

    final lvl = b.get(_kLevel);
    _startLevel = lvl is int ? lvl.clamp(1, 10) : _defLevel;

    _remindDaily = _bool(NotificationService.kDaily, false);
    _remindStreak = _bool(NotificationService.kStreak, false);
    _remindWeekly = _bool(NotificationService.kWeekly, false);
    final hour = b.get(NotificationService.kHour);
    _remindHour = hour is int ? hour.clamp(0, 23) : _defHour;
    final minute = b.get(NotificationService.kMinute);
    _remindMinute = minute is int ? minute.clamp(0, 59) : _defMinute;

    final medMinutes = b.get(_kMedMinutes);
    _medMinutes = medMinutes is int ? medMinutes.clamp(1, 120) : 10;
    final medPattern = b.get(_kMedPattern);
    _medPattern = medPattern is String && isKnownBreathPattern(medPattern)
        ? medPattern
        : 'calm';
    _medCues = _bool(_kMedCues, true);

    final mode = b.get(_kPracticeMode);
    _practiceMode = PracticeMode.byName(mode is String ? mode : null);
    final topics = b.get(_kPracticeTopics);
    final known = kMathTopics.map((t) => t.id).toSet();
    _practiceTopics = topics is List
        ? topics.whereType<String>().where(known.contains).toSet()
        : {};

    final preset = b.get(_kFocusPreset);
    _focusPreset = preset is String ? presetById(preset).id : 'classic';
    final rounds = b.get(_kFocusRounds);
    _focusRounds = rounds is int ? rounds.clamp(1, 12) : focusPreset.defaultRounds;
    final visual = b.get(_kFocusVisual);
    _focusVisual = visual is String ? focusVisualById(visual).id : 'candle';
    _focusDeep = _bool(_kFocusDeep, true);
    _focusAwake = _bool(_kFocusAwake, true);
    _focusAuto = _bool(_kFocusAuto, false);
    _focusCheckIns = _bool(_kFocusCheckIns, true);
    final task = b.get(_kFocusTask);
    _focusTask = task is String ? task : '';
    final steps = b.get(_kFocusSteps);
    _focusSteps = steps is List ? steps.whereType<String>().toList() : [];
    // Older builds kept a single 'tiny first step'.
    final oldStep = b.get('focusStep');
    if (_focusSteps.isEmpty && oldStep is String && oldStep.trim().isNotEmpty) {
      _focusSteps = [oldStep.trim()];
    }

    _uiFollows = _bool(_kUiFollows, true);
    final style = b.get(_kUiStyle);
    _uiStyle = style is String && isKnownBackground(style) ? style : _bgTheme;
    _syncStyle();

    notifyListeners();
  }

  bool _bool(String key, bool fallback) {
    final v = _box.get(key);
    return v is bool ? v : fallback;
  }

  void _save(String key, Object value) {
    _box.put(key, value);
    notifyListeners();
  }

  // ── Sound ─────────────────────────────────────────────────────────────────
  void setSoundMode(SoundMode m) {
    _soundMode = m;
    _save(_kSound, m.index);
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _save(_kVolume, _volume);
  }

  // ── Look & feel ───────────────────────────────────────────────────────────
  void setBgTheme(String t) {
    if (!isKnownBackground(t)) return;
    _bgTheme = t;
    _syncStyle();
    _save(_kTheme, t);
  }

  void setUiFollowsBackground(bool v) {
    _uiFollows = v;
    // Start the hand-picked style from what's on screen, so nothing jumps.
    if (!v) {
      _uiStyle = _bgTheme;
      _box.put(_kUiStyle, _uiStyle);
    }
    _syncStyle();
    _save(_kUiFollows, v);
  }

  void setUiStyle(String id) {
    if (!isKnownBackground(id)) return;
    _uiStyle = id;
    _syncStyle();
    _save(_kUiStyle, id);
  }

  void setHaptics(bool v) {
    _haptics = v;
    _save(_kHaptics, v);
  }

  // ── Session ───────────────────────────────────────────────────────────────
  void setShowStreak(bool v) {
    _showStreak = v;
    _save(_kShowStreak, v);
  }

  void setAutoSubmit(bool v) {
    _autoSubmit = v;
    _save(_kAutoSubmit, v);
  }

  void setSessionTarget(int minutes) {
    _sessionTarget = minutes;
    _save(_kTarget, minutes);
    // The daily reminder text mentions the session length.
    unawaited(NotificationService.sync());
  }

  void setStartLevel(int level) {
    _startLevel = level.clamp(1, 10);
    _save(_kLevel, _startLevel);
  }

  // ── Meditation ────────────────────────────────────────────────────────────
  void setMedMinutes(int minutes) {
    _medMinutes = minutes.clamp(1, 120);
    _save(_kMedMinutes, _medMinutes);
  }

  void setMedPattern(String id) {
    if (!isKnownBreathPattern(id)) return;
    _medPattern = id;
    _save(_kMedPattern, id);
  }

  void setMedCues(bool v) {
    _medCues = v;
    _save(_kMedCues, v);
  }

  // ── Math practice ─────────────────────────────────────────────────────────
  void setPracticeMode(PracticeMode m) {
    _practiceMode = m;
    _save(_kPracticeMode, m.name);
  }

  /// Toggle one topic on/off. Turning off the last one means "all topics".
  void togglePracticeTopic(String id) {
    final next = {..._practiceTopics};
    if (!next.remove(id)) next.add(id);
    // Every topic selected is the same as "all" — keep it simple.
    if (next.length == kMathTopics.length) next.clear();
    _practiceTopics = next;
    _save(_kPracticeTopics, next.toList());
  }

  /// Practise just this one topic (e.g. the weakest one on the skill map).
  void setOnlyTopic(String id) {
    _practiceTopics = {id};
    _save(_kPracticeTopics, [id]);
  }

  void clearPracticeTopics() {
    _practiceTopics = {};
    _save(_kPracticeTopics, <String>[]);
  }

  // ── Focus ─────────────────────────────────────────────────────────────────
  /// Choosing a preset also picks its usual number of rounds.
  void setFocusPreset(String id) {
    final p = presetById(id);
    _focusPreset = p.id;
    _focusRounds = p.defaultRounds;
    _box.put(_kFocusRounds, _focusRounds);
    _save(_kFocusPreset, p.id);
  }

  void setFocusRounds(int n) {
    _focusRounds = n.clamp(1, 12);
    _save(_kFocusRounds, _focusRounds);
  }

  void setFocusVisual(String id) {
    _focusVisual = focusVisualById(id).id;
    _save(_kFocusVisual, _focusVisual);
  }

  void setFocusDeep(bool v) {
    _focusDeep = v;
    _save(_kFocusDeep, v);
  }

  void setFocusAwake(bool v) {
    _focusAwake = v;
    _save(_kFocusAwake, v);
  }

  void setFocusAuto(bool v) {
    _focusAuto = v;
    _save(_kFocusAuto, v);
  }

  void setFocusCheckIns(bool v) {
    _focusCheckIns = v;
    _save(_kFocusCheckIns, v);
  }

  /// Remembers the task so it's still there next time (no notify — typing).
  void setFocusPlan(String task, List<String> steps) {
    _focusTask = task;
    _focusSteps = [...steps];
    _box.put(_kFocusTask, task);
    _box.put(_kFocusSteps, _focusSteps);
  }

  // ── Reminders ─────────────────────────────────────────────────────────────
  Future<void> setRemindDaily(bool v) async {
    _remindDaily = v;
    await _box.put(NotificationService.kDaily, v);
    notifyListeners();
    await NotificationService.sync();
  }

  Future<void> setRemindTime(int hour, int minute) async {
    _remindHour = hour;
    _remindMinute = minute;
    await _box.put(NotificationService.kHour, hour);
    await _box.put(NotificationService.kMinute, minute);
    notifyListeners();
    await NotificationService.sync();
  }

  Future<void> setRemindStreak(bool v) async {
    _remindStreak = v;
    await _box.put(NotificationService.kStreak, v);
    notifyListeners();
    await NotificationService.sync();
  }

  Future<void> setRemindWeekly(bool v) async {
    _remindWeekly = v;
    await _box.put(NotificationService.kWeekly, v);
    notifyListeners();
    await NotificationService.sync();
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  /// Restores sound, background, session and feel defaults.
  /// Reminder choices and session history are left alone.
  Future<void> resetToDefaults() async {
    await _box.deleteAll(const [
      _kSound,
      _kVolume,
      _kHaptics,
      _kShowStreak,
      _kAutoSubmit,
      _kTarget,
      _kTheme,
      _kLevel,
      _kMedMinutes,
      _kMedPattern,
      _kMedCues,
      _kPracticeMode,
      _kPracticeTopics,
      _kFocusPreset,
      _kFocusRounds,
      _kFocusVisual,
      _kFocusDeep,
      _kFocusAwake,
      _kFocusAuto,
      _kFocusCheckIns,
      _kUiFollows,
      _kUiStyle,
      'autoStart', // legacy key from an older build
    ]);
    load();
    await NotificationService.sync();
  }
}
