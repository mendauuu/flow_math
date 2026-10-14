import 'package:flow_math/models/session_stats.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import '../main.dart' show purchaseService;
import 'home_screen.dart';
import 'paywall_screen.dart';

class ResultsScreen extends StatefulWidget {
  final SessionService service;
  final SettingsService settings;
  const ResultsScreen(
      {super.key, required this.service, required this.settings});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    _postSessionActions();
  }

  Future<void> _postSessionActions() async {
    // Reschedule streak saver every session
    await NotificationService.scheduleStreakSaver(widget.service.maxStreak);

    // Paywall trigger: show after 5th session
    if (SessionService.shouldShowPaywall()) {
      await SessionService.markPaywallShown();
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              PaywallScreen(purchases: purchaseService, dismissible: true),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      if (result == true) await SessionService.markPro();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mins = widget.service.sessionSeconds ~/ 60;
    final secs = widget.service.sessionSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final focus = widget.service.focusScore.toStringAsFixed(0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.forestGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 44),
                const Text('SESSION\nCOMPLETE',
                    style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w200,
                        color: AppColors.textBright,
                        height: 1.1,
                        letterSpacing: -0.5)),
                const SizedBox(height: 32),

                // Focus Score
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('FOCUS SCORE', style: AppTextStyles.labelText),
                    const SizedBox(height: 6),
                    Text(focus,
                        style: const TextStyle(
                            fontSize: 76,
                            fontWeight: FontWeight.w100,
                            color: AppColors.primary,
                            height: 1)),
                    const SizedBox(height: 2),
                    const Text('/ 100',
                        style:
                            TextStyle(fontSize: 16, color: AppColors.textDim)),
                  ]),
                ),
                const SizedBox(height: 20),

                _statRow([
                  ('TIME', timeStr),
                  ('PROBLEMS', '${widget.service.totalProblems}')
                ]),
                const SizedBox(height: 12),
                _statRow([
                  (
                    'ACCURACY',
                    '${widget.service.accuracy.toStringAsFixed(0)}%'
                  ),
                  ('MAX STREAK', '${widget.service.maxStreak}'),
                ]),

                const Spacer(),

                // Upgrade nudge (if not pro, after session 3+)
                if (!purchaseService.isPro && _sessionCount() >= 3)
                  _upgradeBanner(context),

                const SizedBox(height: 14),
                _button(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _sessionCount() {
    try {
      return Hive.box<SessionStats>('sessions').length;
    } catch (_) {
      return 0;
    }
  }

  Widget _upgradeBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) =>
                PaywallScreen(purchases: purchaseService, dismissible: true),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          )),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withOpacity(0.20)),
        ),
        child: Row(children: const [
          Text('🏆', style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Expanded(
              child: Text('Unlock full analytics, streak calendar + all sounds',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.gold, height: 1.4))),
          Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.gold),
        ]),
      ),
    );
  }

  Widget _statRow(List<(String, String)> pair) => Row(
        children: [
          Expanded(child: _tile(pair[0].$1, pair[0].$2)),
          const SizedBox(width: 12),
          Expanded(child: _tile(pair[1].$1, pair[1].$2)),
        ],
      );

  Widget _tile(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTextStyles.labelText),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textBright,
                    height: 1)),
          ],
        ),
      );

  Widget _button(BuildContext context) => GestureDetector(
        onTap: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: const Center(
              child: Text('FLOW AGAIN',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 3))),
        ),
      );
}
