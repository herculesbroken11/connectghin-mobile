import 'package:flutter/material.dart';

import '../design_tokens.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: CgColors.gray50,
      colorScheme: const ColorScheme.light(
        primary: CgColors.green700,
        onPrimary: CgColors.white,
        secondary: CgColors.green100,
        onSecondary: CgColors.green800,
        surface: CgColors.white,
        onSurface: CgColors.gray900,
        error: CgColors.destructive,
        onError: CgColors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: CgColors.white,
        foregroundColor: CgColors.gray900,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CgColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CgRadii.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CgColors.green700,
          foregroundColor: CgColors.white,
          elevation: 0,
          // Keep a consistent min height without forcing infinite width in Row.
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CgRadii.md)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CgColors.gray900,
          // Keep a consistent min height without forcing infinite width in Row.
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: CgColors.gray300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CgRadii.md)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w500,
          color: CgColors.gray900,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: CgColors.gray900,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: CgColors.gray900,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: CgColors.gray900,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: CgColors.gray900, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: CgColors.gray600, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: CgColors.gray600, height: 1.5),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: CgColors.gray900,
        ),
      ),
    );
  }
}
