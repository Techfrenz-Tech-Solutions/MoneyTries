// lib/widgets/animations/staggered_entrance.dart
//
// Wrap each item in a list with StaggeredEntrance(index: i, child: ...)
// and every item fades + slides up into place with a small delay per
// index, producing the "cascading list" effect common in premium apps.
// Runs once per widget lifetime (plays on first build only).
import 'package:flutter/material.dart';

class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration itemDelay;
  final Duration duration;
  final double slideOffset;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = Duration.zero,
    this.itemDelay = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 420),
    this.slideOffset = 18,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.slideOffset / 100),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delay = widget.baseDelay + widget.itemDelay * widget.index;
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}