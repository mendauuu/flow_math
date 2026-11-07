import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Small native helpers (Android, see MainActivity.kt).
class DeviceService {
  static const _channel = MethodChannel('flow_math/device');
  static bool _screenOn = false;

  /// Keep the screen from turning off — used while a focus session runs so
  /// the phone can sit on the desk as a timer.
  static Future<void> keepScreenOn(bool on) async {
    if (on == _screenOn) return;
    _screenOn = on;
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('keepScreenOn', {'on': on});
    } catch (e) {
      debugPrint('keepScreenOn failed: $e');
    }
  }
}
