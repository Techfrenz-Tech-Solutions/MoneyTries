// lib/widgets/premium/premium_dialog.dart
//
// A showDialog replacement with a premium feel: the barrier itself blurs
// in (rather than a hard-cut scrim) and the content scales + fades in with
// a slight overshoot, instead of Material's flat instant-appear dialog.
// Pass any content — typically a GlassCard — as `child`.
import 'dart:ui';
import 'package:flutter/material.dart';

Future<T?> showPremiumDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x66000000),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent, // painted manually below so it can blur
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, _) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8 * animation.value,
          sigmaY: 8 * animation.value,
        ),
        child: Container(
          color: barrierColor.withOpacity(barrierColor.opacity * animation.value),
          alignment: Alignment.center,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}