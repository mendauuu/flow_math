import 'dart:io';

import 'package:flow_math/models/practice.dart';
import 'package:flow_math/models/session_stats.dart';
import 'package:flow_math/services/math_progress.dart';
import 'package:flow_math/screens/analyze_screen.dart';
import 'package:flow_math/screens/focus_screen.dart';
import 'package:flow_math/screens/home_screen.dart';
import 'package:flow_math/screens/meditation_screen.dart';
import 'package:flow_math/screens/practice_screen.dart';
import 'package:flow_math/screens/settings_screen.dart';
import 'package:flow_math/screens/stats_screen.dart';
import 'package:flow_math/screens/thoughts_screen.dart';
import 'package:flow_math/services/audio_service.dart';
import 'package:flow_math/services/focus_store.dart';
import 'package:flow_math/services/meditation_log.dart';
import 'package:flow_math/services/settings_service.dart';
import 'package:flow_math/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Renders every screen in every interface style on a small and a large
/// phone, and fails on any layout or build error.
void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('flow_math_test');
    Hive.init(dir.path);
    Hive.registerAdapter(SessionStatsAdapter());
    await Hive.openBox<SessionStats>('sessions');
    await Hive.openBox('prefs');
    await Hive.openBox(MeditationLog.boxName);
    await Hive.openBox(FocusLog.boxName);
    await Hive.openBox(ThoughtStore.boxName);
    await Hive.box('prefs').put('soundMode', SoundMode.off.index);
    // Some history, so the skill map and Mind level have something to draw.
    await MathProgress.addSession(xp: 900, ops: {
      'add': OpTally()
        ..add(right: true, ms: 2500)
        ..add(right: true, ms: 3000)
        ..add(right: false, ms: 6000),
      'multiply': OpTally()..add(right: true, ms: 4000),
      'percentOf': OpTally()..add(right: false, ms: 9000),
    });
    appSettings.load();
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  final screens = <String, Widget Function(AudioService)>{
    'home': (_) => const HomeScreen(),
    'practice': (a) => PracticeScreen(settings: appSettings, audio: a),
    'focus': (a) => FocusScreen(settings: appSettings, audio: a),
    'meditation': (a) => MeditationScreen(settings: appSettings, audio: a),
    'settings': (a) => SettingsScreen(settings: appSettings, audio: a),
    'thoughts': (_) => ThoughtsScreen(settings: appSettings),
    'history': (_) => StatsScreen(settings: appSettings),
    'analytics': (_) => const AnalyzeScreen(),
  };

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    for (final style in kPalettes.keys) {
      testWidgets('all screens render · $style · ${size.width.toInt()}w',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        for (final entry in screens.entries) {
          final audio = AudioService();
          await tester.pumpWidget(MaterialApp(
            theme: themeFor(style),
            home: entry.value(audio),
          ));
          await tester.pump(const Duration(milliseconds: 700));
          expect(tester.takeException(), isNull,
              reason: '${entry.key} in $style');
          await tester.pumpWidget(const SizedBox());
          audio.dispose();
        }
      });
    }
  }
}
