// lib/widgets/animations/animated_primary_button.dart
//
// A pill/rounded action button with press-scale feedback and a smooth
// morph into a loading spinner when `loading` is true — mirrors the
// pattern GPay/PhonePe use on Submit/Pay buttons so the button itself
// communicates in-flight state instead of a separate spinner overlay.
// Visual only: pass your existing onPressed/label/style through.
import 'package:flutter/material.dart';
import 'package:moneytries/config/app_fonts.dart';
import '../../services/audio/interaction_feedback.dart';

class AnimatedPrimaryButton extends StatefulWidget {
  final String label;
  final Widget? labelWidget;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final Color color;
  final Color disabledColor;
  final Color textColor;
  final double height;
  final double borderRadius;
  final TextStyle? textStyle;

  /// Plays a subtle tap-confirmation sound + light haptic on press.
  /// Set to false for buttons that already trigger their own success
  /// cue immediately (avoids two sounds firing back to back).
  final bool playTapSound;

  const AnimatedPrimaryButton({
    super.key,
    required this.label,
    this.labelWidget,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.color = const Color(0xFF4CAF7D),
    this.disabledColor = const Color(0xFFB9BDC3),
    this.textColor = Colors.white,
    this.height = 52,
    this.borderRadius = 16,
    this.textStyle,
    this.playTapSound = true,
  });

  @override
  State<AnimatedPrimaryButton> createState() => _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<AnimatedPrimaryButton> {
  bool _pressed = false;

  bool get _canTap =>
      widget.enabled && !widget.loading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final bg = widget.enabled ? widget.color : widget.disabledColor;
    return GestureDetector(
      onTap: _canTap
          ? () {
              if (widget.playTapSound) InteractionFeedback.buttonTap();
              widget.onPressed!();
            }
          : null,
      onTapDown: _canTap ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: widget.enabled && !_pressed
                ? [
                    BoxShadow(
                      color: bg.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
              child: widget.loading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(widget.textColor),
                      ),
                    )
                  : Container(
                      key: const ValueKey('label'),
                      child: widget.labelWidget ??
                          Text(
                            widget.label,
                            style: widget.textStyle ??
                                TextStyle(
                                  fontFamily: AppFonts.primary, fontFamilyFallback: AppFonts.fallbacks,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: widget.textColor,
                                ),
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}