// lib/widgets/premium/premium_bottom_sheet.dart
//
// showModalBottomSheet replacement with a frosted-glass surface (backdrop
// blur behind a translucent sheet) instead of a flat opaque white sheet,
// plus a standard drag handle. Uses Flutter's own sheet-entrance animation
// (already a smooth decelerate slide-up) — only the surface treatment
// changes, so this drops in wherever a sheet already exists.
import 'dart:ui';
import 'package:flutter/material.dart';

Future<T?> showPremiumBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  Color glassColor = const Color(0xF2FFFFFF),
  BorderRadius borderRadius = const BorderRadius.vertical(
    top: Radius.circular(28),
  ),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (ctx) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: borderRadius,
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.6), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E4DE),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  builder(ctx),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}