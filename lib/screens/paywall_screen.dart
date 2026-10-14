import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/purchase_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PaywallScreen
//  Shows after session 5 (or when user taps locked Pro feature).
//  Two options: Monthly $4.99 / Lifetime $49
//  7-day free trial on monthly.
// ─────────────────────────────────────────────────────────────────────────────
class PaywallScreen extends StatefulWidget {
  final PurchaseService purchases;

  /// If true, show a "No thanks" dismiss button.
  final bool dismissible;

  const PaywallScreen({
    super.key,
    required this.purchases,
    this.dismissible = true,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;
  bool _selectedMonthly = true; // which plan is highlighted

  @override
  void initState() {
    super.initState();
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 14))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  PurchaseService get _p => widget.purchases;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _PaywallBgPainter(_bgCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.50)),
          SafeArea(
            child: ListenableBuilder(
              listenable: _p,
              builder: (_, __) => Column(
                children: [
                  _topBar(context),
                  Expanded(child: _body()),
                  _footer(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          if (widget.dismissible)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.close, color: AppColors.textDim, size: 16),
              ),
            )
          else
            const SizedBox(width: 34),
          const Spacer(),
          // Restore button
          GestureDetector(
            onTap: () async {
              final ok = await _p.restore();
              if (!mounted) return;
              if (ok) {
                Navigator.pop(context, true);
              } else {
                _showError('Nothing to restore.');
              }
            },
            child: const Text('Restore',
                style: TextStyle(fontSize: 12, color: AppColors.textDim)),
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Crown icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withOpacity(0.12),
              border: Border.all(color: AppColors.gold.withOpacity(0.30)),
            ),
            child:
                const Center(child: Text('🏆', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 18),
          const Text('Flow Math Pro',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w200,
                  color: AppColors.textBright,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text('Go deeper. See your progress.\nOwn your focus.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textDim, height: 1.6)),

          const SizedBox(height: 28),
          _featureList(),
          const SizedBox(height: 28),
          _planCards(),
          const SizedBox(height: 16),
          const Text('Cancel anytime. Free trial auto-renews unless cancelled.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textDim)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Pro features list ─────────────────────────────────────────────────────
  Widget _featureList() {
    const items = [
      ('📊', 'Full analytics & focus charts'),
      ('🔥', 'Streak calendar — see every day you focused'),
      ('🎯', 'Weakness drill reports'),
      ('🌲', 'All 8 nature soundscapes'),
      ('🎯', 'Custom session length goals'),
      ('📵', 'No app icon badge'),
    ];
    return Column(
      children: items
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(f.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Text(f.$2,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMid)),
                    const Spacer(),
                    const Icon(Icons.check_circle,
                        size: 14, color: AppColors.primary),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ── Plan cards ────────────────────────────────────────────────────────────
  Widget _planCards() {
    return Row(
      children: [
        Expanded(
            child: _planCard(
          title: 'Monthly',
          price: '\$4.99',
          period: '/ month',
          badge: '7-day free trial',
          selected: _selectedMonthly,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedMonthly = true);
          },
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _planCard(
          title: 'Lifetime',
          price: '\$49',
          period: 'one-time',
          badge: 'Best value',
          selected: !_selectedMonthly,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedMonthly = false);
          },
        )),
      ],
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required String period,
    required String badge,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.50)
                : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge,
                  style: TextStyle(
                    fontSize: 9,
                    color: selected ? AppColors.gold : AppColors.textDim,
                    letterSpacing: 0.5,
                  )),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(fontSize: 13, color: AppColors.textMid)),
            const SizedBox(height: 4),
            Text(price,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w200,
                  color: selected ? AppColors.primary : AppColors.textBright,
                  height: 1,
                )),
            Text(period,
                style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }

  // ── Footer CTA ────────────────────────────────────────────────────────────
  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          // Error
          if (_p.errorMsg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_p.errorMsg!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.incorrect)),
            ),

          // Main CTA button
          GestureDetector(
            onTap: _p.isLoading ? null : () => _purchase(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: _p.isLoading
                    ? Colors.white.withOpacity(0.04)
                    : AppColors.primary.withOpacity(0.20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary
                        .withOpacity(_p.isLoading ? 0.10 : 0.40)),
              ),
              child: Center(
                child: _p.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.primary))
                    : Text(
                        _selectedMonthly
                            ? 'START FREE TRIAL'
                            : 'GET LIFETIME ACCESS',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ),

          if (widget.dismissible)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later',
                  style: TextStyle(fontSize: 12, color: AppColors.textDim)),
            ),

          const Text('Privacy Policy · Terms of Service',
              style: TextStyle(fontSize: 10, color: AppColors.textDim)),
        ],
      ),
    );
  }

  Future<void> _purchase(BuildContext context) async {
    final ok = _selectedMonthly
        ? await _p.purchaseMonthly()
        : await _p.purchaseLifetime();
    if (!mounted) return;
    if (ok) Navigator.pop(context, true);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: AppColors.textMid)),
      backgroundColor: const Color(0xFF111E18),
      duration: const Duration(seconds: 3),
    ));
  }
}

// ── Paywall background ────────────────────────────────────────────────────────
class _PaywallBgPainter extends CustomPainter {
  final double t;
  _PaywallBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size sz) {
    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050C10), Color(0xFF080D18), Color(0xFF0A1020)],
          ).createShader(Offset.zero & sz));

    // Gold orb top-center
    canvas.drawCircle(
        Offset(sz.width * 0.5, sz.height * 0.08),
        sz.width * 0.5,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
          ..color =
              const Color(0xFF4A3A00).withOpacity(0.18 + 0.06 * sin(t * pi)));

    // Tree silhouettes bottom
    final r = Random(7);
    final p = Paint()..color = const Color(0xFF040C08);
    final step = sz.width / 14;
    for (int i = 0; i < 14; i++) {
      final x = i * step + r.nextDouble() * step * 0.6;
      final h = sz.height * (0.20 + r.nextDouble() * 0.12);
      final w = h * (0.22 + r.nextDouble() * 0.08);
      final yb = sz.height;
      canvas.drawPath(
          Path()
            ..moveTo(x, yb - h)
            ..lineTo(x - w / 2, yb)
            ..lineTo(x + w / 2, yb)
            ..close(),
          p);
      canvas.drawPath(
          Path()
            ..moveTo(x, yb - h * .70)
            ..lineTo(x - w * .60, yb - h * .28)
            ..lineTo(x + w * .60, yb - h * .28)
            ..close(),
          p);
    }

    canvas.drawRect(
        Offset.zero & sz,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.85,
            colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
          ).createShader(Offset.zero & sz));
  }

  @override
  bool shouldRepaint(_PaywallBgPainter old) => old.t != t;
}
