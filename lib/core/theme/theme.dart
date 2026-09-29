import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class RythemTheme {
  RythemTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: RythemColors.background,
      colorScheme: const ColorScheme.dark(
        primary: RythemColors.actionPrimary,
        onPrimary: RythemColors.actionOnPrimary,
        surface: RythemColors.surface,
        onSurface: RythemColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: false,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return Colors.white.withOpacity(0.40);
          }
          return Colors.white.withOpacity(0.20);
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(4.0),
        crossAxisMargin: 2.0,
        mainAxisMargin: 4.0,
        thumbVisibility: WidgetStateProperty.all(false),
        interactive: true,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withOpacity(0.12),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withOpacity(0.1),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0, elevation: 1.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: RythemColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: RythemColors.lightActionPrimary,
        onPrimary: RythemColors.lightActionOnPrimary,
        surface: RythemColors.lightSurface,
        onSurface: RythemColors.lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return Colors.black.withOpacity(0.35);
          }
          return Colors.black.withOpacity(0.18);
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(4.0),
        crossAxisMargin: 2.0,
        mainAxisMargin: 4.0,
        thumbVisibility: WidgetStateProperty.all(false),
        interactive: true,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.black87,
        inactiveTrackColor: Colors.black.withOpacity(0.08),
        thumbColor: Colors.black87,
        overlayColor: Colors.black.withOpacity(0.08),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0, elevation: 1.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
