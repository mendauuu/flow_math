import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Nature-inspired dark palette
  static const Color bgDeep = Color(0xFF0A0F0D);
  static const Color bgMid = Color(0xFF0F1A14);
  static const Color bgSurface = Color(0xFF162019);

  static const Color accent = Color(0xFF4ADE80);       // soft green
  static const Color accentDim = Color(0xFF22C55E);
  static const Color accentGlow = Color(0xFF86EFAC);

  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF81A88A);
  static const Color textDim = Color(0xFF4A6B52);

  static const Color errorSoft = Color(0xFFF87171);
  static const Color successSoft = Color(0xFF4ADE80);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDeep,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      surface: bgSurface,
    ),
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.dmMono(
        fontSize: 64,
        fontWeight: FontWeight.w300,
        color: textPrimary,
        letterSpacing: -2,
      ),
      displayMedium: GoogleFonts.dmMono(
        fontSize: 48,
        fontWeight: FontWeight.w300,
        color: textPrimary,
        letterSpacing: -1,
      ),
      headlineMedium: GoogleFonts.dmMono(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        color: textSecondary,
        letterSpacing: 0.3,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        color: textDim,
      ),
    ),
  );
}
