import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../utils/app_theme.dart';

class FeedbackOverlay extends StatefulWidget {
  final String message;
  final bool isCorrect;
  final RewardEvent reward;

  const FeedbackOverlay({
    super.key,
    required this.message,
    required this.isCorrect,
    required this.reward,
  });

  @override
  State<FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<FeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCorrect) return _correctFeedback();
    return _wrongFeedback();
  }

  // ── Correct — reward-driven display ───────────────────────────────────────
  Widget _correctFeedback() {
    final r = widget.reward;

    // Plain correct — silent green flash, no text
    if (r == RewardEvent.correct || r == RewardEvent.none) {
      return FadeTransition(
        opacity: _fade,
        child: Container(
          height: 44,
          width: double.infinity,
          color: AppColors.correct.withOpacity(0.06),
        ),
      );
    }

    // Big reward moment
    final cfg = _rewardConfig(r);
    return FadeTransition(
      opacity: _fade,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cfg.color.withOpacity(0.0),
              cfg.color.withOpacity(0.12),
              cfg.color.withOpacity(0.0)
            ],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cfg.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(cfg.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cfg.color,
                      letterSpacing: 2.5,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Wrong — explanation + hint ─────────────────────────────────────────────
  Widget _wrongFeedback() {
    final lines = widget.message.split('\n');
    return FadeTransition(
      opacity: _fade,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        color: AppColors.incorrect.withOpacity(0.05),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                size: 14, color: AppColors.incorrect),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lines[0],
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMid, height: 1.4)),
                  if (lines.length > 1) ...[
                    const SizedBox(height: 3),
                    Text(lines[1],
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary.withOpacity(0.7),
                          height: 1.4,
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reward configs ─────────────────────────────────────────────────────────
  _RewardCfg _rewardConfig(RewardEvent r) => switch (r) {
        RewardEvent.streakThree => _RewardCfg('💫', 'NICE', AppColors.primary),
        RewardEvent.streakFive => _RewardCfg('✨', 'FLOWING', AppColors.primary),
        RewardEvent.streakTen => _RewardCfg('⚡', 'ON FIRE', AppColors.gold),
        RewardEvent.streakTwenty =>
          _RewardCfg('🔥', 'UNSTOPPABLE', const Color(0xFFFF7043)),
        RewardEvent.personalBest =>
          _RewardCfg('🏆', 'PERSONAL BEST', AppColors.gold),
        RewardEvent.speedBonus =>
          _RewardCfg('⚡', 'LIGHTNING', const Color(0xFFB3E5FC)),
        RewardEvent.levelUp => _RewardCfg('↑', 'LEVEL UP', AppColors.primary),
        _ => _RewardCfg('', '', AppColors.primary),
      };
}

class _RewardCfg {
  final String emoji, label;
  final Color color;
  const _RewardCfg(this.emoji, this.label, this.color);
}
