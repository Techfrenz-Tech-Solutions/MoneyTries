import 'package:flutter/material.dart';
import '../models/onboarding_model.dart';

// Image card: r:20, no background card — image sits directly on the
// black background. No drop shadow (invisible on black, removed for a
// flatter, more compact card matching the MoneyMining reference).
class OnboardingSlideWidget extends StatefulWidget {
  final OnboardingSlide slide;
  final bool isActive;
  final int slideIndex;

  const OnboardingSlideWidget({
    super.key,
    required this.slide,
    required this.isActive,
    required this.slideIndex,
  });

  @override
  State<OnboardingSlideWidget> createState() => _OnboardingSlideWidgetState();
}

class _OnboardingSlideWidgetState extends State<OnboardingSlideWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (widget.isActive) _ctrl.forward();
  }

  @override
  void didUpdateWidget(OnboardingSlideWidget old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20), // r:20 — compact card
          child: Image.asset(
            widget.slide.imagePath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}