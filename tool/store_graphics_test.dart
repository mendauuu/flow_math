// Renders the Google Play feature graphic (1024×500) from the app's own
// animated scenes. Not part of the normal test run — generate with:
//
//   flutter test tool/store_graphics_test.dart
//
// Output: play_store/feature-graphic-<scene>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flow_math/widgets/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fonts = r'C:\src\flutter\bin\cache\artifacts\material_fonts';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('$_fonts\\$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

ui.Paragraph _text(String s, double size, Color color,
    {FontWeight weight = FontWeight.w300, double spacing = 0}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Roboto'))
    ..pushStyle(ui.TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      fontFamily: 'Roboto',
    ))
    ..addText(s);
  return b.build()..layout(const ui.ParagraphConstraints(width: 900));
}

void main() {
  testWidgets('feature graphic', (tester) async {
    await tester.runAsync(() async {
      await _loadFont('Roboto', ['roboto-light.ttf', 'roboto-medium.ttf']);
      final iconBytes = File(
              'assets/flow-math-icons/A-moon-divide/assets/icon/icon-1024.png')
          .readAsBytesSync();
      final icon =
          (await (await ui.instantiateImageCodec(iconBytes)).getNextFrame())
              .image;
      Directory('play_store').createSync();

      for (final scene in const [
        ('lanterns', Color(0xFFFF9E5C)),
        ('starfall', Color(0xFFF4D88A)),
        ('sakura', Color(0xFFF5A8CA)),
      ]) {
        const size = Size(1024, 500);
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        ScenePainter(scene.$1, fixedT: 0.44).paint(c, size);
        // Darken the left side so the words read clearly.
        c.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = const LinearGradient(colors: [
              Color(0xE6050610),
              Color(0x99050610),
              Color(0x00050610),
            ], stops: [
              0.0,
              0.45,
              0.75,
            ]).createShader(Offset.zero & size),
        );

        // App icon
        const iconRect = Rect.fromLTWH(72, 100, 128, 128);
        c.save();
        c.clipRRect(
            RRect.fromRectAndRadius(iconRect, const Radius.circular(30)));
        c.drawImageRect(
            icon,
            Rect.fromLTWH(
                0, 0, icon.width.toDouble(), icon.height.toDouble()),
            iconRect,
            Paint()..filterQuality = FilterQuality.high);
        c.restore();

        c.drawParagraph(
            _text('Flow Math', 76, const Color(0xFFF6F2FF)),
            const Offset(68, 250));
        c.drawParagraph(
            _text('CALM MATH  ·  DEEP FOCUS  ·  SLOW BREATHING', 19,
                scene.$2,
                weight: FontWeight.w500, spacing: 3),
            const Offset(74, 352));

        final img = await rec.endRecording().toImage(1024, 500);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('play_store/feature-graphic-${scene.$1}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      }
    });
  });
}
