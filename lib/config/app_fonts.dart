// lib/config/app_fonts.dart
//
// Centralised font configuration for Moneytries.
//
// Primary font : Times New Roman  — elegant serif for all UI text.
// Fallback font: NotoSans          — bundled asset that covers Unicode
//                                    characters not present in Times New
//                                    Roman, most importantly the Indian
//                                    Rupee sign (₹, U+20B9).
//
// Usage in TextStyle:
//   TextStyle(
//     fontFamily: AppFonts.primary,
//     fontFamilyFallback: AppFonts.fallbacks,
//   )
//
// Or use the convenience extension:
//   TextStyle(fontSize: 16).withAppFont
//
// The theme (app_theme.dart) uses AppFonts.applyTo() to patch every
// TextStyle in a TextTheme at once.

import 'package:flutter/material.dart';

class AppFonts {
  AppFonts._();

  /// Primary font family — Times New Roman (system font on Android/iOS/Web).
  static const String primary = 'Times New Roman';

  /// Bundled fallback fonts consulted when a glyph is missing from the
  /// primary font.  NotoSans covers ₹ and the full Unicode Latin/Devanagari
  /// range, so it seamlessly handles every currency and script the app
  /// displays.
  static const List<String> fallbacks = ['NotoSans'];

  /// Apply [primary] + [fallbacks] to an existing [TextStyle].
  static TextStyle apply(TextStyle style) =>
      style.copyWith(fontFamily: primary, fontFamilyFallback: fallbacks);

  /// Patch every non-null style in a [TextTheme] with the app fonts.
  static TextTheme applyToTextTheme(TextTheme theme) {
    TextStyle? patch(TextStyle? s) => s == null ? null : apply(s);
    return theme.copyWith(
      displayLarge: patch(theme.displayLarge),
      displayMedium: patch(theme.displayMedium),
      displaySmall: patch(theme.displaySmall),
      headlineLarge: patch(theme.headlineLarge),
      headlineMedium: patch(theme.headlineMedium),
      headlineSmall: patch(theme.headlineSmall),
      titleLarge: patch(theme.titleLarge),
      titleMedium: patch(theme.titleMedium),
      titleSmall: patch(theme.titleSmall),
      bodyLarge: patch(theme.bodyLarge),
      bodyMedium: patch(theme.bodyMedium),
      bodySmall: patch(theme.bodySmall),
      labelLarge: patch(theme.labelLarge),
      labelMedium: patch(theme.labelMedium),
      labelSmall: patch(theme.labelSmall),
    );
  }
}

/// Convenience extension: apply Times New Roman + NotoSans fallback to
/// any TextStyle without calling AppFonts.apply() explicitly.
extension AppFontStyle on TextStyle {
  TextStyle get withAppFont => AppFonts.apply(this);
}
