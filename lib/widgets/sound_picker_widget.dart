import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../utils/app_theme.dart';

/// Compact pill in the flow screen HUD — tap to cycle through all sound modes.
class SoundPickerWidget extends StatelessWidget {
  final AudioService audio;
  const SoundPickerWidget({super.key, required this.audio});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: audio,
      builder: (_, __) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          audio.cycleMode();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: audio.playing
                ? AppColors.primary.withOpacity(0.09)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: audio.playing
                  ? AppColors.primary.withOpacity(0.22)
                  : Colors.white.withOpacity(0.07),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(audio.modeEmoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 5),
              Text(
                audio.modeLabel,
                style: TextStyle(
                  fontSize: 9,
                  color: audio.playing ? AppColors.primary : AppColors.textDim,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (audio.playing) ...[
                const SizedBox(width: 5),
                _SoundWave(color: AppColors.primary),
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
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
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
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.75),
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
