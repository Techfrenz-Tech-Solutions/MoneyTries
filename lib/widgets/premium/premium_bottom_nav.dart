// lib/widgets/premium/premium_bottom_nav.dart
//
// Shared floating bottom-navigation bar used across Home / Plan / History /
// Profile / Referral / Support. Renders a premium, fintech-style floating
// pill: a soft-shadowed off-canvas card with icons that scale-bounce and
// cross-fade color on selection. No background circle/bubble/indicator sits
// behind the icon — the active state is communicated purely through the
// icon's own color + scale animation.
//
// This widget is presentation-only — every screen keeps its own
// `_selectedNavIndex` / `_onNavTap` (or equivalent) and simply passes
// `selectedIndex` + `onTap` in. No routing/business logic lives here.
import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../animations/animations.dart';

class PremiumNavItem {
  final IconData icon;
  const PremiumNavItem({required this.icon});
}

class PremiumBottomNav extends StatelessWidget {
  /// Index of the currently active tab, or -1 if none of the tabs
  /// represents the screen currently on-screen (e.g. Support).
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<PremiumNavItem> items;

  /// Bar background. Defaults to white so the pill floats above the
  /// app's warm beige-white page background.
  final Color backgroundColor;
  final Color selectedColor;
  final Color unselectedColor;

  const PremiumBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.selectedColor = const Color(0xFF1F6B45),
    this.unselectedColor = const Color(0xFF9CA3AF),
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = 64.h;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomInset + 14.h),
      child: Container(
        height: barHeight,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(32.r),
          boxShadow: [
            // Soft, wide ambient shadow — the main "floating" cue.
            BoxShadow(
              color: const Color(0xFF1F2933).withOpacity(0.10),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
            // Tight contact shadow — keeps the edge crisp up close.
            BoxShadow(
              color: const Color(0xFF1F2933).withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == selectedIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: SizedBox(
                  height: barHeight,
                  child: Center(
                    child: AnimatedNavIcon(
                      icon: items[i].icon,
                      selected: selected,
                      size: 24.sp,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}