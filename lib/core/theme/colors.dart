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
    final scoped = RythemThemeScope.maybeOf(context);
    if (scoped != null) return scoped;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkThemeColors : lightThemeColors;
  }

  static const RythemThemeColors dark = darkThemeColors;
  static const RythemThemeColors light = lightThemeColors;

  static RythemThemeColors forPalette(ThemePalette palette, {required bool isDark}) {
    return resolve(isDark: isDark, palette: palette);
  }

  static RythemThemeColors resolve({
    required bool isDark,
    ThemePalette palette = ThemePalette.aurora,
  }) {
    final base = isDark ? darkThemeColors : lightThemeColors;
    final orbs = isDark ? _darkOrbsFor(palette) : _lightOrbsFor(palette);
    final (primary, secondary, gradient) = _accentsFor(palette);

    return base.copyWith(
      palette: palette,
      accentPrimary: primary,
      accentSecondary: secondary,
      accentGradient: gradient,
      ambientOrbs: orbs,
    );
  }

  static (Color, Color, LinearGradient) _accentsFor(ThemePalette palette) {
    switch (palette) {
      case ThemePalette.aurora:
        return (
          const Color(0xFF00E5FF), // Electric Cyan
          const Color(0xFF9D4EDD), // Cosmic Violet
          const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF9D4EDD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case ThemePalette.cobalt:
        return (
          const Color(0xFF00B4D8), // Ice Blue
          const Color(0xFF48CAE4), // Electric Cyan
          const LinearGradient(
            colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case ThemePalette.solar:
        return (
          const Color(0xFFFF9500), // Solar Amber
          const Color(0xFFFF5722), // Warm Coral
          const LinearGradient(
            colors: [Color(0xFFFF9500), Color(0xFFFF5722)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case ThemePalette.studio:
        return (
          const Color(0xFFFFFFFF), // Specular White
          const Color(0xFF8E8E93), // Apple Grey
          const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xB3FFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
    }
  }

  static List<AmbientOrbConfig> _darkOrbsFor(ThemePalette palette) {
    switch (palette) {
      case ThemePalette.aurora:
        return const [
          AmbientOrbConfig(
            alignment: Alignment(0.85, -0.85),
            radius: 0.90,
            color: Color(0xFF3A0CA3), // Deep Royal Indigo
            opacity: 0.28,
          ),
          AmbientOrbConfig(
            alignment: Alignment(-0.95, -0.05),
            radius: 0.80,
            color: Color(0xFF0077B6), // Electric Ocean Cyan
            opacity: 0.22,
          ),
          AmbientOrbConfig(
            alignment: Alignment(0.35, 0.95),
            radius: 0.85,
            color: Color(0xFF7209B7), // Liquid Violet
            opacity: 0.22,
          ),
        ];
      case ThemePalette.cobalt:
        return const [
          AmbientOrbConfig(
            alignment: Alignment(0.85, -0.85),
            radius: 0.90,
            color: Color(0xFF023E8A), // Deep Cobalt
            opacity: 0.32,
          ),
          AmbientOrbConfig(
            alignment: Alignment(-0.90, 0.15),
            radius: 0.80,
            color: Color(0xFF0096C7), // Bright Azure
            opacity: 0.24,
          ),
          AmbientOrbConfig(
            alignment: Alignment(0.50, 0.95),
            radius: 0.85,
            color: Color(0xFF03045E), // Midnight Navy
            opacity: 0.28,
          ),
        ];
      case ThemePalette.solar:
        return const [
          AmbientOrbConfig(
            alignment: Alignment(0.85, -0.85),
            radius: 0.90,
            color: Color(0xFFD97706), // Warm Amber
            opacity: 0.26,
          ),
          AmbientOrbConfig(
            alignment: Alignment(-0.90, -0.05),
            radius: 0.80,
            color: Color(0xFF9A3412), // Burnt Terracotta
            opacity: 0.22,
          ),
          AmbientOrbConfig(
            alignment: Alignment(0.25, 0.95),
            radius: 0.85,
            color: Color(0xFFB45309), // Golden Honey
            opacity: 0.20,
          ),
        ];
      case ThemePalette.studio:
        return const [
          AmbientOrbConfig(
            alignment: Alignment(0.70, -0.85),
            radius: 0.85,
            color: Color(0xFF1C1C1E),
            opacity: 0.35,
          ),
          AmbientOrbConfig(
            alignment: Alignment(-0.70, 0.70),
            radius: 0.75,
            color: Color(0xFF141416),
            opacity: 0.25,
          ),
        ];
    }
  }

  static List<AmbientOrbConfig> _lightOrbsFor(ThemePalette palette) {
    switch (palette) {
      case ThemePalette.aurora:
        return const [
          AmbientOrbConfig(
            alignment: Alignment(0.85, -0.85),
            radius: 0.90,
            color: Color(0xFFC77DFF),
            opacity: 0.10,
          ),
          AmbientOrbConfig(
            alignment: Alignment(-0.95, -0.05),
            radius: 0.80,
            color: Color(0xFF90E0EF),
            opacity: 0.10,
          ),
          AmbientOrbConfig(
            alignment: Alignment(0.35, 0.95),
            radius: 0.85,
            color: Color(0xFFE0AAFF),
            opacity: 0.08,
          ),
        ];
      case ThemePalette.cobalt:
        return const [
          AmbientOrbConfig(
            alignment: Alignment(0.85, -0.85),
            radius: 0.90,
            color: Color(0xFFADE8F4),
            opacity: 0.14,
          ),
          AmbientOrbConfig(
            alignment: Alignment(-0.90, 0.15),
            radius: 0.80,
            color: Color(0xFF90E0EF),
            opacity: 0.12,
          ),
          AmbientOrbConfig(
            alignment: Alignment(0.50, 0.95),
            radius: 0.85,
            color: Color(0xFFCAF0F8),
            opacity: 0.10,
          ),
        ];
      case ThemePalette.solar:
        return const [
          AmbientOrbConfig(
            alignment: Alignment(0.85, -0.85),
            radius: 0.90,
            color: Color(0xFFFDE68A),
            opacity: 0.14,
          ),
          AmbientOrbConfig(
            alignment: Alignment(-0.90, -0.05),
            radius: 0.80,
            color: Color(0xFFFED7AA),
            opacity: 0.12,
          ),
          AmbientOrbConfig(
            alignment: Alignment(0.25, 0.95),
            radius: 0.85,
            color: Color(0xFFFEF3C7),
            opacity: 0.10,
          ),
        ];
      case ThemePalette.studio:
        return const [];
    }
  }

  static const RythemThemeColors darkThemeColors = RythemThemeColors(
    isDark: true,
    palette: ThemePalette.aurora,
    accentPrimary: Color(0xFF00E5FF),
    accentSecondary: Color(0xFF9D4EDD),
    accentGradient: LinearGradient(
      colors: [Color(0xFF00E5FF), Color(0xFF9D4EDD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ambientOrbs: [
      AmbientOrbConfig(
        alignment: Alignment(0.85, -0.85),
        radius: 0.90,
        color: Color(0xFF3A0CA3),
        opacity: 0.28,
      ),
      AmbientOrbConfig(
        alignment: Alignment(-0.95, -0.05),
        radius: 0.80,
        color: Color(0xFF0077B6),
        opacity: 0.22,
      ),
      AmbientOrbConfig(
        alignment: Alignment(0.35, 0.95),
        radius: 0.85,
        color: Color(0xFF7209B7),
        opacity: 0.22,
      ),
    ],
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
    palette: ThemePalette.aurora,
    accentPrimary: Color(0xFF0077B6),
    accentSecondary: Color(0xFF7209B7),
    accentGradient: LinearGradient(
      colors: [Color(0xFF0077B6), Color(0xFF7209B7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ambientOrbs: [
      AmbientOrbConfig(
        alignment: Alignment(0.85, -0.85),
        radius: 0.90,
        color: Color(0xFFC77DFF),
        opacity: 0.10,
      ),
      AmbientOrbConfig(
        alignment: Alignment(-0.95, -0.05),
        radius: 0.80,
        color: Color(0xFF90E0EF),
        opacity: 0.10,
      ),
    ],
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

/// Curated Theme Palettes for Rythem's Liquid Glass Design System
enum ThemePalette {
  aurora,
  cobalt,
  solar,
  studio;

  String get displayName {
    switch (this) {
      case ThemePalette.aurora:
        return 'Aurora';
      case ThemePalette.cobalt:
        return 'Cobalt';
      case ThemePalette.solar:
        return 'Solar';
      case ThemePalette.studio:
        return 'Studio';
    }
  }

  List<Color> get previewColors {
    switch (this) {
      case ThemePalette.aurora:
        return const [Color(0xFF00E5FF), Color(0xFF9D4EDD)];
      case ThemePalette.cobalt:
        return const [Color(0xFF00B4D8), Color(0xFF023E8A)];
      case ThemePalette.solar:
        return const [Color(0xFFFF9500), Color(0xFFFF5722)];
      case ThemePalette.studio:
        return const [Color(0xFFFFFFFF), Color(0xFF55555A)];
    }
  }
}

/// Ambient Orb Configuration for single-pass GPU-friendly atmospheric lighting
class AmbientOrbConfig {
  final Alignment alignment;
  final double radius;
  final Color color;
  final double opacity;

  const AmbientOrbConfig({
    required this.alignment,
    required this.radius,
    required this.color,
    required this.opacity,
  });
}

/// Dynamic Track Signature Accent Resolver
class TrackAccents {
  TrackAccents._();

  static const Color cyan = Color(0xFF00E5FF);     // CS, DSA, Logic, C++, Algorithms
  static const Color emerald = Color(0xFF00E676);  // Python, Backend, Django, Node, Go
  static const Color violet = Color(0xFFB388FF);   // AI, ML, Math, Data Science
  static const Color coral = Color(0xFFFF6E40);    // Frontend, Flutter, React, UI, Web
  static const Color amber = Color(0xFFFFD600);    // System Design, Architecture, DB
  static const Color rose = Color(0xFFFF4081);     // Mobile, Native, iOS, Android

  static Color getAccent(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('python') || lower.contains('backend') || lower.contains('django') || lower.contains('node') || lower.contains('rust')) {
      return emerald;
    }
    if (lower.contains('dsa') || lower.contains('algo') || lower.contains('data struct') || lower.contains('c++') || lower.contains('java') || lower.contains('logic')) {
      return cyan;
    }
    if (lower.contains('ai') || lower.contains('ml') || lower.contains('machine learning') || lower.contains('deep learning') || lower.contains('math') || lower.contains('gpt')) {
      return violet;
    }
    if (lower.contains('flutter') || lower.contains('react') || lower.contains('frontend') || lower.contains('web') || lower.contains('css') || lower.contains('ui')) {
      return coral;
    }
    if (lower.contains('system design') || lower.contains('architecture') || lower.contains('database') || lower.contains('sql') || lower.contains('cloud')) {
      return amber;
    }
    const fallbackPalette = [cyan, emerald, violet, coral, amber, rose];
    return fallbackPalette[title.hashCode.abs() % fallbackPalette.length];
  }
}

class RythemThemeColors {
  final bool isDark;
  final ThemePalette palette;
  final Color accentPrimary;
  final Color accentSecondary;
  final LinearGradient accentGradient;
  final List<AmbientOrbConfig> ambientOrbs;
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
    this.palette = ThemePalette.aurora,
    this.accentPrimary = const Color(0xFF00E5FF),
    this.accentSecondary = const Color(0xFF9D4EDD),
    this.accentGradient = const LinearGradient(
      colors: [Color(0xFF00E5FF), Color(0xFF9D4EDD)],
    ),
    this.ambientOrbs = const [],
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

  RythemThemeColors copyWith({
    bool? isDark,
    ThemePalette? palette,
    Color? accentPrimary,
    Color? accentSecondary,
    LinearGradient? accentGradient,
    List<AmbientOrbConfig>? ambientOrbs,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? glassBackground,
    Color? glassBorder,
    Color? glassBorderHighlight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? actionPrimary,
    Color? actionOnPrimary,
    Color? cardShadow,
    Color? progressTrack,
    Color? progressFill,
    LinearGradient? canvasGradient,
    LinearGradient? specularBorderGradient,
    Color? rowBackground,
    Color? rowBorder,
  }) {
    return RythemThemeColors(
      isDark: isDark ?? this.isDark,
      palette: palette ?? this.palette,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentGradient: accentGradient ?? this.accentGradient,
      ambientOrbs: ambientOrbs ?? this.ambientOrbs,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBorderHighlight: glassBorderHighlight ?? this.glassBorderHighlight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      actionPrimary: actionPrimary ?? this.actionPrimary,
      actionOnPrimary: actionOnPrimary ?? this.actionOnPrimary,
      cardShadow: cardShadow ?? this.cardShadow,
      progressTrack: progressTrack ?? this.progressTrack,
      progressFill: progressFill ?? this.progressFill,
      canvasGradient: canvasGradient ?? this.canvasGradient,
      specularBorderGradient:
          specularBorderGradient ?? this.specularBorderGradient,
      rowBackground: rowBackground ?? this.rowBackground,
      rowBorder: rowBorder ?? this.rowBorder,
    );
  }
}

typedef RythemColorTokens = RythemThemeColors;

/// Inherited scope providing dynamic theme palette colors throughout the widget tree.
class RythemThemeScope extends InheritedWidget {
  final RythemThemeColors colors;

  const RythemThemeScope({
    super.key,
    required this.colors,
    required super.child,
  });

  static RythemThemeColors? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RythemThemeScope>()?.colors;
  }

  @override
  bool updateShouldNotify(RythemThemeScope oldWidget) =>
      colors.palette != oldWidget.colors.palette ||
      colors.isDark != oldWidget.colors.isDark;
}
