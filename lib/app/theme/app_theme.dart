import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../design_tokens.dart';

class AppTheme {
  static ThemeData light() {
    final baseText = GoogleFonts.dmSansTextTheme();
    final display = GoogleFonts.fraunces();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: CgColors.cream,
      colorScheme: const ColorScheme.light(
        primary: CgColors.green700,
        onPrimary: CgColors.white,
        secondary: CgColors.premiumGold,
        onSecondary: CgColors.charcoal,
        surface: CgColors.white,
        onSurface: CgColors.gray900,
        error: CgColors.destructive,
        onError: CgColors.white,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: CgColors.cream,
        foregroundColor: CgColors.gray900,
        centerTitle: true,
        titleTextStyle: display.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: CgColors.gray900,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CgColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CgRadii.lg),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CgColors.green700,
          foregroundColor: CgColors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CgRadii.lg)),
          textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CgColors.gray900,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: CgColors.gray300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CgRadii.lg)),
          textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: CgColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CgRadii.card)),
        shadowColor: CgColors.charcoal.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return CgColors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return CgColors.green700;
          return CgColors.gray300;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      textTheme: baseText.copyWith(
        headlineLarge: display.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: CgColors.gray900,
          height: 1.2,
          decoration: TextDecoration.none,
        ),
        headlineMedium: display.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: CgColors.gray900,
          height: 1.25,
          decoration: TextDecoration.none,
        ),
        headlineSmall: display.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: CgColors.gray900,
          height: 1.3,
          decoration: TextDecoration.none,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: CgColors.gray900,
          decoration: TextDecoration.none,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: CgColors.gray900,
          decoration: TextDecoration.none,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          color: CgColors.gray900,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: CgColors.gray600,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12,
          color: CgColors.gray600,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: CgColors.gray900,
          decoration: TextDecoration.none,
        ),
      ).apply(
        bodyColor: CgColors.gray900,
        displayColor: CgColors.gray900,
        decoration: TextDecoration.none,
      ),
    );
  }
}
