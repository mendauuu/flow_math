import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/palette.dart';

/// A flip clock: each digit sits on a card made of the theme's matte
/// surface, and flips over in 3D when it changes.
class FlipClock extends StatelessWidget {
  /// e.g. "24:13"
  final String text;

  /// Card height; everything else scales from it.
  final double height;

  /// Softer digits (deep mode / paused).
  final bool dim;

  const FlipClock({
    super.key,
    required this.text,
    required this.height,
    this.dim = false,
  });

  /// Width of [text] at [height] — for fitting the clock into a space.
  static double widthFor(String text, double height) {
    var w = 0.0;
    for (final ch in text.split('')) {
      w += ch == ':' ? height * 0.26 : height * 0.68 + height * 0.06;
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chars.length; i++)
          if (chars[i] == ':')
            _Colon(height: height, dim: dim)
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: height * 0.03),
              child: FlipDigit(
                // Keyed by position, so each card keeps its own flip.
                key: ValueKey('digit$i'),
                digit: chars[i],
                height: height,
                dim: dim,
              ),
            ),
      ],
    );
  }
}

class FlipDigit extends StatefulWidget {
  final String digit;
  final double height;
  final bool dim;

  const FlipDigit({
    super.key,
    required this.digit,
    required this.height,
    this.dim = false,
  });

  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late String _current = widget.digit;
  String _previous = '';

  @override
  void didUpdateWidget(FlipDigit old) {
    super.didUpdateWidget(old);
    if (widget.digit != _current) {
      _previous = _current;
      _current = widget.digit;
      _flip.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final h = widget.height;
    final w = h * 0.68;
    final r = min(p.radius * 0.6, w * 0.22);

    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_flip.value);
        final flipping = _flip.isAnimating && _previous.isNotEmpty;
        final firstHalf = v < 0.5;
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              // Behind: the new top half, and the old bottom half until the
              // flap lands on it.
              _half(p, _current, top: true, w: w, h: h, r: r),
              _half(p, flipping && firstHalf ? _previous : _current,
                  top: false, w: w, h: h, r: r),
              // The old top half folds down…
              if (flipping && firstHalf)
                _flap(p, _previous,
                    top: true, angle: v / 0.5 * pi / 2, w: w, h: h, r: r),
              // …and the new bottom half lands.
              if (flipping && !firstHalf)
                _flap(p, _current,
                    top: false,
                    angle: (1 - (v - 0.5) / 0.5) * pi / 2,
                    w: w,
                    h: h,
                    r: r),
              // Hinge
              Positioned(
                left: 0,
                right: 0,
                top: h / 2 - max(1.0, h * 0.008),
                height: max(1.5, h * 0.016),
                child: ColoredBox(color: p.scrim.withValues(alpha: 0.75)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The full card; [_half] shows the top or bottom of it.
  Widget _card(Palette p, String digit, double w, double h, double r) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: p.line),
        // Matte: the top half a touch lighter than the bottom, like a real
        // flip card — no shine.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(p.textBright.withValues(alpha: 0.10), p.surface),
            Color.alphaBlend(p.textBright.withValues(alpha: 0.06), p.surface),
            Color.alphaBlend(p.textBright.withValues(alpha: 0.03), p.surface),
            Color.alphaBlend(Colors.black.withValues(alpha: 0.12), p.surface),
          ],
          stops: const [0.0, 0.499, 0.501, 1.0],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: TextStyle(
          fontSize: h * 0.74,
          height: 1.0,
          fontWeight: FontWeight.w300,
          color: p.textBright.withValues(alpha: widget.dim ? 0.6 : 1),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _halfContent(Palette p, String digit,
          {required bool top, required double w, required double h, required double r}) =>
      ClipRect(
        child: Align(
          alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
          heightFactor: 0.5,
          child: _card(p, digit, w, h, r),
        ),
      );

  Widget _half(Palette p, String digit,
          {required bool top, required double w, required double h, required double r}) =>
      Positioned(
        left: 0,
        right: 0,
        top: top ? 0 : h / 2,
        height: h / 2,
        child: _halfContent(p, digit, top: top, w: w, h: h, r: r),
      );

  /// A half card turning about the hinge, darkening as it turns away.
  Widget _flap(Palette p, String digit,
      {required bool top,
      required double angle,
      required double w,
      required double h,
      required double r}) {
    final shade = (angle / (pi / 2)).clamp(0.0, 1.0);
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : h / 2,
      height: h / 2,
      child: Transform(
        alignment: top ? Alignment.bottomCenter : Alignment.topCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0025)
          ..rotateX(top ? angle : -angle),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _halfContent(p, digit, top: top, w: w, h: h, r: r),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: top
                    ? BorderRadius.vertical(top: Radius.circular(r))
                    : BorderRadius.vertical(bottom: Radius.circular(r)),
                color: Colors.black.withValues(alpha: 0.35 * shade),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Colon extends StatelessWidget {
  final double height;
  final bool dim;
  const _Colon({required this.height, required this.dim});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = height * 0.075;
    Widget dot() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: p.textMid.withValues(alpha: dim ? 0.4 : 0.8),
            // Follows the theme's shape: round for soft styles, square for crisp.
            borderRadius: BorderRadius.circular(min(p.radius / 4, size / 2)),
          ),
        );
    return SizedBox(
      width: height * 0.26,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [dot(), SizedBox(height: height * 0.18), dot()],
      ),
    );
  }
}
