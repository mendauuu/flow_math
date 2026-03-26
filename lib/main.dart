import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/session_stats.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full immersive mode — hide status & nav bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Hive.initFlutter();
  Hive.registerAdapter(SessionStatsAdapter());
  await Hive.openBox<SessionStats>('sessions');
  await Hive.openBox('prefs');

  runApp(const FlowMathApp());
}

class FlowMathApp extends StatelessWidget {
  const FlowMathApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const HomeScreen(),
    );
  }
}
