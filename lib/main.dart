import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/session_stats.dart';
import 'services/app_icon_service.dart';
import 'services/focus_store.dart';
import 'services/meditation_log.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/palette.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SessionStatsAdapter());
  await Hive.openBox<SessionStats>('sessions');
  await Hive.openBox('prefs');
  await Hive.openBox(MeditationLog.boxName);
  await Hive.openBox(FocusLog.boxName);
  await Hive.openBox(ThoughtStore.boxName);

  appSettings.load();

  // Notifications — re-apply the reminder choices from Settings on every
  // launch so schedules stay correct (non-blocking, let the UI load first).
  await NotificationService.init();
  unawaited(NotificationService.sync());
  unawaited(AppIconService.sync());

  final onboarded =
      Hive.box('prefs').get('onboardingDone', defaultValue: false) == true;
  runApp(FlowMathApp(onboarded: onboarded));
}

class FlowMathApp extends StatelessWidget {
  final bool onboarded;
  const FlowMathApp({super.key, required this.onboarded});

  @override
  Widget build(BuildContext context) {
    // The interface style (buttons, colours, shapes) — cross-fades whenever
    // the background or the chosen style changes.
    return ValueListenableBuilder<String>(
      valueListenable: appSettings.styleId,
      builder: (_, style, __) => MaterialApp(
        title: 'Flow Math',
        debugShowCheckedModeBanner: false,
        theme: themeFor(style),
        themeAnimationDuration: const Duration(milliseconds: 600),
        themeAnimationCurve: Curves.easeInOut,
        // Route: onboarding on first launch, home after
        home: onboarded ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}
