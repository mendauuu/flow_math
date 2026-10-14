import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Each mode maps to one of YOUR renamed MP3 files in assets/audio/
enum SoundMode {
  off, // silent
  rain, // rain.mp3     — Rain on forest ground (your best rain file)
  thunder, // thunder.mp3  — Distant rolling thunder, no rain
  wind, // wind.mp3     — Wind through leaves / light rain through window
  forest, // forest.mp3   — Morning birch forest, willow warbler, insects
  birds, // birds.mp3    — Great tit, chaffinch, Jay, calm spring forest
  river, // river.mp3    — Moderately flowing river
  stream, // stream.mp3   — Small river / stream close take
}

class AudioService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  SoundMode _mode = SoundMode.off;

  SoundMode get mode => _mode;
  bool get playing => _mode != SoundMode.off;

  /// Short display label shown in the sound pill + settings chips
  String get modeLabel => switch (_mode) {
        SoundMode.off => 'SILENT',
        SoundMode.rain => 'RAIN',
        SoundMode.thunder => 'THUNDER',
        SoundMode.wind => 'WIND',
        SoundMode.forest => 'FOREST',
        SoundMode.birds => 'BIRDS',
        SoundMode.river => 'RIVER',
        SoundMode.stream => 'STREAM',
      };

  String get modeEmoji => switch (_mode) {
        SoundMode.off => '🔇',
        SoundMode.rain => '🌧',
        SoundMode.thunder => '⛈',
        SoundMode.wind => '🌬',
        SoundMode.forest => '🌲',
        SoundMode.birds => '🐦',
        SoundMode.river => '🏞',
        SoundMode.stream => '💧',
      };

  /// The actual filename in assets/audio/ for each mode
  static String _file(SoundMode m) => switch (m) {
        SoundMode.rain => 'audio/rain.mp3',
        SoundMode.thunder => 'audio/thunder.mp3',
        SoundMode.wind => 'audio/wind.mp3',
        SoundMode.forest => 'audio/forest.mp3',
        SoundMode.birds => 'audio/birds.mp3',
        SoundMode.river => 'audio/river.mp3',
        SoundMode.stream => 'audio/stream.mp3',
        SoundMode.off => '',
      };

  AudioService() {
    _player.setReleaseMode(ReleaseMode.loop);
    _player.setVolume(0.72);
  }

  Future<void> setMode(SoundMode m) async {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    await _player.stop();
    if (m == SoundMode.off) return;
    await _player.play(AssetSource(_file(m)));
  }

  Future<void> setVolume(double v) async {
    await _player.setVolume(v.clamp(0.0, 1.0));
  }

  void cycleMode() {
    final modes = SoundMode.values;
    setMode(modes[(_mode.index + 1) % modes.length]);
  }

  Future<void> stop() => _player.stop();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
