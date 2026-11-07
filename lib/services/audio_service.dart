import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Each mode maps to one of the MP3 files in assets/audio/.
/// The index of each value is saved in prefs — only ever ADD new modes at the
/// end so existing saved choices keep pointing at the same sound.
enum SoundMode {
  off, // silent
  rain, // rain.mp3     — Rain on forest ground
  thunder, // thunder.mp3  — Distant rolling thunder, no rain
  wind, // wind.mp3     — Wind through leaves / light rain through window
  forest, // forest.mp3   — Morning birch forest, willow warbler, insects
  birds, // birds.mp3    — Great tit, chaffinch, Jay, calm spring forest
  river, // river.mp3    — Moderately flowing river
  stream, // stream.mp3   — Small river / stream close take
  creek, // creek.mp3    — Gentle creek trickling over stones
}

class AudioService extends ChangeNotifier {
  // The player is created the first time a sound actually plays, so Silent
  // mode never starts a native player.
  AudioPlayer? _p;
  double _volume = 0.72;
  AudioPlayer get _player => _p ??= AudioPlayer()
    ..setReleaseMode(ReleaseMode.loop)
    ..setVolume(_volume);

  SoundMode _mode = SoundMode.off;

  /// True while the player is actually running [_mode]. After [stop] this is
  /// false, so calling [setMode] with the same mode starts it again.
  bool _active = false;

  SoundMode get mode => _mode;
  bool get playing => _mode != SoundMode.off;

  /// Display name used in Settings chips.
  static String nameOf(SoundMode m) => switch (m) {
        SoundMode.off => 'Silent',
        SoundMode.rain => 'Rain',
        SoundMode.thunder => 'Thunder',
        SoundMode.wind => 'Wind',
        SoundMode.forest => 'Forest',
        SoundMode.birds => 'Birds',
        SoundMode.river => 'River',
        SoundMode.stream => 'Stream',
        SoundMode.creek => 'Creek',
      };

  static String emojiOf(SoundMode m) => switch (m) {
        SoundMode.off => '🔇',
        SoundMode.rain => '🌧',
        SoundMode.thunder => '⛈',
        SoundMode.wind => '🌬',
        SoundMode.forest => '🌲',
        SoundMode.birds => '🐦',
        SoundMode.river => '🏞',
        SoundMode.stream => '💧',
        SoundMode.creek => '🌿',
      };

  /// Short label shown in the in-session sound pill.
  String get modeLabel => nameOf(_mode).toUpperCase();
  String get modeEmoji => emojiOf(_mode);

  /// The actual filename in assets/audio/ for each mode
  static String _file(SoundMode m) => switch (m) {
        SoundMode.rain => 'audio/rain.mp3',
        SoundMode.thunder => 'audio/thunder.mp3',
        SoundMode.wind => 'audio/wind.mp3',
        SoundMode.forest => 'audio/forest.mp3',
        SoundMode.birds => 'audio/birds.mp3',
        SoundMode.river => 'audio/river.mp3',
        SoundMode.stream => 'audio/stream.mp3',
        SoundMode.creek => 'audio/creek.mp3',
        SoundMode.off => '',
      };

  Future<void> setMode(SoundMode m) async {
    if (m == _mode && (_active || m == SoundMode.off)) return;
    _mode = m;
    notifyListeners();
    _active = false;
    await _p?.stop();
    if (m == SoundMode.off) return;
    _active = true;
    await _player.play(AssetSource(_file(m)));
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _p?.setVolume(_volume);
  }

  void cycleMode() {
    final modes = SoundMode.values;
    setMode(modes[(_mode.index + 1) % modes.length]);
  }

  Future<void> stop() async {
    _active = false;
    await _p?.stop();
  }

  @override
  void dispose() {
    _p?.dispose();
    super.dispose();
  }
}
