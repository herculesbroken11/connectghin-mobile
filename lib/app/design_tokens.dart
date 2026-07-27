import 'package:flutter/material.dart';

/// Connectghin design tokens — premium golf / lifestyle palette.
abstract final class CgColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color cream = Color(0xFFF7F4EC);
  static const Color creamDark = Color(0xFFEDE8DC);
  static const Color gray50 = Color(0xFFF7F4EC);
  static const Color gray100 = Color(0xFFEEE9DF);
  static const Color gray200 = Color(0xFFDDD6C8);
  static const Color gray300 = Color(0xFFC9C0B0);
  static const Color gray400 = Color(0xFF9A9184);
  static const Color gray500 = Color(0xFF6F675C);
  static const Color gray600 = Color(0xFF524C44);
  static const Color gray700 = Color(0xFF3A3530);
  static const Color gray900 = Color(0xFF1A1814);

  static const Color charcoal = Color(0xFF141C18);
  static const Color charcoalSoft = Color(0xFF1E2A24);

  static const Color green50 = Color(0xFFEFF7F1);
  static const Color green100 = Color(0xFFD4EAD9);
  static const Color green600 = Color(0xFF2F7A4A);
  static const Color green700 = Color(0xFF1B5E3A);
  static const Color green800 = Color(0xFF154C2F);
  static const Color green900 = Color(0xFF0D3320);
  static const Color fairway = Color(0xFF1F6B45);

  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);

  static const Color purple50 = Color(0xFFFAF5FF);
  static const Color purple700 = Color(0xFF7E22CE);

  static const Color yellow50 = Color(0xFFFFF8E8);
  static const Color yellow100 = Color(0xFFFEEDED);
  static const Color yellow200 = Color(0xFFF5E0A8);
  static const Color yellow500 = Color(0xFFE0B84A);
  static const Color yellow600 = Color(0xFFC9A227);
  static const Color yellow700 = Color(0xFFA17F16);
  static const Color yellow800 = Color(0xFF7A5F12);
  static const Color yellow900 = Color(0xFF5C470E);

  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red700 = Color(0xFFB91C1C);

  static const Color orange500 = Color(0xFFF97316);
  static const Color orange600 = Color(0xFFEA580C);
  static const Color orange700 = Color(0xFFC2410C);

  static const Color premiumGold = Color(0xFFD4A017);
  static const Color premiumGoldLight = Color(0xFFF0D78C);
  static const Color premiumGoldDark = Color(0xFF8B6914);
  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF0D3320);
  static const Color inputBg = Color(0xFFF3F0E8);
  static const Color destructive = Color(0xFFD4183D);

  /// Hero / screen header gradient stops.
  static const List<Color> headerGradient = [
    charcoal,
    green900,
    fairway,
  ];
}

abstract final class CgRadii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
  static const double card = 20;
}

abstract final class CgShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: CgColors.charcoal.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> card = [
    BoxShadow(
      color: CgColors.charcoal.withValues(alpha: 0.10),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
