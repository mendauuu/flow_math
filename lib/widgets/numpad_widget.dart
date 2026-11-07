import 'package:flutter/material.dart';
import '../theme/palette.dart';


class NumpadWidget extends StatelessWidget {
  final void Function(String) onTap;
  const NumpadWidget({super.key, required this.onTap});

  static const _keys = [
    ['7', '8', '9'],
    ['4', '5', '6'],
    ['1', '2', '3'],
    ['⌫', '0', '✓'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: _keys.map((row) {
          return Row(
            children: row.map((key) {
              return Expanded(
                child: _NumKey(label: key, onTap: () => onTap(key)),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class _NumKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NumKey({required this.label, required this.onTap});

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  Palette get pal => context.palette;

  bool _pressed = false;

  bool get _isAction => widget.label == '✓' || widget.label == '⌫';

  @override
  Widget build(BuildContext context) {
    final isConfirm = widget.label == '✓';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 90),
        margin: EdgeInsets.all(4),
        height: 58,
        // Keys are made of the theme's matte surface, in the theme's shape.
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            isConfirm
                ? pal.accent.withValues(alpha: _pressed ? 0.32 : 0.16)
                : pal.textBright.withValues(alpha: _pressed ? 0.10 : 0.03),
            pal.surface.withValues(alpha: 0.62),
          ),
          borderRadius: pal.corners(0.65),
          border: Border.all(
            color: isConfirm
                ? pal.accent.withValues(alpha: _pressed ? 0.6 : 0.35)
                : pal.line,
          ),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: _isAction ? 18 : 22,
              fontWeight: FontWeight.w300,
              color: isConfirm
                  ? pal.accent
                  : widget.label == '⌫'
                      ? pal.textDim
                      : pal.textBright,
            ),
          ),
        ),
      ),
    );
  }
}
