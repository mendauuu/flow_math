import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────────────────────────────────────
//  NotificationService
//  Schedules:
//    1. Daily focus reminder (chosen time)
//    2. Streak save alert (if no session by 8 PM)
//    3. Weekly progress summary (Sunday morning)
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

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  // ── Request permission (call after onboarding) ────────────────────────────
  static Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final iosGranted =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
            true;
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;
    return iosGranted && androidGranted;
  }

  // ── Schedule daily focus reminder ─────────────────────────────────────────
  /// [hour] and [minute] in 24h local time.
  static Future<void> scheduleDailyReminder({
    int hour = 19,
    int minute = 0,
  }) async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      _idDaily,
      'Time to flow 🌲',
      'A 10-minute session keeps your mind sharp.',
      _nextInstanceOf(hour, minute),
      _details('Focus reminder'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Streak saver — fires at 20:00 if no session today ────────────────────
  static Future<void> scheduleStreakSaver(int currentStreak) async {
    if (!_ready || currentStreak < 2) return;
    await _plugin.zonedSchedule(
      _idStreak,
      'Your $currentStreak-day streak ends tonight 🔥',
      'Jump in for just 5 minutes to keep it alive.',
      _nextInstanceOf(20, 0),
      _details('Streak alert'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Weekly summary — Sunday 09:00 ─────────────────────────────────────────
  static Future<void> scheduleWeeklySummary({
    required int totalProblems,
    required double avgFocus,
  }) async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      _idWeekly,
      'Your week in focus 📊',
      '$totalProblems problems solved · avg focus ${avgFocus.toStringAsFixed(0)}/100',
      _nextSunday(9, 0),
      _details('Weekly summary'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ── Cancel all ────────────────────────────────────────────────────────────
  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Helpers ───────────────────────────────────────────────────────────────
  static NotificationDetails _details(String tag) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextSunday(int hour, int minute) {
    var dt = tz.TZDateTime.now(tz.local);
    while (dt.weekday != DateTime.sunday) {
      dt = dt.add(const Duration(days: 1));
    }
    return tz.TZDateTime(tz.local, dt.year, dt.month, dt.day, hour, minute);
  }
}
