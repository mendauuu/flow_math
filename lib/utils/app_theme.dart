import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const deepNight = Color(0xFF080D18);
  static const midNight = Color(0xFF0D1525);
  static const surface = Color(0xFF131E30);

  // Accents (teal-green nature palette)
  static const primary = Color(0xFF6EC6AA);
  static const primaryDim = Color(0xFF3D8B72);
  static const gold = Color(0xFFD4A853);

  // Text
  static const textBright = Color(0xFFF0F4F8);
  static const textMid = Color(0xFF8BA3BF);
  static const textDim = Color(0xFF4A6180);

  // Feedback
  static const correct = Color(0xFF5ECD8A);
  static const incorrect = Color(0xFFE57373);

  // Gradients
  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF080D18),
      Color(0xFF0A1520),
      Color(0xFF0D1E2A),
    ],
  );

  static const forestGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF071510),
      Color(0xFF0A1E18),
      Color(0xFF0D1525),
    ],
  );

  static const oceanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF060D1A),
      Color(0xFF091525),
      Color(0xFF0C1C30),
    ],
  );
}

class AppTextStyles {
  static const problemText = TextStyle(
    fontFamily: 'monospace',
    fontSize: 64,
    fontWeight: FontWeight.w200,
    color: AppColors.textBright,
    letterSpacing: 4,
    height: 1.1,
  );

  static const answerText = TextStyle(
    fontFamily: 'monospace',
    fontSize: 52,
    fontWeight: FontWeight.w300,
    color: AppColors.primary,
    letterSpacing: 2,
  );

  static const timerText = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textDim,
    letterSpacing: 2,
  );

  static const streakText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
    letterSpacing: 1.5,
  );

  static const feedbackText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textMid,
    height: 1.4,
  );

  static const labelText = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textDim,
    letterSpacing: 2,
  );
}
