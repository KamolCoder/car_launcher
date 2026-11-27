import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF0B0D10);
  static const surface = Color(0xFF16191F);
  static const surfaceHigh = Color(0xFF242932);
  static const accent = Color(0xFFFFCC00);
  static const textSecondary = Color(0xFF9AA0AA);
  static const ok = Color(0xFF34C759);
  static const error = Color(0xFFFF453A);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          onPrimary: Colors.black,
          surface: AppColors.surface,
        ),
        sliderTheme: const SliderThemeData(
          trackHeight: 8,
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.surfaceHigh,
          thumbColor: AppColors.accent,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 14),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 30),
        ),
      );
}
