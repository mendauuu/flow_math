import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flow_math/widgets/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paints every background scene straight to pixels: no crashes at any
/// moment of the loop, each scene is really wired up (not the forest
/// fallback), and the 40 s loop is seamless (end frame == start frame).
void main() {
  Future<Uint8List> render(String id, Size size, double t) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    ScenePainter(id, fixedT: t).paint(canvas, size);
    final image = await recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Fraction of pixels that differ noticeably between two frames.
  double diff(Uint8List a, Uint8List b) {
    var changed = 0;
    for (var i = 0; i < a.length; i += 4) {
      for (var ch = 0; ch < 3; ch++) {
        if ((a[i + ch] - b[i + ch]).abs() > 12) {
          changed++;
          break;
        }
      }
    }
    return changed / (a.length / 4);
  }

  const phone = Size(200, 400); // scaled-down phone, keeps the test quick
  const tile = Size(110, 80); // Settings picker tile

  testWidgets('every scene paints through the whole loop', (tester) async {
    await tester.runAsync(() async {
      for (final b in kBackgroundThemes) {
        for (final size in const [phone, tile]) {
          for (final t in const [0.0, 0.07, 0.31, 0.44, 0.62, 0.78, 0.97]) {
            final px = await render(b.id, size, t);
            expect(px.length, size.width * size.height * 4,
                reason: '${b.id} @ $t');
          }
        }
      }
    });
  });

  testWidgets('every scene is its own picture (none falls back to forest)',
      (tester) async {
    await tester.runAsync(() async {
      final frames = {
        for (final b in kBackgroundThemes) b.id: await render(b.id, phone, 0.44)
      };
      final ids = frames.keys.toList();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final d = diff(frames[ids[i]]!, frames[ids[j]]!);
          expect(d, greaterThan(0.05), reason: '${ids[i]} vs ${ids[j]}: $d');
        }
      }
    });
  });

  testWidgets('scenes loop seamlessly and keep moving', (tester) async {
    await tester.runAsync(() async {
      for (final b in kBackgroundThemes) {
        final start = await render(b.id, phone, 0.0);
        final end = await render(b.id, phone, 1.0);
        // Off-beat moment: at 0.5 every even-cycle motion is back at start.
        final mid = await render(b.id, phone, 0.37);
        final seam = diff(start, end);
        final motion = diff(start, mid);
        // ignore: avoid_print
        print('${b.id.padRight(9)} seam ${seam.toStringAsFixed(4)}  '
            'motion ${motion.toStringAsFixed(4)}');
        expect(seam, lessThan(0.003), reason: '${b.id} seam');
        expect(motion, greaterThan(0.0005), reason: '${b.id} moves');
      }
    });
  });
}
