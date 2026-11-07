import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../widgets/themed.dart';
import 'package:flutter/services.dart';
import '../services/app_icon_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/animated_background.dart';
import 'focus_screen.dart';
import 'meditation_screen.dart';
import 'practice_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Palette get pal => context.palette;

  final SettingsService _settings = appSettings;
  final AudioService _audio = AudioService();

  @override
  void initState() {
    super.initState();
    _settings.load(); // prefs box is already open — load before first frame
    _playAmbient();
  }

  void _playAmbient() {
    _audio.setMode(_settings.soundMode);
    _audio.setVolume(_settings.volume);
  }

  @override
  void dispose() {
    _audio.stop();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: _settings,
            builder: (_, __) => AnimatedBackground(theme: _settings.bgTheme),
          ),
          ThemedScrim(0.32),
          SafeArea(
            // Fills the screen on tall phones; scrolls on very short ones.
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 720;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: _homeColumn(compact),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeColumn(bool compact) {
    return Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: compact ? 20 : 40),
                  _header(compact),
                  Spacer(),
                  SizedBox(height: compact ? 16 : 24),
                  _modeCard(
                    label: 'FLOW STATE',
                    subtitle: 'Math that sharpens your mind.',
                    emoji: '🌊',
                    onTap: () => _open(PracticeScreen(
                        settings: _settings, audio: _audio)),
                    accentColor: pal.accent,
                  ),
                  SizedBox(height: 12),
                  _modeCard(
                    label: 'FOCUS',
                    subtitle: 'Pomodoro for deep work. Start tiny.',
                    emoji: '🕯️',
                    onTap: () =>
                        _open(FocusScreen(settings: _settings, audio: _audio)),
                    accentColor: pal.warm,
                  ),
                  SizedBox(height: 12),
                  _modeCard(
                    label: 'MEDITATION',
                    subtitle: 'Breathe slowly. Grow calm.',
                    emoji: '🧘',
                    onTap: () => _open(
                        MeditationScreen(settings: _settings, audio: _audio)),
                    accentColor: pal.calm,
                  ),
                  SizedBox(height: compact ? 18 : 24),
                  _bottomRow(context),
                  SizedBox(height: compact ? 20 : 36),
                ],
              ),
            );
  }

  Widget _header(bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          // The chosen app icon doubles as the in-app brand mark.
          ValueListenableBuilder<String>(
            valueListenable: AppIconService.current,
            builder: (_, id, __) => AnimatedSwitcher(
              duration: Duration(milliseconds: 400),
              child: ClipRRect(
                key: ValueKey(id),
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(AppIconService.byId(id).asset,
                    width: 22, height: 22, filterQuality: FilterQuality.medium),
              ),
            ),
          ),
          SizedBox(width: 10),
          Text('FLOW MATH',
              style: TextStyle(
                  fontSize: 11,
                  color: pal.accent,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600)),
        ]),
        SizedBox(height: compact ? 14 : 22),
        Text('Quiet\nyour mind.',
            style: TextStyle(
                fontSize: compact ? 36 : 44,
                fontWeight: FontWeight.w200,
                color: pal.textBright,
                height: 1.12,
                letterSpacing: -0.5)),
        SizedBox(height: compact ? 8 : 12),
        Text('Sharpen your mind, beat the drift,\nbreathe a little slower.',
            style: TextStyle(
                fontSize: 14, color: pal.textDim, height: 1.65)),
      ],
    );
  }

  Widget _modeCard({
    required String label,
    required String subtitle,
    required String emoji,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return Pressable(
      onTap: () {
        if (_settings.haptics) HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: pal.card(tint: accentColor),
        child: Row(
          children: [
            // Emoji sits in a little tile of the same material
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: pal.chip(true, tint: accentColor, scale: 0.6),
              child: Text(emoji, style: TextStyle(fontSize: 22)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                          letterSpacing: 2.5)),
                  SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: pal.textDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: accentColor.withValues(alpha: 0.7), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _bottomRow(BuildContext context) {
    return Row(
      children: [
        // History
        Pressable(
          onTap: () => Navigator.push(
              context, _fadeRoute(StatsScreen(settings: _settings))),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pal.panel(scale: 0.6),
            child: Row(children: [
              Icon(Icons.show_chart, color: pal.textMid, size: 16),
              SizedBox(width: 8),
              Text('HISTORY',
                  style: TextStyle(
                      fontSize: 10, color: pal.textMid, letterSpacing: 2)),
            ]),
          ),
        ),
        Spacer(),
        // Settings
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            _fadeRoute(SettingsScreen(settings: _settings, audio: _audio)),
          ).then((_) {
            // Re-apply any changed settings when returning
            if (!mounted) return;
            _playAmbient();
            setState(() {});
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: EdgeInsets.all(10),
            decoration: pal.panel(scale: 0.6),
            child: Icon(Icons.tune_rounded, color: pal.textMid, size: 18),
          ),
        ),
      ],
    );
  }

  /// Opens a mode. The ambient sound keeps playing — every mode shares it.
  void _open(Widget page) {
    Navigator.push(context, _fadeRoute(page)).then((_) {
      if (mounted) _playAmbient();
    });
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: Duration(milliseconds: 600),
      );
}
