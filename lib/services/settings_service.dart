import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'audio_service.dart';

class SettingsService extends ChangeNotifier {
  late Box _box;

  SoundMode _soundMode = SoundMode.forest;
  double _volume = 0.72;
  bool _haptics = true;
  bool _showStreak = true;
  bool _autoStart = true;
  int _sessionTarget = 10;
  String _bgTheme = 'forest';

  SoundMode get soundMode => _soundMode;
  double get volume => _volume;
  bool get haptics => _haptics;
  bool get showStreak => _showStreak;
  bool get autoStart => _autoStart;
  int get sessionTarget => _sessionTarget;
  String get bgTheme => _bgTheme;

  Future<void> init() async {
    _box = Hive.box('prefs');
    final idx =
        _box.get('soundMode', defaultValue: SoundMode.forest.index) as int;
    _soundMode = SoundMode.values[idx.clamp(0, SoundMode.values.length - 1)];
    _volume = (_box.get('volume', defaultValue: 0.72) as num).toDouble();
    _haptics = _box.get('haptics', defaultValue: true) as bool;
    _showStreak = _box.get('showStreak', defaultValue: true) as bool;
    _autoStart = _box.get('autoStart', defaultValue: true) as bool;
    _sessionTarget = _box.get('sessionTarget', defaultValue: 10) as int;
    _bgTheme = _box.get('bgTheme', defaultValue: 'forest') as String;
    notifyListeners();
  }

  void setSoundMode(SoundMode m) {
    _soundMode = m;
    _box.put('soundMode', m.index);
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v;
    _box.put('volume', v);
    notifyListeners();
  }

  void setHaptics(bool v) {
    _haptics = v;
    _box.put('haptics', v);
    notifyListeners();
  }

  void setShowStreak(bool v) {
    _showStreak = v;
    _box.put('showStreak', v);
    notifyListeners();
  }

  void setAutoStart(bool v) {
    _autoStart = v;
    _box.put('autoStart', v);
    notifyListeners();
  }

  void setSessionTarget(int m) {
    _sessionTarget = m;
    _box.put('sessionTarget', m);
    notifyListeners();
  }

  void setBgTheme(String t) {
    _bgTheme = t;
    _box.put('bgTheme', t);
    notifyListeners();
  }

  String get sessionTargetLabel =>
      _sessionTarget == 0 ? 'Unlimited' : '$_sessionTarget min';
}
