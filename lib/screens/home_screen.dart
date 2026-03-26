import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../utils/app_theme.dart';
import 'flow_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                _buildHeader(),
                const Spacer(),
                _buildModeButton(
                  context,
                  label: 'FLOW STATE',
                  subtitle: 'Pure focus mode',
                  icon: Icons.water_drop_outlined,
                  mode: SessionMode.focus,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3A2E), Color(0xFF0D2018)],
                  ),
                  accentColor: AppColors.primary,
                ),
                const SizedBox(height: 16),
                _buildModeButton(
                  context,
                  label: 'ANTI-SCROLL',
                  subtitle: 'Replace distraction with focus',
                  icon: Icons.psychology_outlined,
                  mode: SessionMode.antiScroll,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A2A1A), Color(0xFF1A1A0D)],
                  ),
                  accentColor: AppColors.gold,
                ),
                const SizedBox(height: 32),
                _buildStatsButton(context),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FLOW MATH',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Quiet\nyour mind.',
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w200,
            color: AppColors.textBright,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Replace scrolling with thinking.\nEnter the flow.',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textDim,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required String label,
    required String subtitle,
    required IconData icon,
    required SessionMode mode,
    required LinearGradient gradient,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: () => _startSession(context, mode),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: accentColor.withOpacity(0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StatsScreen()),
      ),
      child: Row(
        children: const [
          Icon(Icons.bar_chart, color: AppColors.textDim, size: 16),
          SizedBox(width: 8),
          Text(
            'VIEW STATS',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textDim,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _startSession(BuildContext context, SessionMode mode) {
    final service = SessionService();
    service.startSession(mode);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FlowScreen(service: service),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }
}
