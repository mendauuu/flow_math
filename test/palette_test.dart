import 'package:flow_math/theme/palette.dart';
import 'package:flow_math/widgets/animated_background.dart';
import 'package:flow_math/widgets/themed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every background scene has its own interface palette', () {
    for (final b in kBackgroundThemes) {
      expect(kPalettes.containsKey(b.id), isTrue, reason: b.id);
      expect(paletteFor(b.id).id, b.id);
    }
    expect(paletteFor('unknown').id, 'forest');
  });

  test('palettes differ in colour and shape', () {
    final radii = kPalettes.values.map((p) => p.radius).toSet();
    final accents = kPalettes.values.map((p) => p.accent).toSet();
    expect(radii.length, greaterThan(5));
    expect(accents.length, kPalettes.length);
  });

  test('theme changes blend smoothly', () {
    final a = paletteFor('storm');
    final b = paletteFor('snow');
    final mid = a.lerp(b, 0.5);
    expect(mid.radius, (a.radius + b.radius) / 2);
    expect(a.lerp(b, 0).accent, a.accent);
    expect(a.lerp(b, 1).accent, b.accent);
  });

  testWidgets('widgets read the active palette from the theme', (tester) async {
    late Palette seen;
    await tester.pumpWidget(MaterialApp(
      theme: themeFor('sakura'),
      home: Builder(builder: (context) {
        seen = context.palette;
        return Scaffold(
          body: ThemedButton(label: 'GO', onTap: () {}),
        );
      }),
    ));
    expect(seen.id, 'sakura');
    expect(find.text('GO'), findsOneWidget);
  });
}
