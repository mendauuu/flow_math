import 'dart:io';

import 'package:flow_math/models/session_stats.dart';
import 'package:flow_math/screens/focus_screen.dart';
import 'package:flow_math/services/audio_service.dart';
import 'package:flow_math/services/focus_store.dart';
import 'package:flow_math/services/meditation_log.dart';
import 'package:flow_math/services/settings_service.dart';
import 'package:flow_math/theme/palette.dart';
import 'package:flow_math/widgets/cozy_painters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Walks through a Pomodoro session on screen — setup → focus → break →
/// summary — for every timer style, in a round and a square theme, on a
/// small and a large phone.
void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('flow_math_focus');
    Hive.init(dir.path);
    Hive.registerAdapter(SessionStatsAdapter());
    await Hive.openBox<SessionStats>('sessions');
    await Hive.openBox('prefs');
    await Hive.openBox(MeditationLog.boxName);
    await Hive.openBox(FocusLog.boxName);
    await Hive.openBox(ThoughtStore.boxName);
    appSettings.load();
    appSettings
      ..setFocusPreset('quick')
      ..setFocusRounds(3)
      ..setFocusCheckIns(false)
      ..setFocusPlan('Math homework — chapter 4', ['Do Q1–Q3', 'Check answers']);
  });

  // Settings saved during the simulated-time tests never finish writing, so
  // don't wait on them forever when closing.
  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('rotating mid-session never overflows; idle hides the controls',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(915, 412) * 3;
    addTearDown(tester.view.reset);
    appSettings
      ..setFocusVisual('campfire')
      ..setFocusDeep(true);
    final audio = AudioService();

    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(MaterialApp(
      theme: themeFor('forest'),
      home: FocusScreen(settings: appSettings, audio: audio),
    ));
    await settle();
    await tester.tap(find.text('START FOCUS'));
    await settle();

    // Turn the phone around while the round runs.
    for (final size in const [Size(412, 915), Size(915, 412), Size(360, 640)]) {
      tester.view.physicalSize = size * 3;
      await settle();
    }
    expect(find.text('Wrap up'), findsOneWidget);

    // Leave it alone: the buttons fold away, only the timer stays.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4600)));
    await settle();
    expect(find.text('Wrap up'), findsNothing);
    expect(find.text('Park a thought'), findsNothing);

    // One tap brings them back.
    await tester.tapAt(tester.getCenter(find.byType(FocusScreen)));
    await settle();
    expect(find.text('Wrap up'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    audio.dispose();
  });

  // Upright and sideways phones (sideways = flip-clock desk view).
  for (final size in const [
    Size(360, 640),
    Size(412, 915),
    Size(640, 360),
    Size(915, 412),
  ]) {
    for (final style in const ['snow', 'storm']) {
      for (final visual in kFocusVisuals) {
        testWidgets(
            'focus flow · ${visual.id} · $style · '
            '${size.width.toInt()}×${size.height.toInt()}',
            (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          appSettings.setFocusVisual(visual.id);
          final audio = AudioService();

          // One frame to start any new animation, then let it run.
          Future<void> settle() async {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 700));
            expect(tester.takeException(), isNull);
          }

          await tester.pumpWidget(MaterialApp(
            theme: themeFor(style),
            home: FocusScreen(settings: appSettings, audio: audio),
          ));
          await settle();

          // Setup → focus
          await tester.tap(find.text('START FOCUS'));
          await settle();
          expect(find.text('FOCUS · ROUND 1 OF 3'), findsOneWidget);
          expect(find.textContaining('Now: Do Q1–Q3'), findsOneWidget);

          // Tick off the current step
          await tester.tap(find.textContaining('Now: Do Q1–Q3'));
          await settle();
          expect(find.textContaining('Now: Check answers'), findsOneWidget);

          // Focus → break (end the round early)
          await tester.tap(find.text('Wrap up'));
          await settle();
          await tester.tap(find.text('End this round early'));
          await settle();
          expect(find.text('SKIP BREAK'), findsOneWidget);

          // Break → summary
          await tester.tap(find.text('WRAP UP'));
          await settle();
          await tester.tap(find.text('Stop for now'));
          await settle();
          expect(find.text('NEW SESSION'), findsOneWidget);

          // Summary → a fresh setup, keeping the unfinished step
          await tester.tap(find.text('NEW SESSION'));
          await settle();
          expect(find.text('START FOCUS'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          audio.dispose();
        });
      }
    }
  }
}
