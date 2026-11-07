import 'dart:io';

import 'package:flow_math/models/session_stats.dart';
import 'package:flow_math/screens/home_screen.dart';
import 'package:flow_math/screens/onboarding_screen.dart';
import 'package:flow_math/services/focus_store.dart';
import 'package:flow_math/services/meditation_log.dart';
import 'package:flow_math/services/settings_service.dart';
import 'package:flow_math/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// First launch: pick a level and a session length, skip reminders,
/// land on Home — with the choices applied straight away.
void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('flow_math_onboarding');
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
    for (final style in const ['forest', 'lanterns']) {
      testWidgets('onboarding · $style · ${size.width.toInt()}w',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        Future<void> settle([int ms = 600]) async {
          await tester.pump();
          await tester.pump(Duration(milliseconds: ms));
          expect(tester.takeException(), isNull);
        }

        await tester.pumpWidget(MaterialApp(
          theme: themeFor(style),
          home: const OnboardingScreen(),
        ));
        await settle();

        // No age question: we ask about math level instead.
        expect(find.textContaining('Ages'), findsNothing);
        expect(find.text('Comfortable'), findsOneWidget);

        // Can't continue before choosing a level.
        await tester.tap(find.text('CONTINUE'));
        await settle();
        expect(find.text('Comfortable'), findsOneWidget);

        await tester.ensureVisible(find.text('Sharp'));
        await settle(100);
        await tester.tap(find.text('Sharp'));
        await settle(300);
        await tester.tap(find.text('CONTINUE'));
        await settle();

        await tester.ensureVisible(find.text('15 minutes'));
        await settle(100);
        await tester.tap(find.text('15 minutes'));
        await settle(300);
        await tester.tap(find.text('CONTINUE'));
        await settle();

        expect(find.text('TURN ON REMINDERS'), findsOneWidget);
        await tester.tap(find.text('Not now'));
        await settle(1200);

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(appSettings.startLevel, 5);
        expect(appSettings.sessionTarget, 15);
        expect(appSettings.remindDaily, isFalse);
        expect(Hive.box('prefs').get('onboardingDone'), isTrue);

        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
