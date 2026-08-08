import 'package:flutter/material.dart';
import '../models/onboarding_model.dart';
import '../utils/responsive.dart';

// Illustration card — r:28, soft cream gradient background behind the
// image, matching the reference design's rounded illustration frame.
// The badge ("Flexible Plans" / "Smart & Secure") is baked into the
// uploaded illustration assets themselves, right near the top of the
// artwork. BoxFit.contain (not cover) is used so the full illustration —
// badge included — is always shown in full and never cropped off; any
// letterbox space is filled by the matching cream gradient behind it.
const _cardGradientTop = Color(0xFFF6EFE3);
const _cardGradientBottom = Color(0xFFEDE3D0);
const _cardShadowColor = Color(0xFF2D7A52);

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
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28.r),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_cardGradientTop, _cardGradientBottom],
            ),
            boxShadow: [
              BoxShadow(
                color: _cardShadowColor.withOpacity(0.10),
                blurRadius: 28,
                offset: const Offset(0, 14),
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.r),
            child: Image.asset(
              widget.slide.imagePath,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}