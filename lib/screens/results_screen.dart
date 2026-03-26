import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

class ResultsScreen extends StatelessWidget {
  final SessionService service;
  const ResultsScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final mins = service.sessionSeconds ~/ 60;
    final secs = service.sessionSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final focus = service.focusScore.toStringAsFixed(0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.forestGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                const Text(
                  'SESSION\nCOMPLETE',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w200,
                    color: AppColors.textBright,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Focus Score — big centrepiece
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'FOCUS SCORE',
                        style: AppTextStyles.labelText,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        focus,
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w100,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
                      const Text(
                        '/ 100',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildGrid([
                  ('TIME', timeStr),
                  ('PROBLEMS', '${service.totalProblems}'),
                  ('ACCURACY', '${service.accuracy.toStringAsFixed(0)}%'),
                  ('MAX STREAK', '${service.maxStreak}'),
                ]),

                const Spacer(),
                _buildButton(
                  context,
                  label: 'FLOW AGAIN',
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (r) => false,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<(String, String)> items) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.$1, style: AppTextStyles.labelText),
              const SizedBox(height: 4),
              Text(
                item.$2,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textBright,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
