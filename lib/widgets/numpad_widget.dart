import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.all(4),
        height: 58,
        decoration: BoxDecoration(
          color: _pressed
              ? (isConfirm
                  ? AppColors.primary.withOpacity(0.25)
                  : Colors.white.withOpacity(0.06))
              : (isConfirm
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.white.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConfirm
                ? AppColors.primary.withOpacity(_pressed ? 0.4 : 0.15)
                : Colors.white.withOpacity(0.04),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: _isAction ? 18 : 22,
              fontWeight: FontWeight.w300,
              color: isConfirm
                  ? AppColors.primary
                  : widget.label == '⌫'
                      ? AppColors.textDim
                      : AppColors.textBright,
            ),
          ),
        ),
      ),
    );
  }
}
