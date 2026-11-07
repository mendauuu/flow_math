import 'package:flow_math/theme/palette.dart';
import 'package:flow_math/widgets/flip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget clock(String text) => MaterialApp(
        theme: themeFor('cosmos'),
        home: Scaffold(
          body: Center(child: FlipClock(text: text, height: 120)),
        ),
      );

  testWidgets('digits flip when the time changes', (tester) async {
    await tester.pumpWidget(clock('25:00'));
    expect(find.text('2'), findsWidgets);

    await tester.pumpWidget(clock('24:59'));
    // Midway through the flip both the old and new digits are on the cards.
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('0'), findsWidgets);
    expect(find.text('9'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 260));
    expect(tester.takeException(), isNull);

    // Once it has landed only the new digits remain.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('9'), findsWidgets);
    expect(find.text('0'), findsNothing);
  });

  test('clock width scales with its height', () {
    final w = FlipClock.widthFor('25:00', 100);
    expect(w, closeTo(4 * 74 + 26, 0.01));
    expect(FlipClock.widthFor('25:00', 50), closeTo(w / 2, 0.01));
  });
}
