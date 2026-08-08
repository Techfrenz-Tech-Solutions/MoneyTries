import 'package:flutter/material.dart';

/// Moneytries — Premium Light Fintech Color System
///
/// Primary brand: Light Green (#4CAF7D) — fresh, modern, trustworthy
/// Accent:        Light Brown (#A07850) — premium, warm, highlights/borders
/// Backgrounds:   White + Soft Beige — clean, airy, readable
/// Text:          Near-black + greys — excellent contrast/accessibility
///
/// Design inspiration: CRED, Navi, Groww — premium fintech aesthetics
class AppColors {
  AppColors._();

  // ── Primary Brand — Light Green ──────────────────────────────────────────
  /// Primary brand green — buttons, icons, active states, links
  static const Color primary = Color(0xFF4CAF7D);

  /// Slightly deeper green — hover / pressed states, dark text on green
  static const Color primaryDark = Color(0xFF3D9463);

  /// Lighter green — secondary buttons, unselected chips, subtle fills
  static const Color primaryLight = Color(0xFF7DCB9E);

  /// Very soft green — icon backgrounds, card tints, success surfaces
  static const Color primarySurface = Color(0xFFE8F5EE);

  /// Even softer green tint — subtle hover, unread notifications
  static const Color primarySurfaceLight = Color(0xFFF0FAF4);

  // ── Gradient Pairs — Light Green ────────────────────────────────────────
  /// Hero gradient start (banner, cards, CTAs)
  static const Color gradientStart = Color(0xFF4CAF7D);

  /// Hero gradient end
  static const Color gradientEnd = Color(0xFF7DCB9E);

  /// Deep gradient — for dark headers (referral hero, summary cards)
  static const Color gradientDeep = Color(0xFF2D7A52);

  // ── Light Brown / Warm Accent ────────────────────────────────────────────
  /// Light brown — icons, highlights, dividers, borders, chips, accents
  static const Color brown = Color(0xFFA07850);

  /// Light brown surface — chip backgrounds, card accents
  static const Color brownSurface = Color(0xFFF5EDE3);

  /// Brown border — subtle dividers, card frames
  static const Color brownBorder = Color(0xFFE2CEBA);

  /// Brown light — very subtle backgrounds, hover states
  static const Color brownLight = Color(0xFFFAF4EE);

  // ── Backgrounds ──────────────────────────────────────────────────────────
  /// App scaffold background — soft warm beige-white
  static const Color background = Color(0xFFF7F5F2);

  /// Slightly cooler off-white for variety (deposit/withdrawal/plan screens)
  static const Color backgroundCool = Color(0xFFF4F6F4);

  /// White — cards, modals, bottom sheets
  static const Color white = Color(0xFFFFFFFF);

  /// Soft beige card — warm card backgrounds
  static const Color cardBeige = Color(0xFFFBF9F5);

  /// Beige border — card borders, dividers
  static const Color beigeBorder = Color(0xFFEDE9E2);

  // ── Surface / Card ───────────────────────────────────────────────────────
  /// Standard white card
  static const Color surface = Color(0xFFFFFFFF);

  /// Read-only / disabled field background
  static const Color surfaceDisabled = Color(0xFFF5F4F2);

  // ── Text ─────────────────────────────────────────────────────────────────
  /// Primary text — headings, important labels
  static const Color textPrimary = Color(0xFF111827);

  /// Secondary text — subtitles, descriptions
  static const Color textSecondary = Color(0xFF6B7280);

  /// Muted text — hints, placeholders, timestamps
  static const Color textMuted = Color(0xFF9CA3AF);

  /// Light muted — very subtle labels
  static const Color textLight = Color(0xFFBBC1C9);

  // ── Dividers & Borders ──────────────────────────────────────────────────
  /// Standard divider
  static const Color divider = Color(0xFFE8E4DE);

  /// Card border
  static const Color cardBorder = Color(0xFFEDE9E2);

  /// Field border (enabled)
  static const Color fieldBorder = Color(0xFFD9D5CF);

  /// Field border (focused)
  static const Color fieldBorderFocus = Color(0xFF4CAF7D);

  // ── Status Colors ────────────────────────────────────────────────────────
  /// Success green — approved/success states
  static const Color success = Color(0xFF4CAF7D);

  /// Success background
  static const Color successBg = Color(0xFFE8F5EE);

  /// Warning amber
  static const Color warning = Color(0xFFD97706);

  /// Warning background
  static const Color warningBg = Color(0xFFFEF3C7);

  /// Error red
  static const Color error = Color(0xFFDC2626);

  /// Error background
  static const Color errorBg = Color(0xFFFEE2E2);

  /// Processing blue
  static const Color processing = Color(0xFF3B82F6);

  /// Processing background
  static const Color processingBg = Color(0xFFEFF6FF);

  // ── Bottom Navigation ────────────────────────────────────────────────────
  /// Selected nav item
  static const Color navSelected = Color(0xFF4CAF7D);

  /// Unselected nav item
  static const Color navUnselected = Color(0xFF9CA3AF);

  // ── PIN / Keypad ─────────────────────────────────────────────────────────
  /// PIN dot filled
  static const Color pinDotFilled = Color(0xFF4CAF7D);

  /// PIN dot empty
  static const Color pinDotEmpty = Color(0xFFD9D5CF);

  /// Key button background
  static const Color keyBackground = Color(0xFFFFFFFF);

  // ── Onboarding ───────────────────────────────────────────────────────────
  static const Color onboardingBgTop = Color(0xFFF7F5F2);
  static const Color onboardingBgMid = Color(0xFFF0EDE7);
  static const Color onboardingMesh1 = Color(0xFFCCE8D8);
  static const Color onboardingMesh2 = Color(0xFFDFF0E6);
  static const Color onboardingAppName = Color(0xFF2D7A52);
  static const Color onboardingTitle = Color(0xFF2D7A52);
  static const Color onboardingBody = Color(0xFF4A7060);
  static const Color onboardingButton = Color(0xFF4CAF7D);
  static const Color onboardingSkip = Color(0xFF5BC487);

  // ── Splash ──────────────────────────────────────────────────────────────
  static const Color splashBgTop = Color(0xFFF7F5F2);
  static const Color splashBgMid = Color(0xFFEFF5F1);
  static const Color splashBgBottom = Color(0xFFE4EEE8);
  static const Color splashGreen = Color(0xFF7DCB9E);
  static const Color splashTextPrimary = Color(0xFF111827);
  static const Color splashTextMuted = Color(0xFF6B7280);

  // ── Referral Hero ────────────────────────────────────────────────────────
  static const Color referralHeroStart = Color(0xFF2D7A52);
  static const Color referralHeroMid = Color(0xFF3D9463);
  static const Color referralHeroEnd = Color(0xFF5BC487);

  // ── Plan Screen Vault ────────────────────────────────────────────────────
  static const Color vaultGreen = Color(0xFFD9EEDC);
  static const Color vaultGreenDeep = Color(0xFFBCE0C4);
  static const Color vaultTextDark = Color(0xFF111827);
  static const Color ledgerPaper = Color(0xFFFBF9F5);
  static const Color ledgerHairline = Color(0xFFE8E4DA);

  // ── Support / Glass ─────────────────────────────────────────────────────
  static const Color supportBgTop = Color(0xFFF4F7F4);
  static const Color supportBgBottom = Color(0xFFEAF0EA);

  // ── Helper gradients (as list for LinearGradient) ───────────────────────
  static const List<Color> heroGradientColors = [gradientStart, gradientEnd];
  static const List<Color> deepGradientColors = [gradientDeep, gradientStart];
  static const List<Color> referralGradientColors = [
    referralHeroStart,
    referralHeroMid,
    referralHeroEnd,
  ];
}
