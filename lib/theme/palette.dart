import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Palette — the look of the interface for each scene
//
//  Every background scene has a matching palette: three accents (one per
//  mode), a tinted "surface" that buttons and cards are made of, tinted text,
//  and its own corner shape. Surfaces are matte (accent blended into the
//  surface colour, no glow) so controls feel like part of the scene.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class Palette extends ThemeExtension<Palette> {
  final String id;

  /// Main actions and Flow State (math).
  final Color accent;

  /// Focus mode, streaks and achievements.
  final Color warm;

  /// Meditation.
  final Color calm;

  /// What buttons, cards and chips are made of — dark, tinted to the scene.
  final Color surface;

  /// Tint used to dim the background behind content.
  final Color scrim;

  final Color textBright;
  final Color textMid;
  final Color textDim;

  /// Corner radius — each theme has its own shape (soft snow, crisp storm…).
  final double radius;

  const Palette({
    required this.id,
    required this.accent,
    required this.warm,
    required this.calm,
    required this.surface,
    required this.scrim,
    required this.textBright,
    required this.textMid,
    required this.textDim,
    required this.radius,
  });

  // ── Derived colours ───────────────────────────────────────────────────────
  Color get line => textBright.withValues(alpha: 0.08);

  /// Solid colour for dialogs, sheets and snackbars.
  Color get dialog =>
      Color.alphaBlend(textBright.withValues(alpha: 0.05), surface);

  BorderRadius corners([double scale = 1]) =>
      BorderRadius.circular(radius * scale);

  /// Solid page colour for screens without the animated scene.
  Color get base => Color.alphaBlend(surface.withValues(alpha: 0.55), scrim);

  /// Calm backdrop for data screens (history, analytics).
  LinearGradient get backdrop => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(accent.withValues(alpha: 0.08), surface),
          base,
        ],
      );

  // ── Surfaces ──────────────────────────────────────────────────────────────
  /// Quiet container for rows and info.
  BoxDecoration panel({double scale = 1}) => BoxDecoration(
        color: surface.withValues(alpha: 0.55),
        borderRadius: corners(scale),
        border: Border.all(color: line),
      );

  /// A card with a hint of [tint] — stronger when [active].
  BoxDecoration card({Color? tint, bool active = false, double scale = 1}) {
    final t = tint ?? accent;
    return BoxDecoration(
      color: Color.alphaBlend(t.withValues(alpha: active ? 0.17 : 0.07),
          surface.withValues(alpha: 0.74)),
      borderRadius: corners(scale),
      border: Border.all(color: t.withValues(alpha: active ? 0.55 : 0.22)),
    );
  }

  /// Selectable chip.
  BoxDecoration chip(bool active, {Color? tint, double scale = 0.7}) {
    final t = tint ?? accent;
    return BoxDecoration(
      color: active
          ? Color.alphaBlend(
              t.withValues(alpha: 0.2), surface.withValues(alpha: 0.72))
          : surface.withValues(alpha: 0.45),
      borderRadius: corners(scale),
      border: Border.all(color: active ? t.withValues(alpha: 0.6) : line),
    );
  }

  /// Matte button.
  BoxDecoration button({bool primary = true, Color? tint}) {
    final t = tint ?? accent;
    return BoxDecoration(
      color: primary
          ? Color.alphaBlend(
              t.withValues(alpha: 0.24), surface.withValues(alpha: 0.85))
          : surface.withValues(alpha: 0.6),
      borderRadius: corners(0.8),
      border: Border.all(
          color: primary
              ? t.withValues(alpha: 0.55)
              : textBright.withValues(alpha: 0.12)),
    );
  }

  // ── Text ──────────────────────────────────────────────────────────────────
  TextStyle get label => TextStyle(
      fontSize: 10,
      color: textDim,
      letterSpacing: 3,
      fontWeight: FontWeight.w600);

  TextStyle get labelText => TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: textDim,
      letterSpacing: 2);

  TextStyle get timerText => TextStyle(
      fontFamily: 'monospace', fontSize: 13, color: textDim, letterSpacing: 2);

  TextStyle get problemText => TextStyle(
      fontFamily: 'monospace',
      fontSize: 64,
      fontWeight: FontWeight.w200,
      color: textBright,
      letterSpacing: 4,
      height: 1.1);

  TextStyle get answerText => TextStyle(
      fontFamily: 'monospace',
      fontSize: 52,
      fontWeight: FontWeight.w300,
      color: accent,
      letterSpacing: 2);

  TextStyle get streakText => TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: warm,
      letterSpacing: 1.5);

  TextStyle get feedbackText =>
      TextStyle(fontSize: 16, color: textMid, height: 1.4);

  // ── ThemeExtension ────────────────────────────────────────────────────────
  @override
  Palette copyWith({
    String? id,
    Color? accent,
    Color? warm,
    Color? calm,
    Color? surface,
    Color? scrim,
    Color? textBright,
    Color? textMid,
    Color? textDim,
    double? radius,
  }) =>
      Palette(
        id: id ?? this.id,
        accent: accent ?? this.accent,
        warm: warm ?? this.warm,
        calm: calm ?? this.calm,
        surface: surface ?? this.surface,
        scrim: scrim ?? this.scrim,
        textBright: textBright ?? this.textBright,
        textMid: textMid ?? this.textMid,
        textDim: textDim ?? this.textDim,
        radius: radius ?? this.radius,
      );

  /// Smooth cross-fade when the theme changes.
  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    return Palette(
      id: t < 0.5 ? id : other.id,
      accent: Color.lerp(accent, other.accent, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      calm: Color.lerp(calm, other.calm, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      textBright: Color.lerp(textBright, other.textBright, t)!,
      textMid: Color.lerp(textMid, other.textMid, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  One palette per scene
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, Palette> kPalettes = {
  'forest': Palette(
    id: 'forest',
    accent: Color(0xFF86C9A4), // sage
    warm: Color(0xFFE2B26F), // lantern
    calm: Color(0xFFA9BCEB), // moonlight
    surface: Color(0xFF10201A),
    scrim: Color(0xFF030B07),
    textBright: Color(0xFFEAF3EC),
    textMid: Color(0xFFA0BBAB),
    textDim: Color(0xFF62806F),
    radius: 18,
  ),
  'ocean': Palette(
    id: 'ocean',
    accent: Color(0xFF6EC1E4), // sea
    warm: Color(0xFFF0B98A), // coral sunrise
    calm: Color(0xFFA3B4F6), // dusk
    surface: Color(0xFF0C1B2C),
    scrim: Color(0xFF020912),
    textBright: Color(0xFFEAF4FB),
    textMid: Color(0xFF97B2C8),
    textDim: Color(0xFF5C778D),
    radius: 22,
  ),
  'desert': Palette(
    id: 'desert',
    accent: Color(0xFFE7B886), // sand
    warm: Color(0xFFE8916B), // terracotta
    calm: Color(0xFFC9A6D8), // dusk mauve
    surface: Color(0xFF26170F),
    scrim: Color(0xFF0D0705),
    textBright: Color(0xFFF7EDE2),
    textMid: Color(0xFFC8AC96),
    textDim: Color(0xFF8E7563),
    radius: 8,
  ),
  'aurora': Palette(
    id: 'aurora',
    accent: Color(0xFF62EBB7), // aurora green
    warm: Color(0xFFF2C46D),
    calm: Color(0xFFA894FF), // violet curtain
    surface: Color(0xFF0B1928),
    scrim: Color(0xFF02060C),
    textBright: Color(0xFFE8FBF4),
    textMid: Color(0xFF92BBB2),
    textDim: Color(0xFF587C73),
    radius: 16,
  ),
  'snow': Palette(
    id: 'snow',
    accent: Color(0xFFAED3F4), // ice
    warm: Color(0xFFF2C29A), // cocoa
    calm: Color(0xFFCDC1F2), // lilac
    surface: Color(0xFF17263C),
    scrim: Color(0xFF070D18),
    textBright: Color(0xFFF4F8FD),
    textMid: Color(0xFFAABBD0),
    textDim: Color(0xFF708299),
    radius: 28,
  ),
  'sakura': Palette(
    id: 'sakura',
    accent: Color(0xFFF5A8CA), // blossom
    warm: Color(0xFFF6C394), // peach
    calm: Color(0xFFC6B4F4), // wisteria
    surface: Color(0xFF2A1528),
    scrim: Color(0xFF0E0610),
    textBright: Color(0xFFFCEFF5),
    textMid: Color(0xFFD6ACC1),
    textDim: Color(0xFF9C768C),
    radius: 24,
  ),
  'sunset': Palette(
    id: 'sunset',
    accent: Color(0xFFFFB27E), // coral
    warm: Color(0xFFFFD27E), // gold
    calm: Color(0xFFE89DC3), // rose
    surface: Color(0xFF2A1325),
    scrim: Color(0xFF100610),
    textBright: Color(0xFFFFF1E8),
    textMid: Color(0xFFE2B0A0),
    textDim: Color(0xFFA47C7A),
    radius: 14,
  ),
  'cosmos': Palette(
    id: 'cosmos',
    accent: Color(0xFFA996FF), // nebula
    warm: Color(0xFFFFBA8C), // star
    calm: Color(0xFF83D6F2), // comet
    surface: Color(0xFF130F2C),
    scrim: Color(0xFF04030D),
    textBright: Color(0xFFF0EEFF),
    textMid: Color(0xFFAAA5D4),
    textDim: Color(0xFF6E6A99),
    radius: 12,
  ),
  'storm': Palette(
    id: 'storm',
    accent: Color(0xFFA0BCD8), // steel
    warm: Color(0xFFE9C17C), // lamplight
    calm: Color(0xFFB2A9DB),
    surface: Color(0xFF131B24),
    scrim: Color(0xFF030608),
    textBright: Color(0xFFECF1F6),
    textMid: Color(0xFF9EACBB),
    textDim: Color(0xFF677482),
    radius: 6,
  ),
  'autumn': Palette(
    id: 'autumn',
    accent: Color(0xFFF2B05A), // amber leaf
    warm: Color(0xFFE8743C), // maple
    calm: Color(0xFFC9A7D8), // dusk
    surface: Color(0xFF2A1612),
    scrim: Color(0xFF100706),
    textBright: Color(0xFFFBEFE4),
    textMid: Color(0xFFD9B39A),
    textDim: Color(0xFF9E7A66),
    radius: 20,
  ),
  'city': Palette(
    id: 'city',
    accent: Color(0xFF7EDFD4), // neon
    warm: Color(0xFFFFC46B), // window light
    calm: Color(0xFFB2A2F2),
    surface: Color(0xFF111826),
    scrim: Color(0xFF04070D),
    textBright: Color(0xFFEAF2F8),
    textMid: Color(0xFF9DB0C4),
    textDim: Color(0xFF63768A),
    radius: 10,
  ),
  'lanterns': Palette(
    id: 'lanterns',
    accent: Color(0xFFFF9E5C), // lantern glow
    warm: Color(0xFFFFCF7A), // flame
    calm: Color(0xFFA9B4F0), // night lake
    surface: Color(0xFF161634),
    scrim: Color(0xFF05050F),
    textBright: Color(0xFFF6F0FF),
    textMid: Color(0xFFB6B0D6),
    textDim: Color(0xFF76709C),
    radius: 22,
  ),
  'deepsea': Palette(
    id: 'deepsea',
    accent: Color(0xFF5ADBEF), // lagoon
    warm: Color(0xFFFFB38A), // coral
    calm: Color(0xFF9CA8FF), // jellyfish
    surface: Color(0xFF082232),
    scrim: Color(0xFF010A12),
    textBright: Color(0xFFE6F8FC),
    textMid: Color(0xFF8FB9C8),
    textDim: Color(0xFF547D8C),
    radius: 26,
  ),
  'meadow': Palette(
    id: 'meadow',
    accent: Color(0xFFC8DF7A), // fresh grass
    warm: Color(0xFFF2BE6E), // low sun
    calm: Color(0xFFB9B2EA),
    surface: Color(0xFF1E2418),
    scrim: Color(0xFF0A0E08),
    textBright: Color(0xFFF4F6E8),
    textMid: Color(0xFFB8C29E),
    textDim: Color(0xFF7C8668),
    radius: 18,
  ),
  'starfall': Palette(
    id: 'starfall',
    accent: Color(0xFFF4D88A), // meteor gold
    warm: Color(0xFFFFB68A),
    calm: Color(0xFFA6B6FF), // night
    surface: Color(0xFF10142C),
    scrim: Color(0xFF03040C),
    textBright: Color(0xFFF2F0FA),
    textMid: Color(0xFFA9ABCC),
    textDim: Color(0xFF6C6F96),
    radius: 14,
  ),
};

Palette paletteFor(String id) => kPalettes[id] ?? kPalettes['forest']!;

extension PaletteContext on BuildContext {
  /// The active interface palette.
  Palette get palette =>
      Theme.of(this).extension<Palette>() ?? kPalettes['forest']!;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ThemeData built from a palette (cached — one per style)
// ─────────────────────────────────────────────────────────────────────────────
final Map<String, ThemeData> _themeCache = {};

ThemeData themeFor(String id) =>
    _themeCache.putIfAbsent(id, () => _buildTheme(paletteFor(id)));

ThemeData _buildTheme(Palette p) {
  final shape = RoundedRectangleBorder(borderRadius: p.corners());
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: p.accent,
      onPrimary: Colors.black,
      secondary: p.warm,
      surface: p.dialog,
      onSurface: p.textBright,
    ),
    scaffoldBackgroundColor: p.scrim,
    dialogTheme: DialogThemeData(backgroundColor: p.dialog, shape: shape),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.dialog,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(p.radius + 4))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.dialog,
      contentTextStyle: TextStyle(color: p.textMid),
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.3),
      selectionHandleColor: p.accent,
    ),
    extensions: [p],
  );
}
