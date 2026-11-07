import 'dart:io';

import 'package:flow_math/services/app_icon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The app icons live in three places (Dart list, AndroidManifest aliases,
/// MainActivity.kt) plus image resources — these tests keep them in sync.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final kotlin = File(
          'android/app/src/main/kotlin/com/mendauuu/flow_math/MainActivity.kt')
      .readAsStringSync();
  String alias(String id) => 'Icon${id[0].toUpperCase()}${id.substring(1)}';

  test('every icon has an enabled-by-default rule and a manifest alias', () {
    final aliases = RegExp(r'<activity-alias([\s\S]*?)</activity-alias>')
        .allMatches(manifest)
        .map((m) => m.group(1)!)
        .toList();
    expect(aliases.length, kAppIcons.length);
    for (final icon in kAppIcons) {
      final block = aliases.firstWhere(
          (a) => a.contains('android:name=".${alias(icon.id)}"'),
          orElse: () => fail('no alias for ${icon.id}'));
      expect(block, contains('android.intent.category.LAUNCHER'));
      expect(kotlin, contains('"${icon.id}" to "${alias(icon.id)}"'));
    }
    // Exactly one icon is on by default — the default "moon".
    final enabled =
        aliases.where((a) => a.contains('android:enabled="true"')).toList();
    expect(enabled.length, 1);
    expect(enabled.single, contains('.IconMoon'));
  });

  test('flutter run can still find the launch activity', () {
    final main = RegExp(r'<activity\s[\s\S]*?android:name="\.MainActivity"[\s\S]*?</activity>')
        .firstMatch(manifest)!
        .group(0)!;
    expect(main, contains('android.intent.action.MAIN'));
    expect(main, contains('android.intent.category.LAUNCHER'));
    // …without showing a second icon in the launcher.
    expect(main, contains('<data android:scheme='));
  });

  test('all icon images exist', () {
    const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
    for (final icon in kAppIcons) {
      final name = icon.id == 'moon' ? 'ic_launcher' : 'ic_launcher_${icon.id}';
      expect(manifest, contains('@mipmap/$name"'));
      expect(File('android/app/src/main/res/mipmap-anydpi-v26/$name.xml').existsSync(),
          isTrue, reason: name);
      for (final d in densities) {
        for (final part in ['', '_background', '_foreground']) {
          final f = File('android/app/src/main/res/mipmap-$d/$name$part.png');
          expect(f.existsSync(), isTrue, reason: f.path);
        }
      }
      expect(File(icon.asset).existsSync(), isTrue, reason: icon.asset);
    }
  });

  test('choosing an icon is remembered', () async {
    final dir = await Directory.systemTemp.createTemp('flow_math_icon');
    Hive.init(dir.path);
    await Hive.openBox('prefs');
    await AppIconService.set('forest');
    expect(AppIconService.current.value, 'forest');
    expect(Hive.box('prefs').get('appIcon'), 'forest');
    await AppIconService.set('nope'); // unknown ids are ignored
    expect(AppIconService.option.id, 'forest');
    await Hive.close();
    await dir.delete(recursive: true);
  });
}
