import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/session_stats.dart';
import '../theme/palette.dart';
import 'focus_store.dart';
import 'meditation_log.dart';
import 'settings_service.dart';

/// "Your timer finished" alerts for sessions that run while the phone is
/// locked or the app is in the background.
enum TimerAlert {
  meditation(4, 'Meditation'),
  focus(5, 'Focus');

  const TimerAlert(this.id, this.tag);
  final int id;
  final String tag;
}

// ─────────────────────────────────────────────────────────────────────────────
//  NotificationService
//  Every reminder follows the user's choices in Settings (stored in the
//  'prefs' Hive box). Call [sync] whenever a choice or the session history
//  changes; it schedules or cancels each reminder to match:
//    1. Daily focus reminder (chosen time)
//    2. Streak saver (8 PM on a day you haven't played yet)
//    3. Weekly progress summary (Sunday 09:00)
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channelId = 'flow_math_main';
  static const _channelName = 'Flow Math';

  // ── Notification IDs ─────────────────────────────────────────────────────
  static const _idDaily = 1;
  static const _idStreak = 2;
  static const _idWeekly = 3;

  // ── Pref keys (also written by SettingsService / onboarding) ─────────────
  static const kDaily = 'remindDaily';
  static const kHour = 'remindHour';
  static const kMinute = 'remindMinute';
  static const kStreak = 'remindStreak';
  static const kWeekly = 'remindWeekly';

  // Reminders don't need to-the-second precision, and inexact alarms need no
  // special "exact alarm" permission on Android 12+.
  static const _androidMode = AndroidScheduleMode.inexactAllowWhileIdle;

  static Future<void> init() async {
    try {
      tz.initializeTimeZones();

      // Flat moon silhouette (res/drawable/ic_stat_moon.xml) — status-bar
      // icons must be single-colour, not the full launcher icon.
      const android = AndroidInitializationSettings('@drawable/ic_stat_moon');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  // ── Ask the OS for permission ────────────────────────────────────────────
  static Future<bool> requestPermission() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final iosGranted = await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          true;
      final androidGranted =
          await android?.requestNotificationsPermission() ?? true;
      return iosGranted && androidGranted;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  // ── Bring every reminder in line with the saved choices ──────────────────
  static Future<void> sync() async {
    if (!_ready) return;
    try {
      final prefs = Hive.box('prefs');
      bool enabled(String key) => prefs.get(key) == true;

      if (enabled(kDaily)) {
        await _scheduleDaily(
          hour: _int(prefs.get(kHour), 19, 0, 23),
          minute: _int(prefs.get(kMinute), 0, 0, 59),
          sessionMinutes: _int(prefs.get('sessionTarget'), 10, 0, 600),
        );
      } else {
        await _plugin.cancel(_idDaily);
      }

      // The streak saver is a one-off that depends on today's history, so it
      // is always rebuilt from scratch.
      await _plugin.cancel(_idStreak);
      if (enabled(kStreak)) await _scheduleStreakSaver();

      if (enabled(kWeekly)) {
        await _scheduleWeekly();
      } else {
        await _plugin.cancel(_idWeekly);
      }
    } catch (e) {
      debugPrint('Could not update reminders: $e');
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Timer finished while the phone was locked / app in background ────────
  /// Fallback alarm in case the app is frozen while the screen is off.
  static Future<void> scheduleAlert(
      TimerAlert alert, Duration after, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        alert.id,
        title,
        body,
        tz.TZDateTime.from(DateTime.now().add(after), tz.UTC),
        _details(alert.tag),
        androidScheduleMode: _androidMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Could not schedule ${alert.tag} alert: $e');
    }
  }

  /// Shown right away when a timer ends while the app is hidden.
  static Future<void> showAlert(
      TimerAlert alert, String title, String body) async {
    if (!_ready) return;
    try {
      await cancelAlert(alert);
      await _plugin.show(alert.id, title, body, _details(alert.tag));
    } catch (e) {
      debugPrint('Could not show ${alert.tag} alert: $e');
    }
  }

  static Future<void> cancelAlert(TimerAlert alert) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(alert.id, tag: alert.tag);
    } catch (_) {}
  }

  // ── 1. Daily reminder ────────────────────────────────────────────────────
  static Future<void> _scheduleDaily({
    required int hour,
    required int minute,
    required int sessionMinutes,
  }) async {
    final body = sessionMinutes > 0
        ? 'A $sessionMinutes-minute session keeps your mind sharp.'
        : 'A short session keeps your mind sharp.';
    await _plugin.zonedSchedule(
      _idDaily,
      'Time to flow 🌲',
      body,
      _nextLocal(hour, minute),
      _details('Focus reminder'),
      androidScheduleMode: _androidMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── 2. Streak saver — 8 PM on the first day you haven't played ───────────
  static Future<void> _scheduleStreakSaver() async {
    final days = _playedDays();
    if (days.isEmpty) return;

    final today = _dateOnly(DateTime.now());
    final yesterday = _addDays(today, -1);
    final last = days.reduce((a, b) => a.isAfter(b) ? a : b);
    if (last != today && last != yesterday) return; // streak already over

    var streak = 0;
    for (var d = last; days.contains(d); d = _addDays(d, -1)) {
      streak++;
    }
    if (streak < 2) return;

    // Played today → the risk is tomorrow. Played yesterday → it's tonight.
    final day = last == today ? _addDays(today, 1) : today;
    final when = DateTime(day.year, day.month, day.day, 20);
    if (!when.isAfter(DateTime.now())) return;

    await _plugin.zonedSchedule(
      _idStreak,
      'Your $streak-day streak ends tonight 🔥',
      'Jump in for just 5 minutes to keep it alive.',
      tz.TZDateTime.from(when, tz.UTC),
      _details('Streak alert'),
      androidScheduleMode: _androidMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── 3. Weekly summary — Sunday 09:00 ─────────────────────────────────────
  static Future<void> _scheduleWeekly() async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recent = Hive.box<SessionStats>('sessions')
        .values
        .where((s) => s.date.isAfter(weekAgo))
        .toList();

    final String body;
    if (recent.isEmpty) {
      body = 'A fresh week starts now. One short session is all it takes.';
    } else {
      final problems = recent.fold<int>(0, (sum, s) => sum + s.totalProblems);
      final focus = recent.fold<double>(0, (sum, s) => sum + s.focusScore) /
          recent.length;
      body =
          '$problems problems solved · avg focus ${focus.toStringAsFixed(0)}/100';
    }

    await _plugin.zonedSchedule(
      _idWeekly,
      'Your week in focus 📊',
      body,
      _nextLocal(9, 0, weekday: DateTime.sunday),
      _details('Weekly summary'),
      androidScheduleMode: _androidMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static NotificationDetails _details(String tag) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
          // Tinted with the accent of the interface style in use.
          color: paletteFor(appSettings.activeStyle).accent,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  /// The next [hour]:[minute] in the phone's local time (optionally on a
  /// given [weekday]), expressed as a UTC instant. Working from the device
  /// clock avoids needing to know the local timezone name — without that,
  /// `tz.local` is UTC and a "7 PM" reminder would fire at 7 PM UTC.
  static tz.TZDateTime _nextLocal(int hour, int minute, {int? weekday}) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day, hour, minute);
    while (!d.isAfter(now) || (weekday != null && d.weekday != weekday)) {
      d = DateTime(d.year, d.month, d.day + 1, hour, minute);
    }
    return tz.TZDateTime.from(d, tz.UTC);
  }

  /// Days with any practice — math, focus or meditation keep the streak alive.
  static Set<DateTime> _playedDays() => {
        ...Hive.box<SessionStats>('sessions').values.map((s) => _dateOnly(s.date)),
        ...MeditationLog.days,
        ...FocusLog.days,
      };

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  static int _int(Object? v, int fallback, int lo, int hi) =>
      v is int ? v.clamp(lo, hi) : fallback;
}
