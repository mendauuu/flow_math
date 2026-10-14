import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/session_stats.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AnalyzeScreen
// ─────────────────────────────────────────────────────────────────────────────
class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});
  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;
  late List<SessionStats> _sessions;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    final box = Hive.box<SessionStats>('sessions');
    _sessions = box.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  // ── Aggregates ──────────────────────────────────────────────────────────
  int    get _total       => _sessions.length;
  double get _avgFocus    => _total == 0 ? 0 : _sessions.fold(0.0,(s,e)=>s+e.focusScore)/_total;
  double get _avgAccuracy => _total == 0 ? 0 : _sessions.fold(0.0,(s,e)=>s+e.accuracy)/_total;
  int    get _totalProbs  => _sessions.fold(0,(s,e)=>s+e.totalProblems);
  int    get _totalMins   => _sessions.fold(0,(s,e)=>s+e.sessionDurationSeconds)~/60;
  int    get _bestStreak  => _sessions.fold(0,(s,e)=>max(s,e.maxStreak));
  double get _bestFocus   => _sessions.fold(0.0,(s,e)=>max(s,e.focusScore));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060C14),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          if (_sessions.isEmpty)
            _buildEmpty()
          else ...[
            _sliver(_heroStats()),
            _sliver(const SizedBox(height: 28)),
            _sliver(_sectionLabel('FOCUS SCORE  —  last 30 sessions')),
            _sliver(_focusLineChart()),
            _sliver(const SizedBox(height: 28)),
            _sliver(_sectionLabel('ACCURACY  vs  SPEED')),
            _sliver(_accuracySpeedChart()),
            _sliver(const SizedBox(height: 28)),
            _sliver(_sectionLabel('DAILY ACTIVITY  —  last 12 weeks')),
            _sliver(_heatmap()),
            _sliver(const SizedBox(height: 28)),
            _sliver(_sectionLabel('DIFFICULTY  PROGRESSION')),
            _sliver(_difficultyBarChart()),
            _sliver(const SizedBox(height: 28)),
            _sliver(_sectionLabel('BEST SESSION')),
            _sliver(_bestSessionCard()),
            _sliver(const SizedBox(height: 60)),
          ],
        ],
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────
  Widget _buildAppBar() => SliverAppBar(
    backgroundColor: const Color(0xFF060C14),
    expandedHeight: 110,
    pinned: true,
    elevation: 0,
    leading: GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textMid, size: 15),
      ),
    ),
    flexibleSpace: FlexibleSpaceBar(
      titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      title: const Text('ANALYTICS', style: TextStyle(
        fontSize: 11, color: AppColors.textDim,
        letterSpacing: 4, fontWeight: FontWeight.w600,
      )),
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0A1A10), Color(0xFF060C14)],
          ),
        ),
      ),
    ),
  );

  Widget _buildEmpty() => SliverFillRemaining(
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Text('🌱', style: TextStyle(fontSize: 48)),
        SizedBox(height: 16),
        Text('No data yet.', style: TextStyle(
          fontSize: 20, color: AppColors.textMid, fontWeight: FontWeight.w300)),
        SizedBox(height: 8),
        Text('Complete a session to see your analytics.',
            style: TextStyle(fontSize: 13, color: AppColors.textDim)),
      ]),
    ),
  );

  // ── Hero stat row ────────────────────────────────────────────────────────
  Widget _heroStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        Row(children: [
          _heroTile('$_total', 'SESSIONS', AppColors.primary),
          const SizedBox(width: 12),
          _heroTile('$_totalMins m', 'FOCUSED', const Color(0xFF7BA8D4)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _heroTile('$_totalProbs', 'SOLVED', AppColors.gold),
          const SizedBox(width: 12),
          _heroTile('$_bestStreak', 'BEST STREAK', const Color(0xFFE07070)),
        ]),
      ]),
    );
  }

  Widget _heroTile(String value, String label, Color color) => Expanded(
    child: AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.10),
              color.withOpacity(0.04),
            ],
          ),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w200,
            color: color, height: 1,
          )),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(
            fontSize: 9, color: AppColors.textDim, letterSpacing: 2)),
        ]),
      ),
    ),
  );

  // ── Focus line chart ─────────────────────────────────────────────────────
  Widget _focusLineChart() {
    final data = _sessions.reversed.take(30).toList().reversed.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AnimatedBuilder(
            animation: _shimmer,
            builder: (_, __) => CustomPaint(
              painter: _LineChartPainter(
                data: data.map((s) => s.focusScore).toList(),
                color: AppColors.primary,
                shimmerT: _shimmer.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Accuracy vs Speed scatter ─────────────────────────────────────────────
  Widget _accuracySpeedChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: _ScatterPainter(sessions: _sessions),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  // ── GitHub-style heatmap ─────────────────────────────────────────────────
  Widget _heatmap() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeatmapWidget(sessions: _sessions),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Less', style: TextStyle(fontSize: 9, color: AppColors.textDim)),
              const SizedBox(width: 6),
              ...List.generate(5, (i) => Container(
                width: 10, height: 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: _heatColor(i / 4),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(width: 3),
              const Text('More', style: TextStyle(fontSize: 9, color: AppColors.textDim)),
            ]),
          ],
        ),
      ),
    );
  }

  Color _heatColor(double t) {
    if (t <= 0) return Colors.white.withOpacity(0.06);
    return Color.lerp(
      const Color(0xFF0D3A20),
      const Color(0xFF6EC6AA),
      t,
    )!;
  }

  // ── Difficulty bar chart ─────────────────────────────────────────────────
  Widget _difficultyBarChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AnimatedBuilder(
            animation: _shimmer,
            builder: (_, __) => CustomPaint(
              painter: _BarChartPainter(
                sessions: _sessions,
                shimmerT: _shimmer.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Best session card ────────────────────────────────────────────────────
  Widget _bestSessionCard() {
    final best = _sessions.reduce((a, b) =>
        a.focusScore >= b.focusScore ? a : b);
    final d = best.date;
    final dateStr =
        '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    final mins = best.sessionDurationSeconds ~/ 60;
    final secs = best.sessionDurationSeconds % 60;
    final timeStr = '${mins}m ${secs}s';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.12),
              AppColors.primary.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🏆  BEST SESSION', style: TextStyle(
              fontSize: 10, color: AppColors.primary,
              letterSpacing: 2, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 10),
            Text(best.focusScore.toStringAsFixed(0), style: const TextStyle(
              fontSize: 52, fontWeight: FontWeight.w100,
              color: AppColors.primary, height: 1,
            )),
            const Text('focus score', style: TextStyle(
              fontSize: 11, color: AppColors.textDim)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _pill(dateStr),
            const SizedBox(height: 8),
            _pill('$timeStr'),
            const SizedBox(height: 8),
            _pill('${best.accuracy.toStringAsFixed(0)}% accuracy'),
            const SizedBox(height: 8),
            _pill('×${best.maxStreak} streak'),
          ]),
        ]),
      ),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: const TextStyle(
      fontSize: 11, color: AppColors.textMid)),
  );

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _sliver(Widget child) =>
      SliverToBoxAdapter(child: child);

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Text(text, style: const TextStyle(
      fontSize: 9, color: AppColors.textDim,
      letterSpacing: 2.5, fontWeight: FontWeight.w600,
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Line Chart Painter  (focus score over last 30 sessions)
// ─────────────────────────────────────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double shimmerT;
  _LineChartPainter({required this.data, required this.color, required this.shimmerT});

  @override
  void paint(Canvas canvas, Size sz) {
    if (data.isEmpty) return;

    const pad = EdgeInsets.fromLTRB(36, 16, 16, 32);
    final w = sz.width  - pad.left - pad.right;
    final h = sz.height - pad.top  - pad.bottom;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = pad.top + h * (1 - i / 4);
      canvas.drawLine(Offset(pad.left, y), Offset(sz.width - pad.right, y), gridPaint);
      // Y-axis labels
      final val = (i * 25).toString();
      _drawText(canvas, val, Offset(4, y - 6),
          color.withOpacity(0.35), 8);
    }

    if (data.length < 2) return;

    final n = data.length;
    Offset point(int i) => Offset(
      pad.left + i / (n - 1) * w,
      pad.top  + h * (1 - data[i] / 100),
    );

    // Filled area under curve
    final areaPath = Path()..moveTo(point(0).dx, pad.top + h);
    for (int i = 0; i < n; i++) areaPath.lineTo(point(i).dx, point(i).dy);
    areaPath.lineTo(point(n-1).dx, pad.top + h);
    areaPath.close();
    canvas.drawPath(areaPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.22), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, pad.top, sz.width, h)));

    // Line
    final linePath = Path()..moveTo(point(0).dx, point(0).dy);
    for (int i = 1; i < n; i++) {
      final cp1 = Offset((point(i-1).dx + point(i).dx)/2, point(i-1).dy);
      final cp2 = Offset((point(i-1).dx + point(i).dx)/2, point(i).dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, point(i).dx, point(i).dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);

    // Dots on each point
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(point(i), 3, Paint()..color = color);
      canvas.drawCircle(point(i), 3,
          Paint()..color = Colors.white.withOpacity(0.6)
            ..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    // Shimmer highlight dot (moves along the line)
    final si = (shimmerT * (n - 1)).round().clamp(0, n - 1);
    canvas.drawCircle(point(si), 6,
        Paint()..color = color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(point(si), 4, Paint()..color = Colors.white);

    // Avg line
    final avg = data.fold(0.0,(a,b)=>a+b)/data.length;
    final avgY = pad.top + h * (1 - avg/100);
    canvas.drawLine(
      Offset(pad.left, avgY), Offset(sz.width - pad.right, avgY),
      Paint()..color = color.withOpacity(0.20)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round);
    _drawText(canvas, 'avg ${avg.toStringAsFixed(0)}',
        Offset(sz.width - pad.right - 30, avgY - 12),
        color.withOpacity(0.50), 8);

    // X labels (first / middle / last)
    _drawText(canvas, '1', Offset(pad.left - 4, sz.height - 18),
        Colors.white.withOpacity(0.25), 8);
    _drawText(canvas, '$n', Offset(sz.width - pad.right - 4, sz.height - 18),
        Colors.white.withOpacity(0.25), 8);
  }

  void _drawText(Canvas c, String text, Offset pos, Color col, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: col, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, pos);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.shimmerT != shimmerT;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Scatter Painter  (accuracy X axis, speed Y axis, dot = session)
// ─────────────────────────────────────────────────────────────────────────────
class _ScatterPainter extends CustomPainter {
  final List<SessionStats> sessions;
  _ScatterPainter({required this.sessions});

  @override
  void paint(Canvas canvas, Size sz) {
    const pad = EdgeInsets.fromLTRB(44, 16, 16, 36);
    final w = sz.width  - pad.left - pad.right;
    final h = sz.height - pad.top  - pad.bottom;

    // Grid
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth=1;
    for (int i=0; i<=4; i++) {
      final y = pad.top + h * i / 4;
      canvas.drawLine(Offset(pad.left,y), Offset(sz.width-pad.right,y), gridPaint);
      final x = pad.left + w * i / 4;
      canvas.drawLine(Offset(x, pad.top), Offset(x, pad.top+h), gridPaint);
    }

    // Axis labels
    _drawText(canvas,'100%', Offset(sz.width-pad.right-16, pad.top+h+4),
        Colors.white.withOpacity(0.25), 8);
    _drawText(canvas,'0%', Offset(pad.left, pad.top+h+4),
        Colors.white.withOpacity(0.25), 8);
    _drawText(canvas,'ACCURACY →', Offset(sz.width/2-24, pad.top+h+18),
        Colors.white.withOpacity(0.20), 7);
    _drawText(canvas,'FAST', Offset(4, pad.top),
        Colors.white.withOpacity(0.25), 8);
    _drawText(canvas,'SLOW', Offset(4, pad.top+h-10),
        Colors.white.withOpacity(0.25), 8);

    // Quadrant labels
    _drawText(canvas,'ZONE', Offset(pad.left+w*0.6, pad.top+6),
        AppColors.primary.withOpacity(0.30), 7);
    _drawText(canvas,'FLOW', Offset(pad.left+w*0.6, pad.top+14),
        AppColors.primary.withOpacity(0.30), 7);

    // Dots
    for (final s in sessions) {
      final acc = s.accuracy.clamp(0, 100) / 100;
      // speed: 2000ms → top, 12000ms+ → bottom
      final spd = 1.0 - ((s.avgResponseTimeMs - 2000) / 10000).clamp(0.0, 1.0);
      final x = pad.left + acc * w;
      final y = pad.top  + (1 - spd) * h;

      // Color by focus score
      final t = s.focusScore / 100;
      final col = Color.lerp(const Color(0xFFE07070), AppColors.primary, t)!;

      // Glow
      canvas.drawCircle(Offset(x,y), 8,
          Paint()..color = col.withOpacity(0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(Offset(x,y), 4, Paint()..color = col.withOpacity(0.85));
      canvas.drawCircle(Offset(x,y), 4,
          Paint()..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.stroke..strokeWidth=1);
    }
  }

  void _drawText(Canvas c, String text, Offset pos, Color col, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: col, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, pos);
  }

  @override
  bool shouldRepaint(_ScatterPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bar Chart Painter  (difficulty level per session)
// ─────────────────────────────────────────────────────────────────────────────
class _BarChartPainter extends CustomPainter {
  final List<SessionStats> sessions;
  final double shimmerT;
  _BarChartPainter({required this.sessions, required this.shimmerT});

  @override
  void paint(Canvas canvas, Size sz) {
    final data = sessions.reversed.take(20).toList().reversed.toList();
    if (data.isEmpty) return;

    const pad = EdgeInsets.fromLTRB(28, 12, 12, 28);
    final w = sz.width  - pad.left - pad.right;
    final h = sz.height - pad.top  - pad.bottom;
    final barW = (w / data.length) * 0.6;
    final gap   = w / data.length;

    // Grid
    for (int i = 0; i <= 5; i++) {
      final y = pad.top + h * (1 - i / 5);
      canvas.drawLine(Offset(pad.left, y), Offset(sz.width-pad.right, y),
          Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth=1);
      if (i > 0) _drawText(canvas, '${i*2}',
          Offset(4, y-6), Colors.white.withOpacity(0.25), 7);
    }

    for (int i = 0; i < data.length; i++) {
      final lvl   = data[i].maxDifficultyReached.clamp(1, 10);
      final barH  = h * lvl / 10;
      final x     = pad.left + i * gap + (gap - barW) / 2;
      final y     = pad.top  + h - barH;

      final t = lvl / 10;
      final col = Color.lerp(const Color(0xFF2A6A48), AppColors.primary, t)!;

      // Shimmer active bar
      final isActive = (shimmerT * data.length).floor() == i;

      final rr = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barW, barH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      canvas.drawRRect(rr, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: isActive
              ? [Colors.white.withOpacity(0.9), col]
              : [col.withOpacity(0.9), col.withOpacity(0.5)],
        ).createShader(Rect.fromLTWH(x, y, barW, barH)));
    }

    _drawText(canvas, 'DIFFICULTY (1–10)',
        Offset(sz.width/2 - 40, sz.height - 14),
        Colors.white.withOpacity(0.20), 7);
  }

  void _drawText(Canvas c, String text, Offset pos, Color col, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: col, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, pos);
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.shimmerT != shimmerT;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Heatmap Widget  (GitHub contribution graph style — 12 weeks × 7 days)
// ─────────────────────────────────────────────────────────────────────────────
class _HeatmapWidget extends StatelessWidget {
  final List<SessionStats> sessions;
  const _HeatmapWidget({required this.sessions});

  @override
  Widget build(BuildContext context) {
    const weeks = 15;
    const days  = 7;
    final today = DateTime.now();

    // Build a map: dateKey → total problems solved that day
    final Map<String, int> dayMap = {};
    for (final s in sessions) {
      final key = '${s.date.year}-${s.date.month}-${s.date.day}';
      dayMap[key] = (dayMap[key] ?? 0) + s.totalProblems;
    }

    final maxVal = dayMap.values.fold(0, max).toDouble();

    // Day labels (Mon, Wed, Fri)
    final dayLabels = ['M','T','W','T','F','S','S'];

    // Month labels — find first day of each month in the range
    final startDay = today.subtract(Duration(days: weeks * 7 - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month row
        _monthRow(weeks, today),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day labels
            Column(
              children: List.generate(days, (d) => SizedBox(
                height: 14,
                width: 12,
                child: Text(
                  dayLabels[d],
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.white.withOpacity(d % 2 == 0 ? 0.3 : 0.0),
                  ),
                ),
              )),
            ),
            const SizedBox(width: 4),
            // Grid
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(weeks, (w) {
                  return Column(
                    children: List.generate(days, (d) {
                      final date = startDay.add(Duration(days: w * 7 + d));
                      if (date.isAfter(today)) {
                        return const SizedBox(width: 14, height: 14);
                      }
                      final key = '${date.year}-${date.month}-${date.day}';
                      final val = dayMap[key] ?? 0;
                      final t = maxVal == 0 ? 0.0 : (val / maxVal).clamp(0.0, 1.0);
                      return Tooltip(
                        message: val == 0
                            ? '${_fmt(date)}: no session'
                            : '${_fmt(date)}: $val problems',
                        child: Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: _cellColor(t),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _monthRow(int weeks, DateTime today) {
    final startDay = today.subtract(Duration(days: weeks * 7 - 1));
    final labels = <Widget>[];
    labels.add(const SizedBox(width: 16)); // offset for day labels

    String? lastMonth;
    for (int w = 0; w < weeks; w++) {
      final d = startDay.add(Duration(days: w * 7));
      final mon = _monthAbbr(d.month);
      if (mon != lastMonth && d.day <= 7) {
        lastMonth = mon;
        labels.add(Expanded(child: Text(mon, style: TextStyle(
          fontSize: 8, color: Colors.white.withOpacity(0.35)))));
      } else {
        labels.add(const Expanded(child: SizedBox()));
      }
    }

    return Row(children: labels);
  }

  Color _cellColor(double t) {
    if (t <= 0) return Colors.white.withOpacity(0.06);
    if (t < 0.25) return const Color(0xFF0D3A20);
    if (t < 0.50) return const Color(0xFF1A5C35);
    if (t < 0.75) return const Color(0xFF2E8A52);
    return const Color(0xFF6EC6AA);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';

  String _monthAbbr(int m) =>
      ['','Jan','Feb','Mar','Apr','May','Jun',
       'Jul','Aug','Sep','Oct','Nov','Dec'][m];
}
