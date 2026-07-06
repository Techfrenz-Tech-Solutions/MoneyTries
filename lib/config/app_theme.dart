import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Moneytries — Green palette ──────────────────────────────────────────

  // Core backgrounds
  static const Color background     = Color(0xFF0A1A10); // deep forest black-green
  static const Color surfaceCard    = Color(0xFF0F2318); // lifted dark green surface
  static const Color surfaceDeep    = Color(0xFF071210); // near-black green

  // Primary green accents
  static const Color primaryGreen   = Color(0xFF16A34A); // vivid green — primary CTA
  static const Color accentEmerald  = Color(0xFF00C896); // emerald highlight
  static const Color primaryGreenDim = Color(0xFF0D7A35); // darker green
  static const Color greenGlow      = Color(0xFF16A34A33); // green with opacity

  // Text
  static const Color titleColor     = Color(0xFF4ADE80); // bright mint green titles
  static const Color bodyColor      = Color(0xFF9CA3AF); // muted grey body
  static const Color skipColor      = Color(0xFF6B7280); // muted skip
  static const Color appNameColor   = Color(0xFF4ADE80); // bright mint app name
  static const Color white          = Color(0xFFFFFFFF);
  static const Color tosColor       = Color(0xFF4B5563);

  // Indicator
  static const Color indicatorActive   = Color(0xFF16A34A); // green active
  static const Color indicatorInactive = Color(0xFF1F3728); // dark green inactive

  // Legacy aliases (used by painters)
  static const Color gold           = Color(0xFF16A34A); // mapped → green
  static const Color goldDim        = Color(0xFF0D7A35);
  static const Color goldGlow       = Color(0xFF16A34A33);
  static const Color canvasDark     = Color(0xFF080E14);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        surface: surfaceCard,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: titleColor,
          letterSpacing: -0.3,
          height: 1.15,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: bodyColor,
          height: 1.65,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: background,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}