import 'package:flutter/material.dart';
import 'grow_wealth_painter.dart';
import 'smart_invest_painter.dart';
import 'secure_earnings_painter.dart';

class OnboardingIllustration extends StatefulWidget {
  final String tag;
  const OnboardingIllustration({super.key, required this.tag});

  @override
  State<OnboardingIllustration> createState() => _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<OnboardingIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _getPainter(_anim.value),
        size: Size.infinite,
      ),
    );
  }

  CustomPainter _getPainter(double v) {
    switch (widget.tag) {
      case 'grow':
        return GrowWealthPainter(animValue: v);
      case 'invest':
        return SmartInvestPainter(animValue: v);
      case 'secure':
        return SecureEarningsPainter(animValue: v);
      default:
        return GrowWealthPainter(animValue: v);
    }
  }
}
