import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/session_stats.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

// ── Global singletons shared across the app ───────────────────────────────────
final purchaseService = PurchaseService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SessionStatsAdapter());
  await Hive.openBox<SessionStats>('sessions');
  await Hive.openBox('prefs');

  // Notifications
  await NotificationService.init();

  // RevenueCat (non-blocking — don't await, let UI load first)
  purchaseService.init();

  runApp(const FlowMathApp());
}

class FlowMathApp extends StatelessWidget {
  const FlowMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('prefs');
    final done = box.get('onboardingDone', defaultValue: false) as bool;

    return MaterialApp(
      title: 'Flow Math',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF0A0F1A),
          primary: const Color(0xFF7EB8A4),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0F1A),
      ),
      // Route: onboarding on first launch, home after
      home: done ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
