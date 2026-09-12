import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class RythemTypography {
  RythemTypography._();

  static TextStyle displayLarge = GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: RythemColors.textPrimary,
  );

  static TextStyle displayMedium = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: RythemColors.textPrimary,
  );

  static TextStyle brandLogo = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 8.0,
    color: RythemColors.textPrimary,
  );

  static TextStyle titleLarge = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: RythemColors.textPrimary,
  );

  static TextStyle titleMedium = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: RythemColors.textPrimary,
  );

  static TextStyle bodyLarge = GoogleFonts.poppins(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: RythemColors.textSecondary,
    height: 1.4,
  );

  static TextStyle bodyMedium = GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: RythemColors.textSecondary,
    height: 1.35,
  );

  static TextStyle headlineMedium = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: RythemColors.textPrimary,
  );

  static TextStyle titleSmall = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: RythemColors.textPrimary,
  );

  static TextStyle bodySmall = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: RythemColors.textSecondary,
    height: 1.35,
  );

  static TextStyle labelSmall = GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: RythemColors.textTertiary,
  );

  static TextStyle button = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: RythemColors.actionOnPrimary,
  );
}
