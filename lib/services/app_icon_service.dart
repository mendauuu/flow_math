import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// One of the app icon designs (images in assets/app_icons/).
class AppIconOption {
  final String id;
  final String name;
  final String tagline;
  const AppIconOption(this.id, this.name, this.tagline);

  String get asset => 'assets/app_icons/$id.png';
}

/// Keep the ids in sync with MainActivity.kt and AndroidManifest.xml.
const List<AppIconOption> kAppIcons = [
  AppIconOption('moon', 'Moon divide', 'Calm night, clear mind'),
  AppIconOption('sprout', 'Sprout globe', 'Grow a little every day'),
  AppIconOption('forest', 'Forest moon', 'Quiet woods after dark'),
  AppIconOption('mint', 'Mint crescent', 'Fresh and minimal'),
];

/// The app icon: shown inside the app, and on Android also used as the
/// home-screen icon (switched natively by MainActivity.kt).
class AppIconService {
  static const _channel = MethodChannel('flow_math/app_icon');
  static const _kPref = 'appIcon';
  static const _default = 'moon';

  /// The chosen icon id — widgets listen to this.
  static final ValueNotifier<String> current = ValueNotifier(_saved());

  /// Whether the home-screen icon itself can change on this device.
  static bool get changesHomeScreen => !kIsWeb && Platform.isAndroid;

  static AppIconOption get option => byId(current.value);

  static AppIconOption byId(String id) =>
      kAppIcons.firstWhere((i) => i.id == id, orElse: () => kAppIcons.first);

  static String _saved() {
    try {
      final v = Hive.box('prefs').get(_kPref);
      return v is String && kAppIcons.any((i) => i.id == v) ? v : _default;
    } catch (_) {
      return _default;
    }
  }

  /// Choose an icon. On Android the home-screen icon updates when the user
  /// leaves the app.
  static Future<void> set(String id) async {
    if (!kAppIcons.any((i) => i.id == id)) return;
    current.value = id;
    await Hive.box('prefs').put(_kPref, id);
    if (!changesHomeScreen) return;
    try {
      await _channel.invokeMethod('set', {'id': id});
    } catch (e) {
      debugPrint('Could not change app icon: $e');
    }
  }

  /// On launch: if a change didn't get applied (e.g. the app was closed
  /// before going to the background), ask for it again.
  static Future<void> sync() async {
    if (!changesHomeScreen) return;
    try {
      final onDevice = await _channel.invokeMethod<String>('current');
      if (onDevice != null && onDevice != current.value) {
        await _channel.invokeMethod('set', {'id': current.value});
      }
    } catch (e) {
      debugPrint('Could not read app icon: $e');
    }
  }
}
