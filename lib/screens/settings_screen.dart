import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../widgets/themed.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/session_stats.dart';
import '../services/app_icon_service.dart';
import '../services/audio_service.dart';
import '../services/focus_store.dart';
import '../services/meditation_log.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/nature_switch.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  final AudioService audio;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.audio,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Palette get pal => context.palette;

  SettingsService get s => widget.settings;
  AudioService get a => widget.audio;

  void _tick() {
    if (s.haptics) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => Stack(
          children: [
            // Live preview of the chosen background
            AnimatedBackground(theme: s.bgTheme),
            ThemedScrim(0.5),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(context),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, 40),
                      children: [
                        _sectionLabel('BACKGROUND'),
                        _backgroundGrid(),
                        SizedBox(height: 14),
                        _toggleTile(
                          icon: Icons.palette_outlined,
                          label: 'Match buttons & colours',
                          sub: s.uiFollowsBackground
                              ? 'Buttons, colours and shapes change with the background'
                              : 'Pick your own interface style below',
                          value: s.uiFollowsBackground,
                          onChanged: (v) {
                            _tick();
                            s.setUiFollowsBackground(v);
                          },
                        ),
                        AnimatedSize(
                          duration: Duration(milliseconds: 300),
                          alignment: Alignment.topCenter,
                          child: s.uiFollowsBackground
                              ? SizedBox(width: double.infinity)
                              : Padding(
                                  padding: EdgeInsets.only(top: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _sectionLabel('INTERFACE STYLE'),
                                      _styleGrid(),
                                    ],
                                  ),
                                ),
                        ),
                        SizedBox(height: 32),
                        _sectionLabel('APP ICON'),
                        _appIconGrid(),
                        SizedBox(height: 10),
                        Text(
                          AppIconService.changesHomeScreen
                              ? 'Your home-screen icon changes when you leave the app.'
                              : 'Shown inside the app.',
                          style: TextStyle(fontSize: 11, color: pal.textDim),
                        ),
                        SizedBox(height: 32),
                        _sectionLabel('SOUND'),
                        _soundGrid(),
                        SizedBox(height: 20),
                        _volumeRow(),
                        SizedBox(height: 32),
                        _sectionLabel('SESSION'),
                        _sessionLengthRow(),
                        SizedBox(height: 20),
                        _startLevelTile(),
                        SizedBox(height: 12),
                        _toggleTile(
                          icon: Icons.flash_on_rounded,
                          label: 'Show streak counter',
                          sub: 'Flame icon while on a roll',
                          value: s.showStreak,
                          onChanged: (v) {
                            _tick();
                            s.setShowStreak(v);
                          },
                        ),
                        SizedBox(height: 12),
                        _toggleTile(
                          icon: Icons.bolt_rounded,
                          label: 'Auto-submit answers',
                          sub: 'Correct answers count instantly, no need to tap ✓',
                          value: s.autoSubmit,
                          onChanged: (v) {
                            _tick();
                            s.setAutoSubmit(v);
                          },
                        ),
                        SizedBox(height: 32),
                        _sectionLabel('REMINDERS'),
                        _toggleTile(
                          icon: Icons.notifications_none_rounded,
                          label: 'Daily reminder',
                          sub: s.remindDaily
                              ? 'Every day at ${_reminderTime(context)}'
                              : 'A gentle nudge to take a focus break',
                          value: s.remindDaily,
                          onChanged: (v) => _setReminder(v, s.setRemindDaily),
                        ),
                        if (s.remindDaily) ...[
                          SizedBox(height: 8),
                          _timeTile(context),
                        ],
                        SizedBox(height: 12),
                        _toggleTile(
                          icon: Icons.local_fire_department_outlined,
                          label: 'Streak saver',
                          sub: '8 PM alert when your daily streak is at risk',
                          value: s.remindStreak,
                          onChanged: (v) => _setReminder(v, s.setRemindStreak),
                        ),
                        SizedBox(height: 12),
                        _toggleTile(
                          icon: Icons.insights_rounded,
                          label: 'Weekly summary',
                          sub: 'Sunday morning recap of your week',
                          value: s.remindWeekly,
                          onChanged: (v) => _setReminder(v, s.setRemindWeekly),
                        ),
                        SizedBox(height: 32),
                        _sectionLabel('FEEL'),
                        _toggleTile(
                          icon: Icons.vibration_rounded,
                          label: 'Haptic feedback',
                          sub: 'Subtle vibration on tap',
                          value: s.haptics,
                          onChanged: (v) {
                            s.setHaptics(v);
                            _tick();
                          },
                        ),
                        SizedBox(height: 12),
                        _toggleTile(
                          icon: Icons.air_rounded,
                          label: 'Breath cues',
                          sub: 'A soft tap at each breath while meditating — '
                              'practise with eyes closed',
                          value: s.medCues,
                          onChanged: (v) {
                            _tick();
                            s.setMedCues(v);
                          },
                        ),
                        SizedBox(height: 32),
                        _sectionLabel('DATA'),
                        _historyTile(context),
                        SizedBox(height: 12),
                        _actionTile(
                          icon: Icons.restart_alt_rounded,
                          color: pal.textMid,
                          label: 'Reset settings',
                          sub: 'Restore sound, background and session defaults',
                          onTap: () => _confirmResetSettings(context),
                        ),
                        SizedBox(height: 36),
                        _footer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: ThemedTopBar(
          title: 'SETTINGS', onBack: () => Navigator.pop(context)),
    );
  }

  // ── Background picker ─────────────────────────────────────────────────────
  Widget _backgroundGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.75,
      children: kBackgroundThemes.map(_backgroundTile).toList(),
    );
  }

  Widget _backgroundTile(BackgroundTheme b) {
    final active = s.bgTheme == b.id;
    return Pressable(
      onTap: () {
        _tick();
        s.setBgTheme(b.id);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: pal.corners(0.8),
          border: Border.all(
            color: active ? pal.accent : pal.line,
            width: active ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: pal.corners(0.7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackgroundPreview(theme: b.id),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(8, 16, 8, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                  child: Text(
                    '${b.emoji} ${b.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? pal.accent
                          : pal.textBright.withValues(alpha: 0.85),
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              if (active)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: pal.accent,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.check, size: 12, color: Colors.black),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Interface style (when not matching the background) ───────────────────
  Widget _styleGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: kBackgroundThemes.map(_styleTile).toList(),
    );
  }

  /// Each tile is drawn in its own style's material, as a preview.
  Widget _styleTile(BackgroundTheme b) {
    final sp = paletteFor(b.id);
    final active = s.uiStyle == b.id;
    return Pressable(
      onTap: () {
        _tick();
        s.setUiStyle(b.id);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
              sp.accent.withValues(alpha: active ? 0.22 : 0.08), sp.surface),
          borderRadius: BorderRadius.circular(sp.radius * 0.6),
          border: Border.all(
            color: active ? sp.accent : sp.accent.withValues(alpha: 0.25),
            width: active ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                for (final c in [sp.accent, sp.warm, sp.calm])
                  Container(
                    width: 10,
                    height: 10,
                    margin: EdgeInsets.only(right: 4),
                    decoration:
                        BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                Spacer(),
                if (active) Icon(Icons.check_rounded, size: 14, color: sp.accent),
              ],
            ),
            Text(b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: active ? sp.accent : sp.textMid,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── App icon ──────────────────────────────────────────────────────────────
  Widget _appIconGrid() {
    return ValueListenableBuilder<String>(
      valueListenable: AppIconService.current,
      builder: (context, chosen, _) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
        children: [
          for (final icon in kAppIcons) _appIconTile(icon, icon.id == chosen),
        ],
      ),
    );
  }

  /// Each icon sits on a mini "home screen" made from the current scene.
  Widget _appIconTile(AppIconOption icon, bool active) {
    return Pressable(
      onTap: () => _chooseIcon(icon),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(6),
        decoration: active ? pal.card(active: true) : pal.panel(),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: pal.corners(0.7),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackgroundPreview(theme: s.bgTheme),
                    ColoredBox(color: pal.scrim.withValues(alpha: 0.2)),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: active ? 1.08 : 1,
                            duration: Duration(milliseconds: 350),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.asset(icon.asset,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.medium),
                              ),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text('Flow Math',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 4)
                                ],
                              )),
                        ],
                      ),
                    ),
                    if (active)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                              color: pal.accent, shape: BoxShape.circle),
                          child:
                              Icon(Icons.check, size: 12, color: Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(icon.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? pal.accent : pal.textMid)),
            SizedBox(height: 1),
            Text(icon.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: pal.textDim)),
            SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseIcon(AppIconOption icon) async {
    if (AppIconService.current.value == icon.id) return;
    _tick();
    await AppIconService.set(icon.id);
    if (!mounted) return;
    _toast(AppIconService.changesHomeScreen
        ? '${icon.name} it is ✨  The home-screen icon changes when you leave the app.'
        : '${icon.name} it is ✨');
  }

  // ── Sound ─────────────────────────────────────────────────────────────────
  Widget _soundGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: SoundMode.values.map((m) {
        final active = s.soundMode == m;
        return GestureDetector(
          onTap: () {
            _tick();
            s.setSoundMode(m);
            a.setMode(m);
            a.setVolume(s.volume);
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: _chipDecoration(active, radius: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AudioService.emojiOf(m),
                    style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Text(AudioService.nameOf(m),
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? pal.accent : pal.textDim,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 0.5,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _volumeRow() {
    final muted = s.soundMode == SoundMode.off;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.volume_down_rounded,
                color: pal.textDim, size: 18),
            Expanded(
              child: _slider(
                value: s.volume,
                min: 0,
                max: 1,
                onChanged: (v) {
                  s.setVolume(v);
                  a.setVolume(v);
                },
              ),
            ),
            Icon(Icons.volume_up_rounded,
                color: pal.textDim, size: 18),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            muted
                ? 'Volume  ${(s.volume * 100).round()}%  ·  pick a sound to hear it'
                : 'Volume  ${(s.volume * 100).round()}%',
            style: TextStyle(
                fontSize: 11, color: pal.textDim, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  // ── Session ───────────────────────────────────────────────────────────────
  Widget _sessionLengthRow() {
    const options = SettingsService.sessionTargets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session length',
            style: TextStyle(fontSize: 13, color: pal.textMid)),
        SizedBox(height: 2),
        Text(
          s.sessionTarget == 0
              ? 'No limit — end whenever you like'
              : 'Ends automatically after ${s.sessionTarget} minutes',
          style: TextStyle(fontSize: 11, color: pal.textDim),
        ),
        SizedBox(height: 10),
        Row(
          children: options.map((mins) {
            final active = s.sessionTarget == mins;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _tick();
                  s.setSessionTarget(mins);
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: mins == options.last ? 0 : 8),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: _chipDecoration(active, radius: 10),
                  child: Center(
                    child: Text(mins == 0 ? '∞' : '${mins}m',
                        style: TextStyle(
                          fontSize: 13,
                          color: active ? pal.accent : pal.textDim,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _startLevelTile() {
    final level = s.startLevel;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 8, 4),
      decoration: _tileDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  color: pal.textDim, size: 18),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Starting difficulty',
                        style: TextStyle(
                            fontSize: 14,
                            color: pal.textMid,
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 2),
                    Text('Flow State starts here, then adapts to you',
                        style:
                            TextStyle(fontSize: 11, color: pal.textDim)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('$level · ${_levelName(level)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: pal.accent,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          _slider(
            value: level.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) {
              final n = v.round();
              if (n == s.startLevel) return;
              _tick();
              s.setStartLevel(n);
            },
          ),
        ],
      ),
    );
  }

  static String _levelName(int level) => switch (level) {
        <= 2 => 'Gentle',
        <= 4 => 'Steady',
        <= 6 => 'Challenging',
        <= 8 => 'Hard',
        _ => 'Expert',
      };

  // ── Reminders ─────────────────────────────────────────────────────────────
  String _reminderTime(BuildContext context) =>
      TimeOfDay(hour: s.remindHour, minute: s.remindMinute).format(context);

  Future<void> _setReminder(bool on, Future<void> Function(bool) save) async {
    _tick();
    if (on) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        _toast('Notifications are blocked for Flow Math. '
            'Allow them in your phone settings first.');
        return;
      }
    }
    await save(on);
  }

  Widget _timeTile(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickTime(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _tileDecoration(),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded,
                color: pal.textDim, size: 18),
            SizedBox(width: 14),
            Expanded(
              child: Text('Reminder time',
                  style: TextStyle(
                      fontSize: 14,
                      color: pal.textMid,
                      fontWeight: FontWeight.w500)),
            ),
            Text(_reminderTime(context),
                style: TextStyle(
                    fontSize: 14,
                    color: pal.accent,
                    fontWeight: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: pal.textDim, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    _tick();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.remindHour, minute: s.remindMinute),
      helpText: 'DAILY REMINDER',
    );
    if (picked == null) return;
    await s.setRemindTime(picked.hour, picked.minute);
    if (mounted) _toast('Daily reminder set for ${_reminderTime(this.context)}');
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Widget _historyTile(BuildContext context) {
    final count = Hive.box<SessionStats>('sessions').length +
        MeditationLog.sessions +
        FocusLog.sessions;
    return _actionTile(
      icon: Icons.delete_outline_rounded,
      color: AppColors.incorrect,
      label: 'Clear history',
      sub: count == 0
          ? 'No sessions saved yet'
          : '$count session${count == 1 ? '' : 's'} saved on this device',
      onTap: count == 0 ? null : () => _confirmClearHistory(context),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: 'Clear history?',
      body: 'All math, focus and meditation sessions will be deleted '
          '(parked thoughts are kept). '
          'This cannot be undone.',
      action: 'Delete',
      color: AppColors.incorrect,
    );
    if (!ok) return;
    await Hive.box<SessionStats>('sessions').clear();
    await MeditationLog.clear();
    await FocusLog.clear();
    await NotificationService.sync(); // streak & weekly text depend on it
    if (!mounted) return;
    setState(() {});
    _toast('History cleared');
  }

  Future<void> _confirmResetSettings(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: 'Reset settings?',
      body: 'Sound, background, session and feel settings go back to their '
          'defaults. Your history and reminders are kept.',
      action: 'Reset',
      color: pal.accent,
    );
    if (!ok) return;
    await s.resetToDefaults();
    a.setMode(s.soundMode);
    a.setVolume(s.volume);
    if (mounted) _toast('Settings restored');
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required Color color,
  }) =>
      showThemedConfirm(context,
          title: title,
          body: body,
          action: action,
          actionIsSafe: true,
          tint: color);

  void _toast(String message) {
    if (mounted) showThemedToast(context, message);
  }

  Widget _footer() {
    return Center(
      child: Column(
        children: [
          Text('FLOW MATH',
              style: TextStyle(
                  fontSize: 10,
                  color: pal.accent,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Made for focus · Your data stays on this device',
              style: TextStyle(fontSize: 11, color: pal.textDim)),
        ],
      ),
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────────────
  Widget _toggleTile({
    required IconData icon,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _tileDecoration(),
        child: Row(
          children: [
            Icon(icon, color: pal.textDim, size: 18),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          color: pal.textMid,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11, color: pal.textDim)),
                ],
              ),
            ),
            SizedBox(width: 12),
            NatureSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: pal.card(tint: color),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            color: color,
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 11, color: pal.textDim)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider({
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
        activeTrackColor: pal.accent,
        inactiveTrackColor: pal.textBright.withValues(alpha: 0.08),
        thumbColor: pal.accent,
        overlayColor: pal.accent.withValues(alpha: 0.12),
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }

  BoxDecoration _tileDecoration() => pal.panel();

  BoxDecoration _chipDecoration(bool active, {required double radius}) =>
      pal.chip(active);

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: TextStyle(
            fontSize: 10,
            color: pal.textDim,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

