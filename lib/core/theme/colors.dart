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
  // Light Palette (Apple Control Center Frosted Glass)
  // Soft ambient platinum canvas with frosted glass plates
  // -------------------------------------------------------------
  static const Color lightBackground = Color(0xFFE8EAEE);
  static const Color lightSurface = Color(0xFFF3F4F6);
  static const Color lightSurfaceElevated = Color(0xFFDFE2E8);
  static const Color lightGlassBackground = Color(0xBAFFFFFF); // 73% frosted white plate
  static const Color lightGlassBorder = Color(0x1F000000); // 12% black border
  static const Color lightGlassBorderHighlight = Color(0x80FFFFFF); // 50% specular top light
  static const Color lightTextPrimary = Color(0xFF141415); // Rich obsidian
  static const Color lightTextSecondary = Color(0xFF55555C); // Muted graphite
  static const Color lightTextTertiary = Color(0xFF8E8E93); // Apple tertiary gray
  static const Color lightActionPrimary = Color(0xFF141415); // Obsidian button
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
      Color(0xFFF1F3F7),
      Color(0xFFE6E9EE),
    ],
    stops: [0.0, 0.4, 1.0],
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
      Color(0xB3FFFFFF), // 70% specular top light
      Color(0x33000000), // 20% side
      Color(0x1A000000), // 10% bottom shadow
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
    cardShadow: Color(0x14000000),
    progressTrack: Color(0x12000000),
    progressFill: Color(0xFF141415),
    canvasGradient: lightCanvasGradient,
    specularBorderGradient: lightSpecularBorder,
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
  });
}

typedef RythemColorTokens = RythemThemeColors;
