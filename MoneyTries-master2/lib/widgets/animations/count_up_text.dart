// lib/widgets/animations/count_up_text.dart
//
// Animates a numeric value counting up — used for wallet balances / stats so
// updates feel alive instead of snapping.
//
// Two independent triggers can start a count animation:
//  • `value` changes (e.g. a fresh balance came back from the server) — this
//    animates smoothly from whatever is currently on screen to the new value.
//  • `replayTrigger` changes (e.g. the user tapped the eye/show-hide toggle)
//    — this always restarts the count from 0 up to the current value, giving
//    a fresh "counting up" reveal every time it's shown.
//
// The widget is stateful and keeps its own AnimationController alive across
// rebuilds so callers can safely keep it permanently mounted (e.g. behind an
// opacity mask) without losing or restarting animation state by accident.
import 'package:flutter/material.dart';

class CountUpText extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  /// Change this value (e.g. bump a counter) to force a fresh 0 → [value]
  /// count-up animation, regardless of whether [value] itself changed.
  final Object? replayTrigger;

  const CountUpText({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.textAlign,
    this.replayTrigger,
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  late double _targetValue;
  Object? _lastReplayTrigger;

  @override
  void initState() {
    super.initState();
    _targetValue = widget.value;
    _lastReplayTrigger = widget.replayTrigger;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);

    final replayRequested = widget.replayTrigger != _lastReplayTrigger;
    final valueChanged = widget.value != _targetValue;
    if (!replayRequested && !valueChanged) return;

    // A replay always restarts from zero for a fresh "counting up" reveal.
    // A plain value change (no replay requested) continues from wherever
    // the animation currently sits, so live balance updates still feel
    // continuous instead of jumping back to zero.
    final start = replayRequested ? 0.0 : _animation.value;

    _targetValue = widget.value;
    _lastReplayTrigger = widget.replayTrigger;
    _controller.duration = widget.duration;
    _animation = Tween<double>(begin: start, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Text(
          widget.formatter(_animation.value),
          style: widget.style,
          textAlign: widget.textAlign,
        );
      },
    );
  }
}