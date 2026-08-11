import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../utils/responsive.dart';

class AppTheme {
  // ── Moneytries — Premium Light Fintech Palette ──────────────────────────

  // Core backgrounds (light mode)
  static const Color background = AppColors.background;
  static const Color surfaceCard = AppColors.surface;
  static const Color surfaceDeep = AppColors.cardBeige;

  // Primary green accents
  static const Color primaryGreen = AppColors.primary;
  static const Color accentEmerald = AppColors.primaryLight;
  static const Color primaryGreenDim = AppColors.primaryDark;
  static const Color greenGlow = Color(0x334CAF7D);

  // Text
  static const Color titleColor = AppColors.textPrimary;
  static const Color bodyColor = AppColors.textSecondary;
  static const Color skipColor = AppColors.textSecondary;
  static const Color appNameColor = AppColors.primary;
  static const Color white = AppColors.white;
  static const Color tosColor = AppColors.textMuted;

  // Indicator
  static const Color indicatorActive = AppColors.primary;
  static const Color indicatorInactive = AppColors.brownBorder;

  // Legacy aliases (used by painters — kept for compatibility)
  static const Color gold = AppColors.primary;
  static const Color goldDim = AppColors.primaryDark;
  static const Color goldGlow = Color(0x334CAF7D);
  static const Color canvasDark = AppColors.background;

  // Inter via google_fonts — clean, modern, professional fintech typography
  static String get _font => GoogleFonts.inter().fontFamily!;

  // ── Static base theme (used as fallback before context is available) ──
  // Font sizes here use design-baseline values (375 dp reference frame).
  // Once the app is running, [themeFor] is used via main.dart's builder
  // to rebuild with properly scaled sizes.
  static ThemeData get lightTheme => _buildTheme(
    displayLargeFontSize: 28,
    bodyLargeFontSize: 15,
    labelLargeFontSize: 16,
  );

  // ── Context-aware theme — call from MaterialApp builder ───────────────
  // Rebuilds TextTheme with responsive font sizes scaled to the actual
  // device width, so Theme.of(context).textTheme widgets pick up the same
  // scaling as every explicit TextStyle that uses .sp.
  static ThemeData themeFor(BuildContext context) {
    ResponsiveConfig.instance.update(context);
    return _buildTheme(
      displayLargeFontSize: 28.sp,
      bodyLargeFontSize: 15.sp,
      labelLargeFontSize: 16.sp,
    );
  }

  static ThemeData _buildTheme({
    required double displayLargeFontSize,
    required double bodyLargeFontSize,
    required double labelLargeFontSize,
  }) {
    final baseTextTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      brightness: Brightness.light,
      fontFamily: _font,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontSize: displayLargeFontSize,
          fontWeight: FontWeight.w800,
          color: titleColor,
          letterSpacing: -0.3,
          height: 1.15,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: bodyLargeFontSize,
          fontWeight: FontWeight.w400,
          color: bodyColor,
          height: 1.65,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: labelLargeFontSize,
          fontWeight: FontWeight.w800,
          color: white,
          letterSpacing: 1.2,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        surface: surfaceCard,
        brightness: Brightness.light,
      ),
    );
  }
}
