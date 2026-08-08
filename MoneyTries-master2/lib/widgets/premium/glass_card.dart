// lib/widgets/premium/glass_card.dart
//
// Drop-in glassmorphism container — CRED/Revolut/Apple-Wallet style frosted
// card: backdrop blur behind translucent content, a faint light border to
// suggest a physical edge, a soft ambient shadow for depth, and an optional
// diagonal "sheen" highlight so the card catches light instead of reading
// flat. Purely presentational: pass any existing child through unchanged.
//
// Usage:
//   GlassCard(
//     gradientColors: const [Color(0xFFDCF3E5), Color(0xFF9AE0BC)],
//     child: yourExistingContent,
//   )
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// Base fill colors (diagonal gradient). Glass translucency is applied
  /// on top via [glassOpacity] — pass normal opaque brand colors here.
  final List<Color> gradientColors;

  /// How much of the blurred backdrop shows through the fill (0 = fully
  /// opaque color, 1 = fully see-through). 0.82 reads as "frosted glass"
  /// without losing the card's own color identity.
  final double glassOpacity;

  /// Blur strength applied to whatever sits behind the card.
  final double blurSigma;

  final Color shadowColor;
  final double shadowOpacity;

  /// Faint diagonal light-catch overlay — set false for a flatter look.
  final bool sheen;

  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.gradientColors = const [Color(0xFFFFFFFF), Color(0xFFF3F3F3)],
    this.glassOpacity = 0.82,
    this.blurSigma = 18,
    this.shadowColor = Colors.black,
    this.shadowOpacity = 0.12,
    this.sheen = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final translucentColors = gradientColors
        .map((c) => c.withOpacity(c.opacity * glassOpacity))
        .toList();

    return Container(
      // The ambient shadow lives on an outer, un-clipped Container — clipping
      // (needed for the inner blur) would otherwise cut the shadow off too.
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(shadowOpacity),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: translucentColors,
              ),
              border: border ??
                  Border.all(
                    color: Colors.white.withOpacity(0.45),
                    width: 1.2,
                  ),
            ),
            child: Stack(
              children: [
                if (sheen)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: const [0.0, 0.45, 1.0],
                            colors: [
                              Colors.white.withOpacity(0.28),
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}