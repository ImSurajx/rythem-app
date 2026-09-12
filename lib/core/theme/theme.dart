import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
