import 'package:flutter/material.dart';
import '../theme/palette.dart';

import 'package:flutter/services.dart';
import '../services/audio_service.dart';

/// Compact pill in the flow screen HUD — tap to cycle through all sound modes.
class SoundPickerWidget extends StatelessWidget {
  final AudioService audio;
  final bool haptics;

  /// Called with the new mode after each tap (used to remember the choice).
  final ValueChanged<SoundMode>? onChanged;

  /// Emoji only (no name) — for narrow top bars.
  final bool compact;

  const SoundPickerWidget({
    super.key,
    required this.audio,
    this.haptics = true,
    this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return ListenableBuilder(
      listenable: audio,
      builder: (_, __) => GestureDetector(
        onTap: () {
          if (haptics) HapticFeedback.selectionClick();
          audio.cycleMode();
          onChanged?.call(audio.mode);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 250),
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 9 : 12, vertical: 7),
          decoration: pal.chip(audio.playing, scale: 0.6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(audio.modeEmoji, style: TextStyle(fontSize: 11)),
              if (!compact) ...[
                SizedBox(width: 5),
                Text(
                  audio.modeLabel,
                  style: TextStyle(
                    fontSize: 9,
                    color: audio.playing ? pal.accent : pal.textDim,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (audio.playing) ...[
                SizedBox(width: 5),
                _SoundWave(color: pal.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundWave extends StatefulWidget {
  final Color color;
  const _SoundWave({required this.color});
  @override
  State<_SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<_SoundWave>
    with SingleTickerProviderStateMixin {
  Palette get pal => context.palette;

  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final h = 3.0 + 5.0 * ((_c.value + i * 0.33) % 1.0);
          return Container(
            width: 2,
            height: h,
            margin: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}
