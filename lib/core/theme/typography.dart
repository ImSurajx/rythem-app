import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class RythemTypography {
  RythemTypography._();

  static TextStyle displayLarge = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    color: RythemColors.textPrimary,
  );

  static TextStyle displayMedium = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: RythemColors.textPrimary,
  );

  static TextStyle brandLogo = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w300,
    letterSpacing: 8.0,
    color: RythemColors.textPrimary,
  );

  static TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: RythemColors.textPrimary,
  );

  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: RythemColors.textPrimary,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: RythemColors.textSecondary,
    height: 1.4,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: RythemColors.textSecondary,
    height: 1.35,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: RythemColors.textTertiary,
  );

  static TextStyle button = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: RythemColors.actionOnPrimary,
  );
}
