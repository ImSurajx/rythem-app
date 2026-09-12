import 'package:flutter/material.dart';

class RythemColors {
  RythemColors._();

  // Pure Monochrome Backgrounds
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF141414);
  static const Color surfaceElevated = Color(0xFF1C1C1E);
  static const Color surfaceGlass = Color(0x1AFFFFFF); // 10% white for frosted glass
  static const Color surfaceGlassHigh = Color(0x2EFFFFFF); // 18% white for active glass

  // Specular Borders
  static const Color glassBorder = Color(0x24FFFFFF); // 14% white border
  static const Color glassBorderHighlight = Color(0x40FFFFFF); // 25% white specular highlight

  // Text Hierarchy (Monochrome only)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% white
  static const Color textTertiary = Color(0x66FFFFFF); // 40% white
  static const Color textMuted = Color(0x33FFFFFF); // 20% white

  // Accent & Action
  static const Color actionPrimary = Color(0xFFFFFFFF);
  static const Color actionOnPrimary = Color(0xFF000000);

  // Status (Monochrome)
  static const Color statusActive = Color(0xFFFFFFFF);
  static const Color statusInactive = Color(0x26FFFFFF);
}
