import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF0B0D10);
  static const surface = Color(0xFF16191F);
  static const surfaceHigh = Color(0xFF242932);

  /// Default accent (cyan, like Spark M300 interior lighting). Widgets should use
  /// Theme.of(context).colorScheme.primary so the user's choice applies.
  static const accent = Color(0xFF00E5FF);

  /// Warnings (battery 20-49%, weak signal): stays yellow whatever the accent is.
  static const warning = Color(0xFFFFCC00);
  static const textSecondary = Color(0xFF9AA0AA);
  static const ok = Color(0xFF34C759);
  static const error = Color(0xFFFF453A);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => build(AppColors.accent);

  /// Dark theme with [accent] as primary (all accents are light -> black content on them).
  static ThemeData build(Color accent) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.dark(
          primary: accent,
          onPrimary: Colors.black,
          surface: AppColors.surface,
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 8,
          activeTrackColor: accent,
          inactiveTrackColor: AppColors.surfaceHigh,
          thumbColor: accent,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 30),
        ),
      );
}
