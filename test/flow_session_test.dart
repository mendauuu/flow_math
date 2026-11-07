import 'dart:io';

import 'package:flow_math/models/practice.dart';
import 'package:flow_math/models/session_stats.dart';
import 'package:flow_math/screens/flow_screen.dart';
import 'package:flow_math/services/audio_service.dart';
import 'package:flow_math/services/focus_store.dart';
import 'package:flow_math/services/meditation_log.dart';
import 'package:flow_math/services/session_service.dart';
import 'package:flow_math/services/settings_service.dart';
import 'package:flow_math/theme/palette.dart';
import 'package:flow_math/widgets/numpad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Plays a real Flow State session by tapping the number pad: mistakes show
/// the weak-spot tag, fast answers fill the flow meter until "IN FLOW", and
/// the results show the XP card — on a small and a large phone.
void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('flow_math_session');
    Hive.init(dir.path);
    Hive.registerAdapter(SessionStatsAdapter());
    await Hive.openBox<SessionStats>('sessions');
    await Hive.openBox('prefs');
    await Hive.openBox(MeditationLog.boxName);
    await Hive.openBox(FocusLog.boxName);
    await Hive.openBox(ThoughtStore.boxName);
    appSettings.load();
  });

  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    for (final style in const ['storm', 'sakura']) {
      testWidgets('flow session · $style · ${size.width.toInt()}w',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final audio = AudioService();
        final svc = SessionService()
          ..startSession(SessionMode.focus,
              startLevel: 4, allowed: opsForTopics(['percent']));

        Future<void> settle([int ms = 1000]) async {
          await tester.pump();
          await tester.pump(Duration(milliseconds: ms));
          expect(tester.takeException(), isNull);
        }

        Future<void> answer(int value) async {
          for (final d in '$value'.split('')) {
            await tester.tap(find.descendant(
                of: find.byType(NumpadWidget), matching: find.text(d)));
            await tester.pump();
          }
          await tester.tap(find.descendant(
              of: find.byType(NumpadWidget), matching: find.text('✓')));
          await tester.pump(const Duration(milliseconds: 100));
        }

        await tester.pumpWidget(MaterialApp(
          theme: themeFor(style),
          home: FlowScreen(service: svc, settings: appSettings, audio: audio),
        ));
        await settle();
        expect(find.text('FLOW'), findsOneWidget);
        expect(find.text('END'), findsOneWidget);

        // Two mistakes on the same kind of problem → the weak-spot tag.
        for (var i = 0; i < 2; i++) {
          await answer(svc.currentProblem!.correctAnswer + 1);
          await settle(2400);
        }
        expect(find.textContaining('🎯'), findsOneWidget);

        // Fast correct answers fill the meter until "IN FLOW".
        var guard = 0;
        while (!svc.inFlow && guard++ < 12) {
          await answer(svc.currentProblem!.correctAnswer);
          expect(find.textContaining('XP'), findsWidgets); // "+18 XP" pops up
          await settle();
        }
        expect(svc.inFlow, isTrue);
        expect(find.textContaining('IN FLOW'), findsOneWidget);
        expect(svc.xp, greaterThan(0));

        // End → results with the XP card
        await tester.tap(find.text('END'));
        await settle(800);
        // On small phones these sit below the fold — scroll like a user.
        await tester.scrollUntilVisible(find.textContaining('In flow'), 200,
            scrollable: find.byType(Scrollable).first);
        await settle(300);
        expect(find.textContaining('LEVEL'), findsOneWidget);
        expect(find.text('+${svc.xp}'), findsOneWidget);
        expect(find.textContaining('In flow'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        svc.dispose();
        audio.dispose();
      });
    }
  }
}
