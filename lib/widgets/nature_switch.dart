import 'package:flutter/material.dart';
import '../theme/palette.dart';

/// Soft pill toggle used across Settings, Focus and Meditation.
/// Takes its colours from the active theme.
class NatureSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Defaults to the theme accent.
  final Color? color;

  const NatureSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.accent;
    // Track and knob follow the theme's shape (round ↔ crisp).
    final r = (p.radius * 0.7).clamp(4.0, 13.0);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value
              ? Color.alphaBlend(c.withValues(alpha: 0.28), p.surface)
              : p.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(r),
          border: Border.all(
            color: value ? c.withValues(alpha: 0.6) : p.line,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? c : p.textDim,
              borderRadius: BorderRadius.circular(r - 3),
            ),
          ),
        ),
      ),
    );
  }
}
