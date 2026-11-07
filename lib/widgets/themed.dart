import 'package:flutter/material.dart';
import '../theme/palette.dart';

// Shared controls that take their look from the active [Palette], so every
// screen changes style together with the theme.

/// Matte button with a gentle press-down.
class ThemedButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  /// Colour of a primary button (defaults to the palette accent).
  final Color? tint;
  final IconData? icon;
  final double height;

  const ThemedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = true,
    this.tint,
    this.icon,
    this.height = 56,
  });

  @override
  State<ThemedButton> createState() => _ThemedButtonState();
}

class _ThemedButtonState extends State<ThemedButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = widget.tint ?? p.accent;
    final color = widget.primary ? t : p.textMid;
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => enabled ? setState(() => _down = true) : null,
      onTapUp: (_) => enabled ? setState(() => _down = false) : null,
      onTapCancel: () => enabled ? setState(() => _down = false) : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: widget.height,
          width: double.infinity,
          decoration: p.button(primary: widget.primary, tint: t),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 17, color: color),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          widget.primary ? FontWeight.w700 : FontWeight.w600,
                      color: color,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps any child with a soft press-down (for cards and tiles).
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, required this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _press(bool down) {
    if (widget.onTap != null) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      );
}

/// Back/close button + small caps title + optional trailing widget.
class ThemedTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final IconData icon;
  final Widget? trailing;

  const ThemedTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.icon = Icons.arrow_back_ios_new_rounded,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: p.panel(scale: 0.55),
              child: Icon(icon,
                  color: p.textMid,
                  size: icon == Icons.arrow_back_ios_new_rounded ? 16 : 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.label.copyWith(fontSize: 11, letterSpacing: 4)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Dims the background with the palette's tinted scrim.
class ThemedScrim extends StatelessWidget {
  final double opacity;
  const ThemedScrim(this.opacity, {super.key});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 900),
        color: context.palette.scrim.withValues(alpha: opacity),
      );
}

/// Small number + caption tile.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  const StatTile(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: p.panel(scale: 0.7),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: p.textBright)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 8, color: p.textDim, letterSpacing: 1.5)),
        ],
      ),
    );
  }
}

/// A themed yes/no dialog. Returns true when [action] is chosen.
Future<bool> showThemedConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  String cancel = 'Cancel',
  bool actionIsSafe = false,
  Color? tint,
}) async {
  final p = context.palette;
  final t = tint ?? p.accent;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: TextStyle(color: p.textBright, fontSize: 18)),
      content: Text(body, style: TextStyle(color: p.textDim, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancel,
              style: TextStyle(color: actionIsSafe ? p.textDim : t)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action,
              style: TextStyle(color: actionIsSafe ? t : p.textDim)),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showThemedToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
    ));
}
