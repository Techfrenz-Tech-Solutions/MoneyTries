import 'package:flutter/material.dart';
import '../utils/responsive.dart';

// Active: sage gradient pill. Inactive: light mint dot with sage border.
// Matches mint/sage banner palette of onboarding screen.
const _indicatorActive = Color(0xFF4CAF7D); // banner sage
const _indicatorInactive = Color(0xFFB2DFC5); // light mint dot
const _inactiveBorder = Color(0xFF7DCB9E); // sage border

class OnboardingIndicator extends StatelessWidget {
  final int count;
  final int current;

  const OnboardingIndicator({
    super.key,
    required this.count,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: isActive ? 28.w : 7.w,
          height: 7.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF5BC487), Color(0xFF4CAF7D)],
                  )
                : null,
            color: isActive ? null : _indicatorInactive,
            border: isActive
                ? null
                : Border.all(color: _inactiveBorder, width: 0.8.r),
          ),
        );
      }),
    );
  }
}
