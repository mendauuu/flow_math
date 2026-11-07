import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../widgets/themed.dart';
import 'package:flutter/services.dart';
import '../services/focus_store.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../widgets/animated_background.dart';

/// The "thought parking lot": distractions written down during focus so the
/// mind could let them go. Tick them off later, or swipe to delete.
class ThoughtsScreen extends StatefulWidget {
  final SettingsService settings;
  const ThoughtsScreen({super.key, required this.settings});

  @override
  State<ThoughtsScreen> createState() => _ThoughtsScreenState();
}

class _ThoughtsScreenState extends State<ThoughtsScreen> {
  Palette get pal => context.palette;

  List<ParkedThought> _thoughts = ThoughtStore.all;

  void _reload() => setState(() => _thoughts = ThoughtStore.all);

  Future<void> _toggle(ParkedThought t) async {
    if (widget.settings.haptics) HapticFeedback.selectionClick();
    await ThoughtStore.setDone(t.key, !t.done);
    _reload();
  }

  Future<void> _delete(ParkedThought t) async {
    await ThoughtStore.delete(t.key);
    _reload();
  }

  Future<void> _clearDone() async {
    await ThoughtStore.clearDone();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final anyDone = _thoughts.any((t) => t.done);
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(theme: widget.settings.bgTheme),
          ThemedScrim(0.58),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThemedTopBar(
                    title: 'PARKED THOUGHTS',
                    onBack: () => Navigator.pop(context)),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 4),
                  child: Text('Set aside,\nnot forgotten.',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w200,
                          color: pal.textBright,
                          height: 1.15)),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 6, 24, 16),
                  child: Text(
                      'Tap to tick one off. Swipe left to let it go.',
                      style: TextStyle(fontSize: 12, color: pal.textDim)),
                ),
                Expanded(
                  child: _thoughts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Nothing parked. 🌿\n\nWhen a thought pulls you away '
                              'during focus, tap "Park a thought" and it will '
                              'wait here for you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: pal.textDim,
                                  height: 1.6),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _thoughts.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8),
                          itemBuilder: (_, i) => _tile(_thoughts[i]),
                        ),
                ),
                if (anyDone)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: TextButton(
                        onPressed: _clearDone,
                        child: Text('Clear finished',
                            style: TextStyle(
                                fontSize: 12,
                                color: pal.textDim,
                                letterSpacing: 1)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(ParkedThought t) {
    return Dismissible(
      key: ValueKey(t.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(t),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.incorrect.withValues(alpha: 0.15),
          borderRadius: pal.corners(0.8),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: AppColors.incorrect, size: 20),
      ),
      child: Pressable(
        onTap: () => _toggle(t),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: t.done
              ? pal.panel(scale: 0.8)
              : pal.card(tint: pal.warm, scale: 0.8),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.done ? pal.warm : Colors.transparent,
                  border: Border.all(
                      color: t.done
                          ? pal.warm
                          : pal.textBright.withValues(alpha: 0.25)),
                ),
                child: t.done
                    ? Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(t.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: t.done ? pal.textDim : pal.textBright,
                      decoration: t.done ? TextDecoration.lineThrough : null,
                      decorationColor: pal.textDim,
                    )),
              ),
              SizedBox(width: 10),
              Text(_when(t.date),
                  style:
                      TextStyle(fontSize: 10, color: pal.textDim)),
            ],
          ),
        ),
      ),
    );
  }

  static String _when(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (day == today) return hm;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}
