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
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
