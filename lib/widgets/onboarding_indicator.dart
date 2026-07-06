import 'package:flutter/material.dart';

// Active: sage gradient pill. Inactive: light mint dot with sage border.
// Matches mint/sage banner palette of onboarding screen.
const _indicatorActive   = Color(0xFF3D9E6A); // banner sage
const _indicatorInactive = Color(0xFFB8DECA); // light mint dot
const _inactiveBorder    = Color(0xFF86C9A0); // sage border

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
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF56B47E), Color(0xFF3D9E6A)],
                  )
                : null,
            color: isActive ? null : _indicatorInactive,
            border: isActive
                ? null
                : Border.all(color: _inactiveBorder, width: 0.8),
          ),
        );
      }),
    );
  }
}