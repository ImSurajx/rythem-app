import 'package:flutter/material.dart';

class RythemColors {
  RythemColors._();

  // -------------------------------------------------------------
  // Dark Palette (Pure Pitch Black & Specular Liquid Glass)
  // -------------------------------------------------------------
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0F0F10);
  static const Color darkSurfaceElevated = Color(0xFF1C1C1E);
  static const Color darkGlassBackground = Color(0x14FFFFFF); // 8% white
  static const Color darkGlassBorder = Color(0x24FFFFFF); // 14% white border
  static const Color darkGlassBorderHighlight = Color(0x40FFFFFF); // 25% white highlight
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xB3FFFFFF); // 70% white
  static const Color darkTextTertiary = Color(0x66FFFFFF); // 40% white
  static const Color darkActionPrimary = Color(0xFFFFFFFF);
  static const Color darkActionOnPrimary = Color(0xFF000000);

  // -------------------------------------------------------------
  // Light Palette (Predominantly White + Apple Translucent Frosted Glass)
  // -------------------------------------------------------------
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F8FA);
  static const Color lightSurfaceElevated = Color(0xFFEEEEF2);
  static const Color lightGlassBackground = Color(0xB8FFFFFF); // 72% frosted translucent white
  static const Color lightGlassBorder = Color(0x12000000); // 7% subtle gray border
  static const Color lightGlassBorderHighlight = Color(0x80FFFFFF); // 50% specular top light
  static const Color lightTextPrimary = Color(0xFF111113); // Deep obsidian
  static const Color lightTextSecondary = Color(0xFF6E6E73); // Apple secondary label
  static const Color lightTextTertiary = Color(0xFF8E8E93); // Apple tertiary gray
  static const Color lightActionPrimary = Color(0xFF111113); // Obsidian button
  static const Color lightActionOnPrimary = Color(0xFFFFFFFF); // White text

  // -------------------------------------------------------------
  // Static Backwards Compatibility (defaults to Dark)
  // -------------------------------------------------------------
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color surfaceElevated = darkSurfaceElevated;
  static const Color surfaceGlass = darkGlassBackground;
  static const Color glassBorder = darkGlassBorder;
  static const Color glassBorderHighlight = darkGlassBorderHighlight;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textTertiary = darkTextTertiary;
  static const Color actionPrimary = darkActionPrimary;
  static const Color actionOnPrimary = darkActionOnPrimary;

  static const LinearGradient darkCanvasGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF121316),
      Color(0xFF050506),
      Color(0xFF000000),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient lightCanvasGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF9FAFB),
      Color(0xFFF2F4F7),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient darkSpecularBorder = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x4DFFFFFF), // 30% specular top light
      Color(0x1AFFFFFF), // 10% side
      Color(0x0DFFFFFF), // 5% bottom shadow
    ],
  );

  static const LinearGradient lightSpecularBorder = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xE6FFFFFF), // specular top light
      Color(0x18000000), // 9% side
      Color(0x0A000000), // 4% bottom shadow
    ],
  );

  // -------------------------------------------------------------
  // Context-Aware Palette Resolver
  // -------------------------------------------------------------
  static RythemThemeColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkThemeColors : lightThemeColors;
  }

  static const RythemThemeColors dark = darkThemeColors;
  static const RythemThemeColors light = lightThemeColors;

  static const RythemThemeColors darkThemeColors = RythemThemeColors(
    isDark: true,
    background: darkBackground,
    surface: darkSurface,
    surfaceElevated: darkSurfaceElevated,
    glassBackground: darkGlassBackground,
    glassBorder: darkGlassBorder,
    glassBorderHighlight: darkGlassBorderHighlight,
    textPrimary: darkTextPrimary,
    textSecondary: darkTextSecondary,
    textTertiary: darkTextTertiary,
    actionPrimary: darkActionPrimary,
    actionOnPrimary: darkActionOnPrimary,
    cardShadow: Color(0x73000000),
    progressTrack: darkSurfaceElevated,
    progressFill: Color(0xFFFFFFFF),
    canvasGradient: darkCanvasGradient,
    specularBorderGradient: darkSpecularBorder,
    rowBackground: Color(0x0AFFFFFF),
    rowBorder: Color(0x12FFFFFF),
  );

  static const RythemThemeColors lightThemeColors = RythemThemeColors(
    isDark: false,
    background: lightBackground,
    surface: lightSurface,
    surfaceElevated: lightSurfaceElevated,
    glassBackground: lightGlassBackground,
    glassBorder: lightGlassBorder,
    glassBorderHighlight: lightGlassBorderHighlight,
    textPrimary: lightTextPrimary,
    textSecondary: lightTextSecondary,
    textTertiary: lightTextTertiary,
    actionPrimary: lightActionPrimary,
    actionOnPrimary: lightActionOnPrimary,
    cardShadow: Color(0x0D000000),
    progressTrack: Color(0x0F000000),
    progressFill: Color(0xFF111113),
    canvasGradient: lightCanvasGradient,
    specularBorderGradient: lightSpecularBorder,
    rowBackground: Color(0x06000000),
    rowBorder: Color(0x0D000000),
  );
}

class RythemThemeColors {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color glassBackground;
  final Color glassBorder;
  final Color glassBorderHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color actionPrimary;
  final Color actionOnPrimary;
  final Color cardShadow;
  final Color progressTrack;
  final Color progressFill;
  final LinearGradient canvasGradient;
  final LinearGradient specularBorderGradient;
  final Color rowBackground;
  final Color rowBorder;

  const RythemThemeColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.glassBackground,
    required this.glassBorder,
    required this.glassBorderHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.actionPrimary,
    required this.actionOnPrimary,
    required this.cardShadow,
    required this.progressTrack,
    required this.progressFill,
    required this.canvasGradient,
    required this.specularBorderGradient,
    required this.rowBackground,
    required this.rowBorder,
  });
}

typedef RythemColorTokens = RythemThemeColors;
