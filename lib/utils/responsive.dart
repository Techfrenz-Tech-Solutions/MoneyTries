// lib/utils/responsive.dart
//
// App-wide responsive scaling utility.
//
// Every screen was designed against a standard mobile design frame
// (375 x 812 logical px — the common Figma/mockup baseline). Real Android
// hardware ranges from ~320dp-wide budget phones up through 6.9" flagships
// (Moto, Samsung, OnePlus, Vivo, Oppo, Redmi, Realme, ...) and 7"-13"
// tablets, so every literal pixel value in the UI needs to scale against
// the device it's actually running on instead of assuming the design
// frame's dimensions.
//
// Usage:
//   16.w   -> horizontally-scaled size (paddings, widths, horizontal gaps)
//   16.h   -> vertically-scaled size (heights, vertical gaps)
//   16.sp  -> scaled font / icon size (scaled more conservatively, and
//             independent of the system accessibility text scale, which is
//             clamped separately in main.dart)
//   16.r   -> scaled corner radius / stroke width
//
// All scale factors are clamped to a sane range so nothing on an unusually
// small or unusually large screen is ever stretched or shrunk past a point
// that would look broken — this is what keeps hairline dividers, borders,
// and tight paddings safe even though the same extension is reused
// everywhere.
//
// [ResponsiveConfig.instance.update] is called once per frame from
// MaterialApp's `builder` in main.dart, so every widget in the tree always
// reads up-to-date values without needing a BuildContext of its own.

import 'package:flutter/material.dart';

class ResponsiveConfig {
  ResponsiveConfig._();
  static final ResponsiveConfig instance = ResponsiveConfig._();

  // Reference design frame every screen was built against.
  static const double designWidth = 375.0;
  static const double designHeight = 812.0;

  // Screens at/above this width are treated as tablets.
  static const double tabletBreakpoint = 600.0;

  // Content is never allowed to stretch wider than this on large screens —
  // keeps forms/cards readable instead of spanning an entire tablet.
  static const double maxContentWidth = 640.0;

  double screenWidth = designWidth;
  double screenHeight = designHeight;
  EdgeInsets safePadding = EdgeInsets.zero;
  bool isTablet = false;

  double _widthScale = 1.0;
  double _heightScale = 1.0;
  double _textScale = 1.0;
  double _radiusScale = 1.0;

  double get widthScale => _widthScale;
  double get heightScale => _heightScale;
  double get textScale => _textScale;
  double get radiusScale => _radiusScale;

  void update(BuildContext context) {
    final mq = MediaQuery.of(context);
    screenWidth = mq.size.width;
    screenHeight = mq.size.height;
    safePadding = mq.padding;
    isTablet = screenWidth >= tabletBreakpoint;

    // Layout scale: allow a wider range upward on tablets (more breathing
    // room looks intentional there) but always keep a floor so small
    // budget-phone screens (~320dp) never crush content unreadably small.
    _widthScale = (screenWidth / designWidth)
        .clamp(0.82, isTablet ? 1.35 : 1.15);
    _heightScale = (screenHeight / designHeight).clamp(0.82, 1.20);

    // Text scales more conservatively than raw layout boxes so headings
    // never blow up disproportionately on tablets.
    _textScale = (screenWidth / designWidth).clamp(0.88, 1.18);

    // Radii/strokes: scale gently, never enough to look inconsistent.
    _radiusScale = (screenWidth / designWidth).clamp(0.88, 1.15);
  }
}

extension ResponsiveNum on num {
  /// Horizontally-scaled dimension (widths, horizontal padding/gaps).
  double get w => this * ResponsiveConfig.instance.widthScale;

  /// Vertically-scaled dimension (heights, vertical padding/gaps).
  double get h => this * ResponsiveConfig.instance.heightScale;

  /// Scaled font/icon size.
  double get sp => this * ResponsiveConfig.instance.textScale;

  /// Scaled corner radius / stroke width.
  double get r => this * ResponsiveConfig.instance.radiusScale;
}

/// Wraps the app's content so it never stretches uncomfortably wide on
/// tablets — the design stays phone-shaped and simply centers with margin
/// on larger screens instead of every screen needing its own constraint.
class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    ResponsiveConfig.instance.update(context);

    // Clamp the system font scale so a user's accessibility text-size
    // setting can never push fixed-height rows/cards into overflow, while
    // still letting a little extra scale through for accessibility.
    final clampedScaler = mq.textScaler.clamp(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.25,
    );

    Widget content = child;
    if (ResponsiveConfig.instance.isTablet) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResponsiveConfig.maxContentWidth,
          ),
          child: child,
        ),
      );
    }

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedScaler),
      child: content,
    );
  }
}

/// Convenience helpers for widgets that want breakpoint checks without
/// pulling in the whole config object.
bool isTabletWidth(BuildContext context) =>
    MediaQuery.of(context).size.width >= ResponsiveConfig.tabletBreakpoint;

/// Picks a grid column count based on available width — used by grids that
/// were previously hardcoded to a fixed `crossAxisCount`.
int responsiveGridColumns(double maxWidth, {int base = 2}) {
  if (maxWidth >= 900) return base + 2;
  if (maxWidth >= ResponsiveConfig.tabletBreakpoint) return base + 1;
  return base;
}