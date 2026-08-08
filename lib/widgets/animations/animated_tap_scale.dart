// lib/widgets/animations/animated_tap_scale.dart
//
// Wraps any widget with a subtle press-down scale + opacity dip, the
// same "physical" tap feedback used across CRED / GPay / PhonePe style
// UIs. Purely presentational — forwards onTap unchanged, so it drops
// in around existing GestureDetector children without touching logic.
import 'package:flutter/material.dart';

class AnimatedTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final HitTestBehavior behavior;

  const AnimatedTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<AnimatedTapScale> createState() => _AnimatedTapScaleState();
}

class _AnimatedTapScaleState extends State<AnimatedTapScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!mounted) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}